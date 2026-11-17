import { prerecordedVoiceIds } from '../functional-regression/scripts/device-contracts.mjs';

export function catalogCoverage(metadata, results = []) {
  const modes = new Map(results.map(row => [row.id, row]));
  const cases = metadata.filter(row => row.tier === 'D').map(row => {
    const observed = modes.get(row.id);
    return {
      id: row.id,
      executionMode: observed?.executionMode ?? (prerecordedVoiceIds.includes(row.id) ? 'HOSTED' : 'LOCAL_ONLY'),
      executed: observed?.executed ?? false,
      status: observed?.status ?? 'SKIP',
    };
  });
  const hostedAndroid = metadata.filter(row => prerecordedVoiceIds.includes(row.id)).length;
  return { total: metadata.length, hosted: metadata.length - cases.length,
    localOnly: cases.length - hostedAndroid, hostedAndroid, cases };
}

export function addLocalOnlyAndroid(rows, metadata, source, harness) {
  if (rows.some(r => metadata.some(c => c.tier === 'D' && c.id === r.id))) throw new Error('Local Android evidence cannot be relabeled as hosted execution');
  return [...rows, ...metadata.filter(c => c.tier === 'D').map(c => {
    const hosted = prerecordedVoiceIds.includes(c.id);
    return { ...c, status: 'SKIP', executionMode: hosted ? 'HOSTED' : 'LOCAL_ONLY', executed: false,
      actual: hosted ? 'Available through the prerecorded digital audio selection' : 'Available through the developer-local emulator runner',
      source, harness, steps: c.steps, durationMs: null, evidenceFiles: [], owner: 'UNASSIGNED' };
  })];
}
