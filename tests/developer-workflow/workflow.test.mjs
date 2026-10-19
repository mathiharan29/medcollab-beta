import { syntheticContext, syntheticExecution } from '../reporting/fixtures/synthetic-inputs.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, readFile, writeFile, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { writeEvidence, verifyEvidence, compareEvidence, compareReports, gate, hash, assertionExecuted, securityOutcome } from './evidence.mjs';
import { defects } from './qa.mjs';
import { validateCoverage } from './coverage-policy.mjs';
import { validateSubmission } from './verify-submission.mjs';

const caseRow = (id, status, extra = {}) => ({ id, status, required: true, executed: true, module: 'AUTH', expected: 'Synthetic request returns authorized identity', definitionFingerprint: 'definition-v1', environmentFingerprint: 'environment-v1', ...extra });
test('security observations remain observations and explicit failures retain their status', () => {
  assert.equal(securityOutcome({passed:false}), 'OBSERVATION');
  assert.equal(securityOutcome({status:'OBSERVATION'}), 'OBSERVATION');
  assert.equal(securityOutcome({status:'FAIL',passed:false}), 'FAIL');
  assert.equal(securityOutcome({status:'INFRASTRUCTURE_FAILURE'}), 'ERROR');
  assert.equal(gate([caseRow('observation','OBSERVATION',{required:false})]), 'PASS');
});
test('setup errors and dependency blocks never inflate actual assertion execution', () => {
  assert.equal(assertionExecuted({ id: 'FR-AUTH-01', status: 'ERROR', errorCategory: 'SETUP', error: 'Backend health timed out' }), false);
  assert.equal(assertionExecuted({ status: 'BLOCKED', errorCategory: 'DEPENDENCY' }), false);
  assert.equal(assertionExecuted({ status: 'SKIP' }), false);
  assert.equal(assertionExecuted(undefined), false);
  assert.equal(assertionExecuted({ status: 'ERROR', executed: false }), false);
  for (const status of ['PASS', 'FAIL', 'NEEDS_DECISION']) assert.equal(assertionExecuted({ status }), true);
});
function report(results, sha = 'a'.repeat(40)) {
  return { context: syntheticContext, execution: syntheticExecution(), scope: 'synthetic-fixture', source: { sha, kind: 'commit', fingerprint: 'b'.repeat(64), verified: true }, harness: { sha: 'c'.repeat(40), fingerprint: 'd'.repeat(64), verified: true }, integrity: 'PASS', environment: { node: '22', synthetic: true }, results };
}

test('all comparison transitions, including omission and harness/environment drift', () => {
  const old = report([caseRow('fixed', 'FAIL'), caseRow('regression', 'PASS'), caseRow('failed', 'FAIL'), caseRow('passed', 'PASS'), caseRow('status', 'BLOCKED'), caseRow('removed', 'PASS'), caseRow('drift', 'PASS'), caseRow('omitted', 'PASS')]);
  const next = report([caseRow('fixed', 'PASS'), caseRow('regression', 'FAIL'), caseRow('failed', 'FAIL'), caseRow('passed', 'PASS'), caseRow('status', 'ERROR'), caseRow('new', 'PASS'), caseRow('drift', 'PASS', { environmentFingerprint: 'changed' }), caseRow('omitted', 'BLOCKED', { executed: false })], 'e'.repeat(40));
  assert.deepEqual(Object.fromEntries(compareReports(old, next).rows.map(r => [r.id, r.classification])), { drift: 'NOT_COMPARABLE', failed: 'STILL_FAILING', fixed: 'FIXED', new: 'NEW_TEST', omitted: 'NOT_COMPARABLE', passed: 'STILL_PASSING', regression: 'NEW_REGRESSION', removed: 'REMOVED_TEST', status: 'STATUS_CHANGED' });
  next.harness.fingerprint = 'f'.repeat(64);
  assert.equal(compareReports(old, next).rows.find(r => r.id === 'fixed').classification, 'NOT_COMPARABLE');
  next.harness.fingerprint = old.harness.fingerprint; next.source.kind = 'working-tree';
  assert.equal(compareReports(old, next).rows.find(r => r.id === 'passed').classification, 'NOT_COMPARABLE');
  assert.equal(compareReports(old, next).rows.find(r => r.id === 'new').classification, 'NOT_COMPARABLE');
  next.source.kind = 'commit'; next.scope = 'different-profile';
  assert(compareReports(old, next).rows.every(r => r.classification === 'NOT_COMPARABLE'));
});

test('real assertion failure and successful fixture produce verifiable reports and comparison', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'vocle-evidence-'));
  try {
    let outcome = 'PASS';
    try { assert.equal(2 + 2, 5); } catch { outcome = 'FAIL'; }
    const old = report([caseRow('synthetic-addition', outcome)]);
    const next = report([caseRow('synthetic-addition', 'PASS')], 'e'.repeat(40));
    assert.equal(2 + 2, 4);
    await writeEvidence(join(dir, 'old'), old);
    const manifest = await writeEvidence(join(dir, 'new'), next);
    assert.equal(manifest.gate, 'PASS');
    assert.equal(manifest.scope, 'synthetic-fixture');
    assert.equal(manifest.releaseGate, 'NOT_EVALUATED');
    assert.equal((await verifyEvidence(join(dir, 'old'))).gate, 'FAIL');
    assert.equal((await compareEvidence(join(dir, 'old'), join(dir, 'new'), join(dir, 'compare'))).rows[0].classification, 'FIXED');
    assert((await readFile(join(dir, 'old', 'junit.xml'), 'utf8')).includes('<failure'));
    assert((await readFile(join(dir, 'compare', 'comparison.md'), 'utf8')).includes('FIXED'));
    await stat(join(dir, 'new', 'pass-manifest.json'));
    next.scope = 'full';
    await writeEvidence(join(dir, 'new'), next);
    assert.equal((await verifyEvidence(join(dir, 'new'))).releaseGate, 'NEEDS_DECISION');
    next.source.kind = 'working-tree';
    await writeEvidence(join(dir, 'new'), next);
    await assert.rejects(stat(join(dir, 'new', 'pass-manifest.json')));
    await writeFile(join(dir, 'new', 'results.json'), '{}');
    await assert.rejects(verifyEvidence(join(dir, 'new')), /checksum/);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('tampered manifest, duplicate IDs and unverified source are rejected', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'vocle-evidence-'));
  try {
    await assert.rejects(writeEvidence(dir, report([caseRow('same', 'PASS'), caseRow('same', 'PASS')])), /IDs/);
    const r = report([caseRow('one', 'PASS')]);
    await writeEvidence(dir, r);
    const manifest = JSON.parse(await readFile(join(dir, 'manifest.json'))); manifest.source.sha = 'e'.repeat(40);
    await writeFile(join(dir, 'manifest.json'), JSON.stringify(manifest));
    await assert.rejects(verifyEvidence(dir), /mismatch/);
    r.source.verified = false; await writeEvidence(dir, r);
    await assert.rejects(verifyEvidence(dir), /provenance/);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('required red statuses gate; optional omissions remain visible', () => {
  for (const status of ['FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP']) assert.equal(gate([caseRow('x', status)]), status);
  assert.equal(gate([caseRow('x', 'PASS'), caseRow('optional', 'BLOCKED', { required: false, executed: false })]), 'PASS');
});

test('submission rejects wrong candidate, omitted required coverage and tooling-only success', () => {
  const r = report([caseRow('functional', 'PASS')]);
  const catalog = [{ id: 'functional', tier: 'B' }];
  assert.throws(() => validateSubmission(r, r.source.sha, catalog), /Full/);
  r.scope = 'full';
  assert.equal(validateSubmission(r, r.source.sha, catalog).status, 'PASS');
  assert.throws(() => validateSubmission(r, 'f'.repeat(40), catalog), /exact/);
  assert.throws(() => validateSubmission(r, r.source.sha, [...catalog, { id: 'missing', tier: 'F' }]), /omitted/);
  r.results[0].required = false;
  assert.throws(() => validateSubmission(r, r.source.sha, catalog), /Required/);
});

test('owners stay UNASSIGNED until approval and root causes group only with evidence', () => {
  const r = report([caseRow('a', 'FAIL'), caseRow('b', 'FAIL')]);
  assert.equal(defects(r, { approved: false, modules: { AUTH: '@unapproved' } }).length, 2);
  assert.deepEqual(defects(r)[0].suggestedOwner, ['UNASSIGNED']);
  r.results.forEach(row => row.rootCause = 'verified-common-setup');
  assert.equal(defects(r).length, 1);
  assert.deepEqual(defects(r)[0].testcaseIds, ['a', 'b']);
});

test('coverage requires registered new IDs, security justification and trusted exceptions', () => {
  const base = { oldCases: [{ id: 'FR-AUTH-01' }], newCases: [{ id: 'FR-AUTH-01' }], changedFiles: ['medcollab-backend/src/new-feature.js'] };
  assert.match(validateCoverage(base).join(' '), /requires/);
  const declaration = { schemaVersion: 1, newFeature: true, securityRelevant: false, reviewReason: 'Synthetic new endpoint', testcaseIds: ['FR-AUTH-01'], localCommand: 'local full suite', ciWorkflow: 'vocle-functional-regression.yml', crossFeatureReview: 'QA journey review pending', securityReason: 'No authorization or sensitive data change' };
  assert.match(validateCoverage({ ...base, declaration }).join(' '), /newly registered/);
  declaration.testcaseIds.push('FR-AUTH-02');
  assert.deepEqual(validateCoverage({ ...base, newCases: [...base.newCases, { id: 'FR-AUTH-02' }], declaration }), []);
  declaration.exceptionId = 'self-approved';
  assert.match(validateCoverage({ ...base, declaration }).join(' '), /trusted base/);
  assert.match(validateCoverage({ ...base, newCases: [], changedFiles: [] }).join(' '), /removed/);
  const exception = { id: 'approved-coverage-gap', approvedBy: 'authorized-fixture-maintainer', expiresAt: '2099-01-01', allowMissingCoverage: true, paths: base.changedFiles };
  assert.deepEqual(validateCoverage({ ...base, declaration: { exceptionId: exception.id, reviewReason: 'Approved scoped fixture waiver' }, authorizedExceptions: [exception] }), []);
  assert(validateCoverage({ ...base, changedFiles: ['medcollab-app/lib/unapproved.dart'], declaration: { exceptionId: exception.id, reviewReason: 'Out of scope' }, authorizedExceptions: [exception] }).length > 0);
});

test('baseline catalog and workflow integration remain connected to exact candidate and isolation', async () => {
  const root = join(import.meta.dirname, '../..');
  const catalog = JSON.parse(await readFile(join(root, 'tests/functional-regression/catalog.json')));
  assert.equal(catalog.cases.length, 187);
  const workflow = await readFile(join(root, '.github/workflows/vocle-functional-regression.yml'), 'utf8');
  assert(!workflow.includes('paths:'));
  assert(workflow.includes('tests/developer-workflow/qa.mjs'));
  assert(workflow.includes('--network none'));
  assert(workflow.includes('github.event.pull_request.head.sha || github.sha'));
  assert.equal(hash('fixture').length, 64);
});
