// Read completed local lane evidence. Never execute or retry application actions.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { catalogCases, harnessRoot, statuses } from './ci-contracts.mjs';
import { generate, writeReports } from '../../reporting/report.mjs';

export function validateLocalLanes(lanes, catalog) {
  assert.deepEqual(lanes.map(lane => lane.tier).sort(), ['B', 'D', 'F']);
  for (const lane of lanes) {
    assert.deepEqual(lane.rows.map(row => row.id).sort(), catalog.filter(row => row.tier === lane.tier).map(row => row.id).sort(), `Missing/extra/duplicate tier ${lane.tier} cases`);
    assert(lane.rows.every(row => statuses.includes(row.status)), 'Invalid status');
    assert(lane.rows.every(row => row.executed !== false && !['BLOCKED', 'SKIP'].includes(row.status) && !['SETUP', 'REPORT_MISSING', 'DEVICE_PREREQUISITE'].includes(row.errorCategory)), 'Unexecuted case');
  }
}

export async function main(args = process.argv.slice(2)) {
  const [backendPath, flutterPath, devicePath, outputPath] = args;
  if (!outputPath) throw new Error('Usage: report-local-catalog.mjs BACKEND_DIR FLUTTER_REPORT_JSON DEVICE_DIR OUTPUT_DIR');
  if (process.env.GITHUB_RUN_ID) throw new Error('This combined device report is LOCAL_ONLY');
  const inputs = [];
  async function read(path) {
    const bytes = await readFile(resolve(path));
    inputs.push({ path: resolve(path), sha256: createHash('sha256').update(bytes).digest('hex') });
    return JSON.parse(bytes);
  }
  const catalog = await catalogCases();
  const execution = await read(join(backendPath, 'execution.json'));
  assert.equal(execution.scope, 'backend-all');
  assert(!execution.attempts.some(row => row.spawnError || row.signal), 'Backend spawn/timeout error');
  const modules = [];
  for (const entry of await readdir(backendPath, { withFileTypes: true })) {
    if (!entry.isDirectory() || !entry.name.endsWith(`-${execution.runId}`) || entry.name.startsWith('sanity-original-')) continue;
    const report = await read(join(backendPath, entry.name, 'results.json'));
    assert(report.complete && report.provenance?.status === 'PASS' && report.cleanup?.status === 'PASS', `Incomplete module, provenance or cleanup: ${entry.name}`);
    modules.push(report);
  }
  assert.deepEqual(await readdir(join(backendPath, 'runtime')), [], 'Backend runtime cleanup incomplete');
  const flutter = await read(flutterPath), device = await read(join(devicePath, 'results.json'));
  assert(flutter.complete && flutter.source?.verified && flutter.implementedAndExecuted === 56, 'Incomplete Flutter evidence');
  assert(!device.partial && device.executed === 8 && device.provenance?.status === 'PASS' && device.cleanup?.status === 'PASS', 'Incomplete device execution/provenance/cleanup');
  assert.equal(device.infrastructureErrors.length, 0, 'Device infrastructure errors');
  assert(!device.cases.some(row => row.cleanup?.status === 'ERROR'), 'Device case cleanup failed');
  const lanes = [
    { tier: 'B', rows: modules.flatMap(report => report.results.map(row => ({ ...row, executionSourceSha: report.targetSha, executionHarnessSha: report.harnessSha }))) },
    { tier: 'F', rows: flutter.cases.map(row => ({ ...row, executionSourceSha: flutter.source.sha, executionHarnessSha: flutter.harnessSha })) },
    { tier: 'D', rows: device.cases.map(row => ({ ...row, executionMode: 'LOCAL_ONLY', executionSourceSha: device.sourceSha, executionHarnessSha: device.harnessSha })) },
  ];
  // Default to this run's application snapshot so future developer fixes can
  // be tested. An explicit historical baseline still requires identical trees.
  const baseline = process.env.VOCLE_APPLICATION_BASELINE_SHA || lanes[0].rows[0].executionSourceSha;
  assert.match(baseline, /^[a-f0-9]{40}$/);
  const repo = resolve(harnessRoot, '../..');
  const git = (...args) => execFileSync('git', ['-C', repo, ...args], { encoding: 'utf8', windowsHide: true }).trim();
  const appPaths = ['medcollab-backend/src', 'medcollab-backend/package.json', 'medcollab-backend/package-lock.json', 'medcollab-app/lib', 'medcollab-app/pubspec.yaml', 'medcollab-app/pubspec.lock'];
  const revisions = [...new Set(lanes.flatMap(lane => lane.rows.flatMap(row => [row.executionSourceSha, row.executionHarnessSha])))];
  const sourceObjects = {};
  for (const sha of revisions) {
    assert.match(sha, /^[a-f0-9]{40}$/);
    sourceObjects[sha] = Object.fromEntries(appPaths.map(path => {
      const object = git('rev-parse', `${sha}:${path}`);
      assert.equal(object, git('rev-parse', `${baseline}:${path}`), `Different application snapshot: ${sha}:${path}`);
      return [path, object];
    }));
  }
  validateLocalLanes(lanes, catalog);
  const rows = lanes.flatMap(lane => lane.rows);
  assert.deepEqual(execution.selectedIds.slice().sort(), lanes[0].rows.map(row => row.id).sort());
  const counts = Object.fromEntries(statuses.map(status => [status, rows.filter(row => row.status === status).length]));
  const result = counts.ERROR ? 'ERROR' : counts.PASS === 241 ? 'PASS' : 'FAIL';
  if (result === 'PASS') assert(execution.attempts.every(row => row.exitCode === 0) && flutter.flutterReporterSuccess && device.fullSuccess, 'Original lane gates must pass');
  const output = resolve(outputPath);
  await mkdir(output, { recursive: true });
  const { report } = await generate({ inputObject: {
    scope: 'local-full-241', source: { sha: baseline, kind: 'commit', verified: true },
    harness: { sha: null }, selectedIds: catalog.map(row => row.id), results: rows, tally: counts,
    gate: result, cleanup: { status: 'PASS' }, provenance: { status: 'PASS' },
  }, suite: 'developer', output, artifact: 'Local complete 241-case catalog' });
  report.title = 'Vocle full local functional regression';
  report.note += ' This is local execution across all three tiers. Application source and locks match the baseline shown above. Lane execution revisions can differ; each case retains its exact source/harness SHA. No single-revision full-suite success or hosted success marker is claimed. Android uses injected providers; iOS and real delivery are not covered.';
  const byId = new Map(rows.map(row => [row.id, row]));
  for (const row of report.results) {
    const original = byId.get(row.id);
    row.source = { sha: original.executionSourceSha, kind: 'commit', verified: true };
    row.harness = { sha: original.executionHarnessSha };
  }
  await writeReports(output, report);
  await writeFile(join(output, 'local-execution-provenance.json'), JSON.stringify({
    baselineApplicationSha: baseline, reporterCheckoutSha: git('rev-parse', 'HEAD'), sourceObjects,
    selected: 241, executed: rows.length, counts, result,
    byTier: Object.fromEntries(lanes.map(lane => [lane.tier, { executed: lane.rows.length,
      revisions: [...new Set(lane.rows.map(row => row.executionHarnessSha))],
      counts: Object.fromEntries(statuses.map(status => [status, lane.rows.filter(row => row.status === status).length])) }])),
    backendCleanupReports: modules.length, backendCleanup: 'PASS', deviceCleanup: device.cleanup,
    inputs, hostedSuccessClaimed: false, iosExecuted: false, providerDeliveryProven: false,
  }, null, 2) + '\n');
  console.log(JSON.stringify({ selected: 241, executed: rows.length, counts, result }));
  if (result !== 'PASS') process.exitCode = 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
