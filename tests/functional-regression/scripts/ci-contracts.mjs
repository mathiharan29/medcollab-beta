import { readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const harnessRoot = resolve(fileURLToPath(new URL('../', import.meta.url)));
export const environmentContractVersion = 1;
export const upstreamRepository = 'mathiharan29/medcollab-beta';
export const upstreamRef = 'refs/heads/master';
export const forkRepository = 'mathiharan29/medcollab-beta';
export const suiteFiles = Object.freeze({
  AUTH: 'auth', PRO: 'profile', DISC: 'discovery', SPC: 'spaces', CH: 'channels', REQ: 'requests', DM: 'conversations',
  MSG: 'messages', THR: 'threads', SOC: 'social', NOT: 'notifications', PUSH: 'push-contracts', RT: 'realtime', SRCH: 'search',
  HOF: 'handoffs', MED: 'media', SUP: 'support', RUN: 'runtime', JRN: 'journeys',
});
export const statuses = Object.freeze(['PASS', 'FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP']);

export async function catalogCases() {
  const catalog = JSON.parse(await readFile(join(harnessRoot, 'catalog.json'), 'utf8'));
  if (catalog.cases.length !== 187 || new Set(catalog.cases.map((item) => item.id)).size !== 187) throw new Error('Catalog size/uniqueness changed');
  return catalog.cases;
}

export function selectBackend(cases, scope, affectedModules = []) {
  if (!['backend-all', 'backend-p0'].includes(scope)) throw new Error(`Invalid backend scope ${scope}`);
  const affected = new Set(affectedModules);
  if ([...affected].some((module) => !suiteFiles[module])) throw new Error('Unknown affected module');
  const selectedIds = new Set(cases.filter((item) => item.tier === 'B' && (scope === 'backend-all' || item.coverage === 'EXISTING' || item.priority === 'P0' || affected.has(item.module))).map((item) => item.id));
  const byId = new Map(cases.map((item) => [item.id, item]));
  for (const id of selectedIds) for (const dependency of byId.get(id)?.dependencies || []) {
    if (byId.get(dependency)?.tier !== 'B') throw new Error(`Backend case ${id} depends on non-backend case ${dependency}`);
    selectedIds.add(dependency);
  }
  const selected = cases.filter((item) => selectedIds.has(item.id));
  if (scope === 'backend-all' && selected.length !== 147) throw new Error('Backend-all requires 147 catalog IDs');
  return selected;
}

export function validateResultSet({ selected, results, targetSha, harnessSha, sourceKind, cleanup, provenance }) {
  const expected = new Set(selected.map((item) => item.id));
  const actual = results.map((item) => item.id);
  if (actual.length !== expected.size || new Set(actual).size !== actual.length || actual.some((id) => !expected.has(id))) throw new Error('Missing, extra or duplicate case IDs');
  if (results.some((item) => !statuses.includes(item.status))) throw new Error('Unknown case status');
  if (!/^[a-f0-9]{40}$/.test(targetSha || '') || !/^[a-f0-9]{40}$/.test(harnessSha || '')) throw new Error('Invalid source/harness SHA');
  if (!['upstream-read-only', 'pr-head', 'commit', 'committed-fork-archive'].includes(sourceKind)) throw new Error('Invalid source kind');
  if (cleanup?.status !== 'PASS' || provenance?.status !== 'PASS' || provenance.targetSha !== targetSha || provenance.harnessSha !== harnessSha) throw new Error('Cleanup or provenance failed');
  return Object.fromEntries(statuses.map((status) => [status, results.filter((item) => item.status === status).length]));
}

export function completeBackendSuccess({ scope, selected, tally, cleanup, provenance }) {
  return scope === 'backend-all' && selected.length === 147 && tally.PASS === 147 && statuses.filter((status) => status !== 'PASS').every((status) => tally[status] === 0) && cleanup.status === 'PASS' && provenance.status === 'PASS';
}
