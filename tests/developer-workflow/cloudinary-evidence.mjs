import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { hash } from './evidence.mjs';

// Import only sanitized, source-bound measurements from the existing provider
// launcher. This does not execute or redefine any provider assertion.
export async function providerEvidence(directory, sourceSha, harness) {
  const read = async file => JSON.parse(await readFile(join(directory, file)));
  const state = await read('local-session.json');
  const report = await read('vocle-cloudinary-results/results.json');
  const cleanup = await read('vocle-cloudinary-results/post-job-cleanup.json');
  const safety = await read('vocle-cloudinary-results/safety.json');
  const journal = await read('vocle-cloudinary-results/resources.json');
  const manifest = JSON.parse(await readFile(join(harness, 'medcollab-backend/scripts/security-cloudinary/manifest.json')));
  if (state.sourceSha !== sourceSha || report.source !== sourceSha || report.executionMode !== 'local') throw new Error('Provider source/local identity mismatch');
  if (!state.providerExecuted || state.status !== 'PASS' || state.cleanup !== 'PASS' || state.providerCleanup !== 'PASS' || cleanup.proven !== true || cleanup.pendingUnresolved !== 0 || cleanup.broadDeletionUsed !== false || cleanup.resources.some(row => row.originAbsent !== true) || report.failure || report.counts.infrastructureFailures) throw new Error('Provider execution or cleanup is incomplete');
  for (const binding of [safety, journal]) if (binding.source !== report.source || binding.runId !== report.runId || binding.attempt !== report.attempt || binding.root !== report.namespace) throw new Error('Provider cleanup journal identity mismatch');
  const expected = manifest.cases.map(row => row.caseId);
  const measured = report.cases;
  if (report.counts.executed !== manifest.count || report.counts.registered !== manifest.count || measured.length !== manifest.count || new Set(measured.map(row => row.caseId)).size !== manifest.count || measured.some(row => !expected.includes(row.caseId) || !['PASS', 'OBSERVATION'].includes(row.status))) throw new Error('Provider measured catalog incomplete or invalid');
  if (!report.safety?.positiveAllowlistMatched || !report.safety.approvedTestCloudOnly || !report.safety.syntheticFixturesOnly || !report.safety.appSourceUnchanged || report.safety.network?.blocked !== 0) throw new Error('Provider safety evidence invalid');
  if (report.counts.pass !== measured.filter(row => row.status === 'PASS').length || report.counts.observations !== measured.filter(row => row.status === 'OBSERVATION').length) throw new Error('Provider recorded counts mismatch');
  for (const name of ['guard.js', 'run.js', 'cases.js', 'broker.js', 'fixtures.js', 'manifest.json', 'check.js']) {
    const fingerprint = hash(await readFile(join(harness, 'medcollab-backend/scripts/security-cloudinary', name)));
    if (state.harnessFiles?.[name] !== fingerprint) throw new Error('Provider definitions differ from the current harness');
  }
  return { report, rows: measured.map(row => ({ ...row, id: 'cloudinary:' + row.caseId, catalogId: row.caseId, suite: 'cloudinary', required: false, executed: true, status: row.status, recordedStatus: row.status, module: 'SECURITY', harness: { sha: state.harnessSha }, artifacts: ['cloudinary/results.json'] })) };
}
