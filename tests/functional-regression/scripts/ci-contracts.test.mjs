import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { catalogCases, completeBackendSuccess, environmentContractVersion, selectBackend, statuses, upstreamRef, upstreamRepository, validateResultSet } from './ci-contracts.mjs';
import { affectedModules, affectsFlutter } from './affected-modules.mjs';

const targetSha = 'a'.repeat(40), harnessSha = 'b'.repeat(40), fingerprint = 'c'.repeat(64);
const cases = await catalogCases();
const selected = selectBackend(cases, 'backend-all');
const expectedIds = selected.map((item) => item.id);
const tally = Object.fromEntries(statuses.map((status) => [status, status === 'PASS' ? 147 : 0]));
const cleanup = { status: 'PASS' };
const provenance = { status: 'PASS', targetSha, harnessSha };
const reportArtifact = { digest: `sha256:${'d'.repeat(64)}`, expired: false };
const evidence = { schemaVersion: 1, environmentContractVersion, targetRepository: upstreamRepository, targetRef: upstreamRef,
  sourceKind: 'upstream-read-only', scope: 'backend-all', targetSha, harnessSha, fingerprint, result: 'PASS', verifiedBackendAll: true,
  provenance, cleanup, reportArtifactDigest: reportArtifact.digest, selectedIds: expectedIds, tally, resultsSha256: 'e'.repeat(64) };

test('catalog selection keeps all 147 backend IDs and retained 48', () => {
  assert.equal(selected.length, 147);
  const subset = selectBackend(cases, 'backend-p0');
  assert(subset.length >= 48 && subset.length < 147);
  assert.equal(subset.filter((item) => item.coverage === 'EXISTING').length, 48);
});

test('fork changes select mapped modules; unknown shared changes select all', () => {
  assert.deepEqual(affectedModules(['medcollab-backend/src/features/handoffs/handoff.controller.js']), ['NOT', 'SRCH', 'HOF', 'JRN']);
  assert.equal(affectedModules(['medcollab-backend/src/middleware/auth.js']).length, 19);
  assert.equal(affectedModules(['tests/functional-regression/suites/handoffs.mjs']).length, 19);
});

test('Flutter lane runs for client and reporter changes, and unknown diffs', () => {
  assert(affectsFlutter(['medcollab-app/lib/app.dart']));
  assert(affectsFlutter(['medcollab-app/test/functional_regression/runtime_recovery_test.dart']));
  assert(affectsFlutter(['tests/functional-regression/scripts/aggregate-flutter.mjs']));
  assert(affectsFlutter(['tests/reporting/report.mjs']));
  assert(affectsFlutter([]));
  assert(!affectsFlutter(['medcollab-backend/src/features/handoffs/handoff.controller.js']));
});

test('full success requires exact IDs, status, source and cleanup', () => {
  const results = selected.map((item) => ({ id: item.id, status: 'PASS' }));
  assert.equal(validateResultSet({ selected, results, targetSha, harnessSha, sourceKind: 'upstream-read-only', cleanup, provenance }).PASS, 147);
  assert(completeBackendSuccess({ scope: 'backend-all', selected, tally, cleanup, provenance }));
  assert(!completeBackendSuccess({ scope: 'backend-p0', selected, tally, cleanup, provenance }));
  assert.throws(() => validateResultSet({ selected, results: results.slice(1), targetSha, harnessSha, sourceKind: 'upstream-read-only', cleanup, provenance }), /Missing/);
  assert.throws(() => validateResultSet({ selected, results: [...results.slice(0, -1), results[0]], targetSha, harnessSha, sourceKind: 'upstream-read-only', cleanup, provenance }), /duplicate/);
  assert.throws(() => validateResultSet({ selected, results, targetSha, harnessSha, sourceKind: 'upstream-read-only', cleanup: { status: 'ERROR' }, provenance }), /Cleanup/);
});

test('PR target pins the exact head and full scope; unsupported contexts fail', () => {
  const script = fileURLToPath(new URL('./resolve-target.mjs', import.meta.url));
  const env = { ...process.env, GITHUB_EVENT_NAME: 'pull_request', GITHUB_REPOSITORY: upstreamRepository, VOCLE_PR_HEAD_REPOSITORY: upstreamRepository, VOCLE_PR_HEAD_SHA: targetSha };
  delete env.GITHUB_OUTPUT;
  const run = overrides => spawnSync(process.execPath, [script], { env: { ...env, ...overrides }, encoding: 'utf8', windowsHide: true });
  const good = run({});assert.equal(good.status, 0, good.stderr);
  assert.deepEqual(JSON.parse(good.stdout), { targetKind: 'pr-head', targetSha, scope: 'backend-all', targetRepository: upstreamRepository });
  for (const overrides of [{ VOCLE_PR_HEAD_SHA: 'invalid' }, { VOCLE_PR_HEAD_REPOSITORY: 'other/repo' }, { GITHUB_EVENT_NAME: 'push' }, { GITHUB_EVENT_NAME: 'workflow_dispatch' }, { GITHUB_REPOSITORY: 'other/repo' }]) assert.notEqual(run(overrides).status, 0);
});
