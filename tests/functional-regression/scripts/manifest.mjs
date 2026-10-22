import { captureContext, executionIdentity } from '../../developer-workflow/context.mjs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { catalogCases, completeBackendSuccess, environmentContractVersion, forkRepository, harnessRoot, selectBackend, statuses, upstreamRef, upstreamRepository, validateResultSet } from './ci-contracts.mjs';

const output = resolve(process.env.VOCLE_OUTPUT_DIR || join(harnessRoot, 'output'));
const target = process.env.VOCLE_TARGET_DIR;
const scope = process.env.VOCLE_SCOPE || 'backend-all';
const sourceKind = process.env.VOCLE_TARGET_KIND || 'upstream-read-only';
const targetSha = process.env.VOCLE_TARGET_SHA;
const harnessSha = process.env.VOCLE_HARNESS_SHA;
const fingerprint = process.env.VOCLE_FINGERPRINT;
const affected = (process.env.VOCLE_AFFECTED_MODULES || '').split(',').filter(Boolean);
const sha = (directory, ref = 'HEAD') => execFileSync('git', ['-C', directory, 'rev-parse', ref], { encoding: 'utf8' }).trim();
const fileHash = async (path) => createHash('sha256').update(await readFile(path)).digest('hex');
const xml = (value) => String(value ?? '').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
await mkdir(output, { recursive: true });
let selected = [], results = [], reports = [], execution, integrityError = null, provenance, cleanup, tally, result = 'ERROR';
try {
  if (!target || !/^[a-f0-9]{40}$/.test(targetSha || '') || !/^[a-f0-9]{40}$/.test(harnessSha || '') || !/^[a-f0-9]{64}$/.test(fingerprint || '')) throw new Error('Missing exact source, harness or fingerprint');
  selected = selectBackend(await catalogCases(), scope, affected);
  execution = JSON.parse(await readFile(join(output, 'execution.json'), 'utf8'));
  if (process.env.VOCLE_REQUIRE_PREFLIGHT === 'true') {
    const preflight = JSON.parse(await readFile(join(output, 'preflight.json'), 'utf8'));
    if (preflight.status !== 'PASS' || !preflight.fakeProviderIntercepted || !preflight.unexpectedProviderRequestBlocked || !preflight.loopbackOnlyInterfaces || !preflight.outboundNetworkDenied) throw new Error('Provider/network isolation preflight failed');
  }
  if (JSON.stringify(execution.selectedIds) !== JSON.stringify(selected.map((item) => item.id))) throw new Error('Execution ID selection does not match catalog scope');
  const entries = await readdir(output, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory() || !entry.name.endsWith(`-${execution.runId}`)) continue;
    try {
      const report = JSON.parse(await readFile(join(output, entry.name, 'results.json'), 'utf8'));
      reports.push({ directory: entry.name, report });
    } catch { /* original sanity output has no adapted results.json */ }
  }
  const reportResults = reports.flatMap((item) => item.report.results || []);
  const expected = new Set(selected.map((item) => item.id));
  const duplicates = reportResults.map((item) => item.id).filter((id, index, ids) => ids.indexOf(id) !== index);
  const extra = reportResults.map((item) => item.id).filter((id) => !expected.has(id));
  const missing = selected.filter((item) => !reportResults.some((row) => row.id === item.id));
  if (duplicates.length || extra.length || missing.length) integrityError = `Report ID mismatch: missing=${missing.map((item) => item.id).join(',')}; extra=${extra.join(',')}; duplicate=${duplicates.join(',')}`;
  results = [...reportResults.filter((item) => expected.has(item.id)), ...missing.map((item) => ({ id: item.id, status: 'ERROR', errorCategory: 'REPORT_MISSING', error: 'No module result was produced', durationMs: 0 }))]
    .sort((a, b) => selected.findIndex((item) => item.id === a.id) - selected.findIndex((item) => item.id === b.id));
  const repoHead = sha(target), repoTree = sha(target, 'HEAD^{tree}'), harnessHead = sha(harnessRoot);
  const trackedChanges = execFileSync('git', ['-C', target, 'status', '--porcelain', '--untracked-files=no'], { encoding: 'utf8' }).trim();
  provenance = { status: repoHead === targetSha && harnessHead === harnessSha && !trackedChanges ? 'PASS' : 'ERROR', sourceKind, targetRepository: sourceKind === 'upstream-read-only' ? upstreamRepository : forkRepository, targetRef: sourceKind === 'upstream-read-only' ? upstreamRef : null, targetSha: repoHead, targetTree: repoTree, harnessSha: harnessHead, fingerprint, targetBackendLockSha256: await fileHash(join(target, 'medcollab-backend/package-lock.json')), harnessLockSha256: await fileHash(join(harnessRoot, 'package-lock.json')), trackedChanges };
  const runtimeEntries = await readdir(join(output, 'runtime')).catch(() => []);
  cleanup = { status: reports.length > 0 && reports.every((item) => item.report.cleanup?.status === 'PASS') && runtimeEntries.length === 0 ? 'PASS' : 'ERROR', reportCleanup: reports.map((item) => ({ directory: item.directory, cleanup: item.report.cleanup })), remainingRuntimeEntries: runtimeEntries };
  if (reports.some((item) => !item.report.complete || item.report.targetSha !== targetSha || item.report.harnessSha !== harnessSha || item.report.provenance?.status !== 'PASS')) integrityError = `${integrityError || ''} Incomplete or mismatched module report`.trim();
  if (execution.attempts.some((item) => item.spawnError || item.signal)) integrityError = `${integrityError || ''} Module spawn/timeout error`.trim();
  tally = Object.fromEntries(statuses.map((status) => [status, results.filter((item) => item.status === status).length]));
  if (tally.PASS === selected.length && execution.attempts.some((item) => item.exitCode !== 0)) integrityError = `${integrityError || ''} Module exited nonzero despite all-PASS reports`.trim();
  if (!integrityError) validateResultSet({ selected, results, targetSha, harnessSha, sourceKind, cleanup, provenance });
  result = integrityError || cleanup.status !== 'PASS' || provenance.status !== 'PASS' || tally.ERROR ? 'ERROR' : tally.FAIL || tally.BLOCKED || tally.NEEDS_DECISION || tally.SKIP ? 'FAIL' : 'PASS';
} catch (error) {
  integrityError = `${integrityError || ''} ${error.message}`.trim();
  if (selected.length && results.length === 0) results = selected.map((item) => ({ id: item.id, module: item.module, status: 'ERROR', errorCategory: 'REPORT_MISSING', error: `No validated report: ${error.message}`, durationMs: 0 }));
  if (!tally) tally = Object.fromEntries(statuses.map((status) => [status, results.filter((item) => item.status === status).length]));
  provenance ||= { status: 'ERROR', targetSha, harnessSha, sourceKind, error: error.message };
  cleanup ||= { status: 'ERROR', error: 'Unable to verify cleanup' };
}
const byId = new Map(selected.map((item) => [item.id, item]));
const enriched = results.map((item) => ({ ...item, title: byId.get(item.id)?.title, tier: byId.get(item.id)?.tier, priority: byId.get(item.id)?.priority, targetSha }));
const coverage = { planned: { total: 187, hosted: 179, localOnly: 8, backend: 147, flutter: 32, device: 8 }, localOnlyCases: (await catalogCases()).filter(c => c.tier === 'D').map(c => ({ id: c.id, executionMode: 'LOCAL_ONLY', executed: false, status: 'SKIP' })), scope, selected: selected.length, executed: enriched.filter((item) => item.errorCategory !== 'REPORT_MISSING').length, tally, byTier: Object.fromEntries(['B', 'F', 'D'].map((tier) => [tier, { selected: selected.filter((item) => item.tier === tier).length, executed: enriched.filter((item) => item.tier === tier && item.errorCategory !== 'REPORT_MISSING').length }])), byPriority: Object.fromEntries(['P0', 'P1', 'P2'].map((priority) => [priority, { selected: selected.filter((item) => item.priority === priority).length, executed: enriched.filter((item) => item.priority === priority && item.errorCategory !== 'REPORT_MISSING').length }])) };
const verifiedBackendAll = result === 'PASS' && completeBackendSuccess({ scope, selected, tally, cleanup, provenance });
const manifest = { context: captureContext(harnessRoot), execution: executionIdentity(), schemaVersion: 1, environmentContractVersion, scope, sourceKind, targetSha, harnessSha, fingerprint, selectedIds: selected.map((item) => item.id), tally, result, verifiedBackendAll, integrityError, runId: process.env.GITHUB_RUN_ID || null, attempt: process.env.GITHUB_RUN_ATTEMPT || null };
await Promise.all([
  writeFile(join(output, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`),
  writeFile(join(output, 'results.json'), `${JSON.stringify({ ...manifest, results: enriched }, null, 2)}\n`),
  writeFile(join(output, 'coverage.json'), `${JSON.stringify(coverage, null, 2)}\n`),
  writeFile(join(output, 'provenance.json'), `${JSON.stringify(provenance, null, 2)}\n`),
  writeFile(join(output, 'cleanup.json'), `${JSON.stringify(cleanup, null, 2)}\n`),
  writeFile(join(output, 'junit.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<testsuite name="vocle-functional-regression" tests="${enriched.length}" failures="${tally.FAIL + tally.BLOCKED + tally.NEEDS_DECISION}" errors="${tally.ERROR}" skipped="${tally.SKIP}">\n${enriched.map((item) => `  <testcase classname="${xml(item.module || byId.get(item.id)?.module || 'UNKNOWN')}" name="${xml(item.id)}" time="${((item.durationMs || 0) / 1000).toFixed(3)}">${item.status === 'PASS' ? '' : item.status === 'ERROR' ? `<error message="${xml(item.error || 'Infrastructure error')}"/>` : item.status === 'SKIP' ? `<skipped message="${xml(item.error || 'Unselected scope')}"/>` : `<failure message="${xml(item.status + ': ' + (item.error || 'Functional requirement not met'))}"/>`}</testcase>`).join('\n')}\n</testsuite>\n`),
  writeFile(join(output, 'report.md'), `# Vocle functional regression\n\n- Scope: ${scope}; source: ${sourceKind} \`${targetSha || 'unresolved'}\`\n- Result: **${result}**; backend-all success: **${verifiedBackendAll}**\n- PASS ${tally.PASS}; FAIL ${tally.FAIL}; ERROR ${tally.ERROR}; BLOCKED ${tally.BLOCKED}; NEEDS_DECISION ${tally.NEEDS_DECISION}; SKIP ${tally.SKIP}\n- Selected ${selected.length}; executed ${coverage.executed}; catalog 187 total / 179 hosted / 8 LOCAL_ONLY (B/F/D 147/32/8)\n- Provenance ${provenance.status}; cleanup ${cleanup.status}${integrityError ? `\n- Integrity error: ${integrityError}` : ''}\n\n${enriched.filter((item) => item.status !== 'PASS').map((item) => `- ${item.id} **${item.status}**: ${item.error || ''}`).join('\n')}\n`.trimEnd() + '\n'),
]);
if (process.env.GITHUB_OUTPUT) await writeFile(process.env.GITHUB_OUTPUT, `result=${result}\nreport_ready=${integrityError ? 'false' : 'true'}\nverified_backend_all=${verifiedBackendAll}\n`, { flag: 'a' });
console.log(JSON.stringify({ result, scope, selected: selected.length, tally, verifiedBackendAll, integrityError }, null, 2));
