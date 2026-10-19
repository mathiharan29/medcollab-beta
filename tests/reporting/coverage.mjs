export function addLocalOnlyAndroid(rows, metadata, source, harness) {
  if (rows.some(r => metadata.some(c => c.tier === 'D' && c.id === r.id))) throw new Error('Local Android evidence cannot be relabeled as hosted execution');
  return [...rows, ...metadata.filter(c => c.tier === 'D').map(c => ({ ...c, status:'SKIP', executionMode:'LOCAL_ONLY', executed:false,
    actual:'Available through the developer-local emulator runner', source, harness, steps:c.steps, durationMs:null, evidenceFiles:[], owner:'UNASSIGNED' }))];
}
