import assert from 'node:assert/strict';
import { test } from 'node:test';
import { validateLocalLanes } from './report-local-catalog.mjs';

const catalog = ['B', 'F', 'D'].map(tier => ({ id: `fixture-${tier}`, tier }));
const lanes = () => catalog.map(row => ({ tier: row.tier, rows: [{ id: row.id, status: 'PASS', executed: true }] }));

test('local completeness requires every tier and exactly its own unique IDs', () => {
  assert.throws(() => validateLocalLanes(lanes().slice(0, 2), catalog));
  const missing = lanes(); missing[2].rows = [];
  assert.throws(() => validateLocalLanes(missing, catalog));
  const duplicate = lanes(); duplicate[0].rows.push({ ...duplicate[0].rows[0] });
  assert.throws(() => validateLocalLanes(duplicate, catalog));
  const misplaced = lanes(); misplaced[0].rows[0].id = 'fixture-D';
  assert.throws(() => validateLocalLanes(misplaced, catalog));
});

test('unexecuted, skipped, blocked and missing-report rows cannot claim a complete run', () => {
  for (const patch of [{ executed: false }, { status: 'SKIP' }, { status: 'BLOCKED' }, { status: 'UNKNOWN' }, { errorCategory: 'REPORT_MISSING' }, { errorCategory: 'SETUP' }]) {
    const rows = lanes(); Object.assign(rows[0].rows[0], patch);
    assert.throws(() => validateLocalLanes(rows, catalog));
  }
});

test('executed failures and unresolved decisions are retained without becoming passes', () => {
  const rows = lanes(); rows[0].rows[0].status = 'FAIL'; rows[1].rows[0].status = 'NEEDS_DECISION';
  validateLocalLanes(rows, catalog);
  assert.deepEqual(rows.flatMap(lane => lane.rows.map(row => row.status)), ['FAIL', 'NEEDS_DECISION', 'PASS']);
});
