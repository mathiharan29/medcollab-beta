// Maintained deterministic reporter inputs. These are never execution evidence.
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

export const syntheticContext = { repository: 'mathiharan29/medcollab-beta', kind: 'pull_request', prNumber: 42, branchRef: 'refs/heads/synthetic-report-contract' };
export const syntheticExecution = () => ({ id: randomUUID(), mode: 'LOCAL', completed: true, completedAt: '2026-10-19T00:00:00Z' });
export async function functionalInput(suite) {
  const catalog = JSON.parse(await readFile(new URL('../../functional-regression/catalog.json', import.meta.url))).cases;
  const selected = catalog.filter(c => suite === 'sanity' ? c.coverage === 'EXISTING' : c.tier === ({ backend: 'B', flutter: 'F', device: 'D' })[suite]);
  const statuses = ['PASS', 'FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP'];
  const rows = selected.map((c, i) => ({ id: c.id, status: statuses[i % statuses.length], executed: !['SKIP', 'BLOCKED'].includes(statuses[i % statuses.length]), error: i ? 'Synthetic format diagnostic' : undefined, durationMs: i + 1 }));
  const common = { synthetic: true, context: syntheticContext, execution: syntheticExecution(), sourceKind: suite === 'device' ? 'committed-fork-archive' : 'pr-head', environmentContractVersion: 1, targetSha: 'a'.repeat(40), harnessSha: 'b'.repeat(40), fingerprint: 'c'.repeat(64), scope: suite === 'backend' ? 'backend-all' : suite };
  if (suite === 'flutter') return { ...common, tier: 'F', cases: rows, counts: Object.fromEntries(statuses.map(s => [s, rows.filter(r => r.status === s).length])) };
  if (suite === 'sanity') return { ...common, metadata: { upstreamSha: common.targetSha, harnessSha: common.harnessSha }, scenarios: rows.map(r => ({ ...r, status: ({ PASS: 'passed', FAIL: 'failed', ERROR: 'error', BLOCKED: 'blocked', SKIP: 'skipped' })[r.status] || r.status })) };
  return { ...common, tier: suite === 'device' ? 'D' : 'B', results: rows };
}
export function securityInput(catalog, kind) {
  const observations = { discovery: 80, media: 35, data: 9 }[kind];
  const rows = catalog.map((c, i) => ({ ...c, caseId: c.caseId, name: c.name, passed: i >= observations, status: i < observations ? 'OBSERVATION' : 'PASS', expected: 'Synthetic contract result', actual: { synthetic: true, status: i < observations ? 403 : 200 } }));
  return { synthetic: true, results: rows, executed: rows.length, passed: rows.length - observations, observations };
}
