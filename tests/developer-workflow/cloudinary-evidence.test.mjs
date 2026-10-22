import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { providerEvidence } from './cloudinary-evidence.mjs';
import { hash } from './evidence.mjs';

test('provider import requires complete source-bound cases, unchanged definitions and independently proven cleanup', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'vocle-provider-evidence-'));
  const harness = resolve(import.meta.dirname, '../..');
  const suite = join(harness, 'medcollab-backend/scripts/security-cloudinary');
  const source = 'a'.repeat(40);
  const manifest = JSON.parse(await readFile(join(suite, 'manifest.json')));
  const hashes = {};
  for (const name of ['guard.js', 'run.js', 'cases.js', 'broker.js', 'fixtures.js', 'manifest.json', 'check.js']) hashes[name] = hash(await readFile(join(suite, name)));
  const identity = { source, runId: '12345', attempt: '1', root: 'synthetic-offline-namespace' };
  const state = { sourceSha: source, harnessSha: source, providerExecuted: true, status: 'PASS', cleanup: 'PASS', providerCleanup: 'PASS', harnessFiles: hashes };
  const report = { source, runId: identity.runId, attempt: '1', namespace: identity.root, executionMode: 'local', counts: { registered: 34, executed: 34, pass: 34, observations: 0, infrastructureFailures: 0 }, safety: { positiveAllowlistMatched: true, approvedTestCloudOnly: true, syntheticFixturesOnly: true, appSourceUnchanged: true, network: { blocked: 0 } }, cases: manifest.cases.map(row => ({ ...row, status: 'PASS' })) };
  const cleanup = { proven: true, pendingUnresolved: 0, broadDeletionUsed: false, resources: [{ originAbsent: true }] };
  const put = async (name, value) => writeFile(join(directory, name), JSON.stringify(value));
  try {
    await mkdir(join(directory, 'vocle-cloudinary-results'));
    await put('local-session.json', state);
    for (const name of ['safety.json', 'resources.json']) await put('vocle-cloudinary-results/' + name, identity);
    await put('vocle-cloudinary-results/results.json', report);
    await put('vocle-cloudinary-results/post-job-cleanup.json', cleanup);
    assert.equal((await providerEvidence(directory, source, harness)).rows.length, 34);
    await assert.rejects(providerEvidence(directory, 'b'.repeat(40), harness), /identity mismatch/);
    await put('vocle-cloudinary-results/post-job-cleanup.json', { ...cleanup, proven: false });
    await assert.rejects(providerEvidence(directory, source, harness), /cleanup is incomplete/);
    await put('vocle-cloudinary-results/post-job-cleanup.json', cleanup);
    await put('vocle-cloudinary-results/results.json', { ...report, cases: report.cases.slice(1) });
    await assert.rejects(providerEvidence(directory, source, harness), /catalog incomplete/);
    await put('vocle-cloudinary-results/results.json', report);
    await put('local-session.json', { ...state, harnessFiles: { ...hashes, 'fixtures.js': 'tampered' } });
    await assert.rejects(providerEvidence(directory, source, harness), /definitions differ/);
  } finally { await rm(directory, { recursive: true, force: true }); }
});
