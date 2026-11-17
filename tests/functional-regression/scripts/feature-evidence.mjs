import { statuses } from './ci-contracts.mjs';
import { prerecordedVoiceIds } from './device-contracts.mjs';

export function collectFeatureEvidence(selected, lanes) {
  const expected = new Map(selected.map(row => [row.id, row]));
  const observed = new Map();
  const issues = [];
  for (const { tier, results, error } of lanes) {
    if (error) issues.push(error);
    for (const row of results) {
      if (!row || expected.get(row.id)?.tier !== tier || tier === 'D' || !statuses.includes(row.status) ||
          (row.status === 'PASS' && row.executed === false)) {
        issues.push(`Unexpected or invalid ${tier} observation: ${row?.id ?? 'missing ID'}`);
        continue;
      }
      if (observed.has(row.id)) {
        issues.push(`Duplicate observation: ${row.id}`);
        if (row.status === 'FAIL') observed.set(row.id, row);
        continue;
      }
      observed.set(row.id, row);
    }
  }
  const results = selected.map(row => {
    if (row.tier === 'D' && prerecordedVoiceIds.includes(row.id)) return {
      id: row.id, status: 'SKIP', executed: false, executionMode: 'HOSTED',
      error: 'Runs in the separate prerecorded digital audio selection.',
    };
    if (row.tier === 'D') return {
      id: row.id, status: 'SKIP', executed: false, executionMode: 'LOCAL_ONLY',
      error: 'Requires the local Android emulator runner.',
    };
    if (observed.has(row.id)) return observed.get(row.id);
    issues.push(`Missing execution evidence: ${row.id}`);
    return { id: row.id, status: 'ERROR', executed: false, errorCategory: 'REPORT_MISSING', error: 'No result from the selected executor.' };
  });
  const gate = issues.length || results.some(row => row.status === 'ERROR') ? 'ERROR'
    : results.some(row => row.status !== 'PASS' && expected.get(row.id).tier !== 'D') ? 'FAIL'
    : observed.size === 0 ? 'NOT_EXECUTED' : 'PASS';
  return { results, gate, issues };
}
