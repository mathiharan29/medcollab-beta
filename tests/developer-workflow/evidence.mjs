import { historyProblem } from './context.mjs';
import { createHash } from 'node:crypto';
import { readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { join } from 'node:path';

export const hash = value => createHash('sha256').update(value).digest('hex');
export const statuses = ['PASS', 'FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP', 'OBSERVATION'];
export function securityOutcome(row) {
  if (statuses.includes(row.status)) return row.status;
  if (row.status === 'INFRASTRUCTURE_FAILURE') return 'ERROR';
  if (row.passed === true) return 'PASS';
  if (row.passed === false) return 'OBSERVATION';
  throw new Error('Unknown security outcome');
}
export const gate = rows => ['ERROR', 'FAIL', 'BLOCKED', 'NEEDS_DECISION', 'SKIP'].find(s => rows.some(r => r.required && r.status === s)) || 'PASS';
export function assertionExecuted(row) {
  if (!row || ['BLOCKED', 'SKIP'].includes(row.status) || ['SETUP', 'DEVICE_PREREQUISITE', 'INVALID_CASE_ID', 'DEPENDENCY'].includes(row.errorCategory)) return false;
  return typeof row.executed === 'boolean' ? row.executed : true;
}
const xml = value => String(value ?? '').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
export const json = value => JSON.stringify(value, null, 2) + '\n';

export async function writeEvidence(directory, report) {
  await mkdir(directory, { recursive: true });
  if (!report.results.length || new Set(report.results.map(r => r.id)).size !== report.results.length || report.results.some(r => !statuses.includes(r.status) || (r.status === 'PASS' && !r.executed))) throw new Error('Invalid result IDs/statuses or unexecuted PASS');
  report.schemaVersion = 1;
  report.generatedAt ||= new Date().toISOString();
  report.gate = gate(report.results);
  report.releaseGate = report.scope === 'full' ? report.gate === 'PASS' ? 'NEEDS_DECISION' : report.gate : 'NOT_EVALUATED';
  const bytes = json(report);
  const reportChecksum = hash(bytes);
  const manifest = { schemaVersion: 1, context: report.context, execution: report.execution, scope: report.scope, source: report.source, harness: report.harness, environment: report.environment,
    executedIds: report.results.filter(r => r.executed).map(r => r.id),
    coverage: report.results.map(({ id, required, status, executed, exclusion }) => ({ id, required, status, executed, exclusion })),
    timestamp: report.generatedAt, gate: report.gate, releaseGate: report.releaseGate, reportChecksum,
    commitEvidence: report.source.kind === 'commit' && report.source.verified && report.integrity === 'PASS',
    integrity: report.integrity,
    note: 'Checksums detect changed artifacts; independent hosted CI establishes trust.' };
  const junit = report.results.map(r => `<testcase classname="${xml(r.module || 'TOOLING')}" name="${xml(r.id)}">${r.status === 'PASS' ? '' : ['SKIP', 'OBSERVATION'].includes(r.status) ? `<skipped message="${xml(r.exclusion)}"/>` : `<${r.status === 'ERROR' ? 'error' : 'failure'} message="${xml(r.status)}">${xml(r.error || r.exclusion || r.status)}</${r.status === 'ERROR' ? 'error' : 'failure'}>`}</testcase>`).join('\n');
  const markdown = `# Vocle developer regression\n\nLocal gate: **${report.gate}**; release gate: **${report.releaseGate}**; integrity: **${report.integrity}**.\nApplication: ${report.source.sha}; kind: ${report.source.kind}; fingerprint: ${report.source.fingerprint}.\nHarness: ${report.harness.sha}; fingerprint: ${report.harness.fingerprint}.\nTimestamp: ${report.generatedAt}.\n\nA working-tree report certifies only the recorded bytes. Required omissions prevent PASS. Optional coverage remains explicit. A local PASS still requires independent hosted CI and applicable QA approval for release.\n\n| ID | Requirement | Status | Executed | Diagnostic/exclusion |\n| --- | --- | --- | --- | --- |\n${report.results.map(r => `| ${r.id} | ${r.required ? 'required' : 'optional'} | ${r.status} | ${Boolean(r.executed)} | ${String(r.error || r.exclusion || '').replaceAll('|', '/').replaceAll('\n', ' ').slice(0, 600)} |`).join('\n')}\n`;
  await Promise.all([
    writeFile(join(directory, 'results.json'), bytes), writeFile(join(directory, 'manifest.json'), json(manifest)),
    writeFile(join(directory, 'report.md'), markdown),
    writeFile(join(directory, 'junit.xml'), `<?xml version="1.0"?>\n<testsuite name="Vocle developer" tests="${report.results.length}" failures="${report.results.filter(r => !['PASS', 'ERROR', 'SKIP', 'OBSERVATION'].includes(r.status)).length}" errors="${report.results.filter(r => r.status === 'ERROR').length}" skipped="${report.results.filter(r => ['SKIP', 'OBSERVATION'].includes(r.status)).length}">\n${junit}\n</testsuite>\n`),
    writeFile(join(directory, 'submission.md'), `## Regression evidence\n\nApplication: \`${report.source.sha}\` (${report.source.kind}).\nHarness: \`${report.harness.sha}\` / \`${report.harness.fingerprint}\`.\nGate: **${report.gate}**; report SHA-256: \`${reportChecksum}\`.\n\nAttach results.json and manifest.json together, or link a CI artifact containing them; replace REPORT_URL below.\n\nRegression-Report: REPORT_URL\nRegression-Report-SHA256: ${reportChecksum}\nRegression-Source: ${report.source.kind === 'commit' ? report.source.sha : 'working-tree:' + report.source.fingerprint}\n\nHosted CI must test the exact submitted SHA and applicable coverage. No developer claim or checksum replaces that verification.\n`),
  ]);
  await rm(join(directory, 'pass-manifest.json'), { force: true });
  if (manifest.commitEvidence && manifest.gate === 'PASS') await writeFile(join(directory, 'pass-manifest.json'), json(manifest));
  return manifest;
}

export async function verifyEvidence(directory) {
  const bytes = await readFile(join(directory, 'results.json'));
  const report = JSON.parse(bytes);
  const manifest = JSON.parse(await readFile(join(directory, 'manifest.json'), 'utf8'));
  if (hash(bytes) !== manifest.reportChecksum) throw new Error('Report checksum mismatch');
  if (JSON.stringify(manifest.context) !== JSON.stringify(report.context) || JSON.stringify(manifest.execution) !== JSON.stringify(report.execution)) throw new Error('Context/execution manifest mismatch');
  if (manifest.releaseGate !== report.releaseGate || (report.releaseGate && report.releaseGate !== (report.scope === 'full' ? report.gate === 'PASS' ? 'NEEDS_DECISION' : report.gate : 'NOT_EVALUATED'))) throw new Error('Release gate mismatch');
  if (report.schemaVersion !== 1 || manifest.schemaVersion !== 1 || !report.results?.length || report.integrity !== 'PASS' || !report.source.verified || !report.harness.verified) throw new Error('Unverified report provenance/integrity');
  if (!/^[a-f0-9]{40}$/.test(report.source.sha) || !/^[a-f0-9]{40}$/.test(report.harness.sha) || !/^[a-f0-9]{64}$/.test(report.source.fingerprint) || !/^[a-f0-9]{64}$/.test(report.harness.fingerprint)) throw new Error('Invalid provenance identifiers');
  const ids = report.results.map(r => r.id);
  if (new Set(ids).size !== ids.length || report.results.some(r => !r.id || !statuses.includes(r.status) || (r.status === 'PASS' && !r.executed) || typeof r.required !== 'boolean' || typeof r.executed !== 'boolean' || !r.definitionFingerprint)) throw new Error('Invalid result set');
  if (gate(report.results) !== report.gate || manifest.gate !== report.gate || manifest.scope !== report.scope || JSON.stringify(manifest.environment) !== JSON.stringify(report.environment) || JSON.stringify(manifest.source) !== JSON.stringify(report.source) || JSON.stringify(manifest.harness) !== JSON.stringify(report.harness) || JSON.stringify(manifest.coverage) !== JSON.stringify(report.results.map(({ id, required, status, executed, exclusion }) => ({ id, required, status, executed, exclusion }))) || JSON.stringify(manifest.executedIds) !== JSON.stringify(report.results.filter(r => r.executed).map(r => r.id))) throw new Error('Manifest/report mismatch');
  return report;
}

export function comparisonProblem(old, current) {
  const contextError = historyProblem(current, old);
  if (contextError) return contextError;
  if (old.scope !== current.scope || old.source.kind !== current.source.kind || old.source.kind !== 'commit') return 'Changed scope or source kind';
  if (old.harness.fingerprint !== current.harness.fingerprint || JSON.stringify(old.environment) !== JSON.stringify(current.environment)) return 'Changed harness or environment contract';
  const definitions = r => JSON.stringify(r.results.map(x => [x.id, x.definitionFingerprint, x.environmentFingerprint, x.required]).sort((a, b) => a[0].localeCompare(b[0])));
  if (definitions(old) !== definitions(current)) return 'Changed case definitions or coverage';
  return null;
}

export function compareReports(old, current) {
  const a = new Map(old.results.map(r => [r.id, r])), b = new Map(current.results.map(r => [r.id, r]));
  const contextError = historyProblem(current, old);
  const sourceComparable = !contextError && old.scope === current.scope && old.source.kind === current.source.kind && old.source.kind === 'commit';
  const rows = [...new Set([...a.keys(), ...b.keys()])].sort().map(id => {
    const before = a.get(id), after = b.get(id);
    let classification, reason;
    if (!sourceComparable) { classification = 'NOT_COMPARABLE'; reason = contextError || 'Changed report scope or working-tree source provenance'; }
    else if (!before) classification = 'NEW_TEST';
    else if (!after) classification = 'REMOVED_TEST';
    else if (!before.executed || !after.executed || old.harness.fingerprint !== current.harness.fingerprint || before.definitionFingerprint !== after.definitionFingerprint || before.environmentFingerprint !== after.environmentFingerprint || before.required !== after.required) {
      classification = 'NOT_COMPARABLE'; reason = 'Dirty source, omitted execution, changed harness/definition/environment/coverage';
    } else if (before.status === 'FAIL' && after.status === 'PASS') classification = 'FIXED';
    else if (before.status === 'PASS' && after.status === 'FAIL') classification = 'NEW_REGRESSION';
    else if (before.status === 'FAIL' && after.status === 'FAIL') classification = 'STILL_FAILING';
    else if (before.status === 'PASS' && after.status === 'PASS') classification = 'STILL_PASSING';
    else classification = 'STATUS_CHANGED';
    return { id, oldStatus: before?.status, newStatus: after?.status, classification, reason };
  });
  return { available: !contextError && sourceComparable, reason: contextError || (!sourceComparable ? 'Changed scope/source kind' : null), oldSource: old.source, newSource: current.source, oldHarness: old.harness, newHarness: current.harness, rows };
}

export async function compareEvidence(oldDirectory, newDirectory, output) {
  const old = await verifyEvidence(oldDirectory), current = await verifyEvidence(newDirectory);
  const reason = comparisonProblem(old, current);
  const comparison = { ...compareReports(old, current), ...(reason ? { available: false, status: 'UNAVAILABLE', reason } : { available: true, status: 'AVAILABLE' }) };
  await mkdir(output, { recursive: true });
  await writeFile(join(output, 'comparison.json'), json(comparison));
  await writeFile(join(output, 'comparison.md'), `# Revision comparison\n\nOld application: ${comparison.oldSource.sha}; harness: ${comparison.oldHarness.sha} / ${comparison.oldHarness.fingerprint}.\nNew application: ${comparison.newSource.sha}; harness: ${comparison.newHarness.sha} / ${comparison.newHarness.fingerprint}.\n\n| ID | Old | New | Classification | Reason |\n| --- | --- | --- | --- | --- |\n${comparison.rows.map(r => `| ${r.id} | ${r.oldStatus || '-'} | ${r.newStatus || '-'} | ${r.classification} | ${r.reason || ''} |`).join('\n')}\n`);
  return comparison;
}
