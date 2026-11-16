import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import { selectSanityGroups } from '../../sanity/src/scenarios.js';
import { catalogCases, selectBackendRun } from './ci-contracts.mjs';
import { collectFeatureEvidence } from './feature-evidence.mjs';
import { readFeatureRegistry, selectFeature, validateFeatureRegistry } from './feature-registry.mjs';
import { validateFeatureDropdown, validateFeatures, workflowPath } from './validate-features.mjs';

const root = resolve(import.meta.dirname, '../../..');
const cases = await catalogCases();
const registry = await readFeatureRegistry();
const features = validateFeatureRegistry(registry, cases);

test('the catalog, registry, executor inventory, matrix and dropdown agree', async () => {
  await validateFeatures(root, cases);
  assert.deepEqual(selectFeature(features, cases, 'all').map(row => row.id), cases.map(row => row.id));
  for (const [id, feature] of features) {
    const selection = selectFeature(features, cases, id);
    assert.deepEqual(new Set(selection.map(row => row.id)), new Set(feature.caseIds));
    assert.equal(selection.length, feature.caseIds.length);
  }
  const shared = 'FR-MED-04';
  assert(features.get('voice-messaging').caseIds.includes(shared));
  assert(features.get('media-sharing').caseIds.includes(shared));
  assert.equal(selectFeature(features, cases, 'all').filter(row => row.id === shared).length, 1);
  assert.throws(() => selectFeature(features, cases, ''));
  assert.throws(() => selectFeature(features, cases, 'unknown'));
});

test('invalid, unknown, duplicate and unmapped registry entries are rejected', () => {
  for (const mutate of [
    copy => { copy.features[0].id = 'Bad-Feature'; },
    copy => { copy.features[1].id = copy.features[0].id; },
    copy => { copy.features[0].caseIds.push('FR-NOT-99'); },
    copy => { copy.features[0].caseIds.push(copy.features[0].caseIds[0]); },
    copy => { copy.features[0].caseIds = []; },
    copy => { copy.catalogCount++; },
    copy => { for (const item of copy.features) item.caseIds = item.caseIds.filter(id => id !== 'FR-NDL-55'); },
  ]) {
    const copy = structuredClone(registry);
    mutate(copy);
    assert.throws(() => validateFeatureRegistry(copy, cases));
  }
  assert.throws(() => validateFeatureRegistry(registry, [cases[0], ...cases.slice(0, -1)]), /catalog count mismatch/);
});

test('a stale dropdown or accidental automatic trigger fails validation', async () => {
  const workflow = (await readFile(join(root, workflowPath), 'utf8')).replaceAll('\r\n', '\n');
  assert.throws(() => validateFeatureDropdown(workflow.replace('          - needl\n', ''), features), /out of sync/);
  assert.throws(() => validateFeatureDropdown(workflow.replace('  workflow_dispatch:', '  push:\n  workflow_dispatch:'), features), /manual/);
});

test('backend selection does not expand retained case dependencies into other cases', async () => {
  const selected = await selectBackendRun(cases, 'backend-feature', [], 'needl');
  const retained = selected.filter(row => row.coverage === 'EXISTING').map(row => row.id);
  assert(retained.includes('direct-and-group-conversations-05'));
  assert(!retained.includes('message-requests-01'));
  const planned = selectSanityGroups(retained.join(',')).flatMap(group => group.scenarios);
  assert.deepEqual(planned.map(row => row.id), retained);
  assert.throws(() => selectSanityGroups(''));
  assert.throws(() => selectSanityGroups('startup-01,startup-01'));
});

test('feature evidence gates failures, missing and unrelated results and lists Android as local-only', () => {
  const selected = [{ id: 'backend', tier: 'B' }, { id: 'flutter', tier: 'F' }, { id: 'android', tier: 'D' }];
  const valid = [
    { tier: 'B', results: [{ id: 'backend', status: 'PASS' }] },
    { tier: 'F', results: [{ id: 'flutter', status: 'PASS' }] },
  ];
  const evidence = collectFeatureEvidence(selected, valid);
  assert.equal(evidence.gate, 'PASS');
  assert.deepEqual(evidence.results.at(-1), {
    id: 'android', status: 'SKIP', executed: false, executionMode: 'LOCAL_ONLY', error: 'Requires the local Android emulator runner.',
  });
  assert.equal(collectFeatureEvidence(selected, valid.slice(0, 1)).gate, 'ERROR');
  assert.equal(collectFeatureEvidence(selected, [...valid, { tier: 'F', results: [{ id: 'other', status: 'PASS' }] }]).gate, 'ERROR');
  assert.equal(collectFeatureEvidence(selected, [...valid, valid[0]]).gate, 'ERROR');
  const failed = structuredClone(valid);
  failed[0].results[0].status = 'FAIL';
  assert.equal(collectFeatureEvidence(selected, failed).gate, 'FAIL');
});

test('the Flutter reporter rejects both unrelated catalog tests and non-catalog tests', async () => {
  const scratch = await mkdtemp(join(tmpdir(), 'vocle-feature-report-'));
  try {
    const events = join(scratch, 'events.ndjson');
    for (const name of ['FR-NDL-39 unselected', 'uncatalogued test']) {
      await writeFile(events, [
        { type: 'testStart', test: { id: 1, name } },
        { type: 'testDone', testID: 1, result: 'success', hidden: false },
        { type: 'done', success: true },
      ].map(row => JSON.stringify(row)).join('\n'));
      const run = spawnSync(process.execPath, [join(import.meta.dirname, 'aggregate-flutter.mjs'), events, join(scratch, 'report')], {
        env: { ...process.env, VOCLE_FEATURE: 'handoff' }, encoding: 'utf8', windowsHide: true,
      });
      assert.notEqual(run.status, 0);
      assert.match(run.stderr, /Unknown Flutter catalog ID|Unselected Flutter testcase ran/);
    }
  } finally {
    await rm(scratch, { recursive: true, force: true });
  }
});
