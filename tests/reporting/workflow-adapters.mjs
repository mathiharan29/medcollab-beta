import { hash } from './scenarios.mjs';
// Reporting-only adapters. Never execute test/provider code or alter original gates.
import { normalize, sanitize, statuses, root } from './report.mjs';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';

export async function settledWorkflowJobs(read, { attempts = 3, wait = ms => new Promise(resolve => setTimeout(resolve, ms)) } = {}) {
  const deadline = Date.now() + 30000;
  for (let attempt = 0; attempt < attempts; attempt++) {
    if (Date.now() >= deadline) break;
    const jobs = (await read(attempt)).jobs.filter(j => j.name !== 'Visual QA report' && !j.name.startsWith('Visual QA report /'));
    if (jobs.length && jobs.every(j => j.status === 'completed' && j.conclusion &&
      (j.conclusion === 'skipped' || j.steps?.length > 0))) return jobs;
    if (attempt + 1 < attempts) await wait(5000);
  }
  throw new Error('Completed source job metadata did not become available within the retry budget; no step execution evidence inferred');
}

export function jobOutcomeEvidence(needs, options = {}) {
  const outcomes = { success: 'PASS', failure: 'FAIL', cancelled: 'BLOCKED', skipped: 'SKIP' };
  const entries = Object.entries(needs || {});
  if (!entries.length || entries.some(([,value]) => !Object.hasOwn(outcomes,value?.result))) throw new Error('Missing or invalid authoritative workflow needs results');
  const rows = entries.map(([id,value]) => ({ id: `workflow-job-${id}`, title: id, module: options.title || 'Workflow',
    status: outcomes[value.result], executed: ['success','failure'].includes(value.result), category: 'WORKFLOW_JOB',
    expected: 'The original workflow job completes successfully.',
    actual: `GitHub Actions needs context reports ${value.result}. Individual step details are unavailable; no application testcase execution is inferred.`,
    evidence: { source: 'github.needs', jobId: id, result: value.result } }));
  const report=normalize({source:{sha:options.sha,kind:'commit',verified:true},harness:{sha:options.sha},results:rows,gate:options.gate},[],{suite:'workflow-checks',context:options.context,execution:options.execution,runUrl:options.runUrl});
  report.title=options.title;report.inventoryKind='workflow job results';
  report.note='Job conclusions come from the GitHub Actions needs context supplied by the owning workflow. Step details were unavailable from the API. These are job-level records, not application testcase, scanner finding or secret-match coverage.';
  return report;
}

export const profiles = {
  'vocle-backend-environment-test.yml': { title: 'Vocle API & Realtime Security', artifact: 'vocle-security-discovery', kind: 'discovery', scope: 'Real HTTP and controlled database/socket state. Observations require separate security review.' },
  'vocle-data-security.yml': { title: 'MongoDB data security', artifact: 'vocle-mongodb-data-security', kind: 'data', manifest: 'security-data', scope: 'Disposable MongoDB; HTTP, model and handler scopes remain individually labeled.' },
  'vocle-media-security.yml': { title: 'Offline media security', artifact: 'vocle-offline-media-security', kind: 'media', manifest: 'security-media', scope: 'Real isolated backend with test-owned SDK doubles. No real provider coverage.' },
  'vocle-cloudinary-security.yml': { title: 'Cloudinary security', artifact: 'vocle-real-cloudinary-security', kind: 'cloudinary', manifest: 'security-cloudinary', scope: 'Only existing recorded provider evidence is reported. No provider operations are performed by reporting. Controller-level evidence does not prove route/auth/database coverage.' },
  'secrets-scan.yml': { title: 'Repository secret scan', kind: 'scan', scope: 'Scanner job/step outcomes only. Raw secret matches and SARIF snippets are never downloaded or published.' },
  'vocle-developer-qa.yml': { title: 'Developer QA integration', kind: 'developer', scope: 'Tooling and isolated smoke evidence. Matrix jobs and profiles are distinct; they are not summed as unique application cases.' },
};
const stringify = value => typeof value === 'string' ? value : JSON.stringify(value ?? 'Not captured', null, 2);
export async function catalogFor(profile) {
  if (profile.manifest) return JSON.parse(await readFile(join(root, 'medcollab-backend/scripts', profile.manifest, 'manifest.json'), 'utf8')).cases;
  if (profile.kind === 'discovery') {
    // The existing --list mode is static: no MongoDB, authentication or providers.
    const list = JSON.parse(execFileSync(process.execPath, [join(root, 'medcollab-backend/scripts/security-api-discovery.js'), '--list'], { encoding: 'utf8', windowsHide: true }));
    return list.cases.map((c, i) => ({ ...c, caseId: `VOCLE-${String(i + 1).padStart(3, '0')}` }));
  }
  return [];
}
export function adaptSecurity(input, catalog, profile, options = {}) {
  const recordedSource = input.provenance?.source || input.source;
  if (recordedSource && options.sha && recordedSource !== options.sha) throw new Error('Security source identity differs from the checked-out execution');
  const raw = input.results || input.cases || [];
  if (!Array.isArray(raw) || new Set(raw.map(r=>r.caseId)).size !== raw.length) throw new Error('Duplicate/invalid security case evidence');
  const known = new Map(catalog.map(c=>[c.caseId,c]));
  if (raw.some(r=>!known.has(r.caseId))) throw new Error('Security evidence contains an unknown manifest ID');
  const rows = raw.map(r => {
    const recorded = r.status || (r.passed === true ? 'PASS' : r.passed === false ? 'OBSERVATION' : null);
    const status = recorded === 'INFRASTRUCTURE_FAILURE' ? 'ERROR' : recorded;
    if (![...statuses,'OBSERVATION'].includes(status)) throw new Error('Unknown security outcome');
    return { ...known.get(r.caseId), ...r, id: r.caseId, title:r.name, status, originalSecurityStatus:recorded, executed: typeof r.executed === 'boolean' ? r.executed : !['SKIP', 'BLOCKED'].includes(status),
      expected:stringify(r.expected || { statuses:known.get(r.caseId).statuses, semanticCheck:known.get(r.caseId).hasSemanticCheck }),
      actual:stringify(r.actual), evidence:stringify(r.actual), category:status==='OBSERVATION'?'SECURITY_OBSERVATION_REQUIRES_REVIEW':status==='PASS'?'PASS':'INFRASTRUCTURE_OR_HARNESS_ERROR',
      assertionExpected:stringify(r.expected), assertionActual:stringify(r.actual), rootCause:r.rootCause || undefined,
      module:r.module || r.category || r.scope || profile.title };
  });
  for (const c of catalog.filter(c=>!raw.some(r=>r.caseId===c.caseId))) rows.push({ ...c, id:c.caseId,title:c.name,status:'ERROR',executed:false,errorCategory:'REPORT_MISSING',error:'No execution record for this manifest case; inspect workflow prerequisites.' });
  const executed = raw.filter(r=>r.executed!==false&&!['SKIP','BLOCKED'].includes(r.status)).length;
  for (const [field,expected] of [['executed',executed],['passed',raw.filter(r=>r.passed===true||r.status==='PASS').length],['observations',raw.filter(r=>r.passed===false||r.status==='OBSERVATION').length],['unexpected',raw.filter(r=>r.passed===false||r.status==='OBSERVATION').length]]) if (Number.isFinite(input[field]) && input[field]!==expected) throw new Error('Original security tally disagrees with recorded rows: '+field);
  if (input.counts) for (const [field, expected] of [['registered',catalog.length],['executed',raw.length],['pass',raw.filter(r=>r.status==='PASS').length],['observations',raw.filter(r=>r.status==='OBSERVATION').length]]) if (Number.isFinite(input.counts[field]) && input.counts[field]!==expected) throw new Error('Original provider tally disagrees with recorded rows: '+field);
  const metadata = catalog.map(c=>{const recorded=raw.find(r=>r.caseId===c.caseId);return ({id:c.caseId,title:recorded?.name||c.name,module:recorded?.module||c.module||c.category||c.scope||profile.title,priority:'UNSPECIFIED',tier:'SECURITY',definitionFingerprint:hash(JSON.stringify(c)),
    scenario:recorded?.report?.whatItChecks || `${c.name}. ${c.actor ? 'Synthetic actor '+c.actor+' performs the recorded action.' : 'Execute the documented isolated security probe.'}`,
    prerequisites:recorded?.report?.testSetup ? stringify(recorded.report.testSetup) : c.context || 'Use only deterministic synthetic fixtures in the owning suite. '+profile.scope,
    reproduction:'API/environment procedure; no UI or production incident is claimed. Use the owning workflow at the recorded source revision.',
    expected:recorded?.report?.expectedSecurityBehaviour || stringify(recorded?.expected || c.expected || {statuses:c.statuses,semanticCheck:c.hasSemanticCheck}),
    steps:[{number:1,action:'Prepare the owning suite fixtures and safety prerequisites.',expected:'Isolation and prerequisites verified before the action.'},{number:2,action:recorded?.report?.actionPerformed ? stringify(recorded.report.actionPerformed)+'; mutation: '+stringify(recorded.report.mutation) : c.method?`${c.actor||'suite actor'}: ${c.method} ${c.endpoint}`:c.name,expected:recorded?.report?.expectedSecurityBehaviour || stringify(recorded?.expected||c.expected||{statuses:c.statuses,semanticCheck:c.hasSemanticCheck})},{number:3,action:'Independently inspect the recorded database, transport/provider and cleanup evidence.',expected:'Recorded semantic checks and resource cleanup satisfy the unchanged suite contract.'}],limitations:profile.scope,definitions:[],questionIds:[],sourceReferences:recorded?.sources||c.sources||[] });});
  const report = normalize({synthetic:input.synthetic===true,source:{sha:input.provenance?.source||input.source||options.sha||'UNKNOWN',kind:'commit',verified:true},harness:{sha:options.sha||'UNKNOWN',fingerprint:options.fingerprint},environmentContractVersion:1,scope:profile.kind,results:rows,gate:options.gate||'See original workflow job'},metadata,{suite:'security',context:options.context,execution:options.execution,statuses:[...statuses,'OBSERVATION'],runUrl:options.runUrl,environmentFingerprint:options.environmentFingerprint});
  for(const row of report.results){const original=raw.find(r=>r.caseId===row.id);if(original){row.originalSecurityStatus=original.status||(original.passed?'PASS':'OBSERVATION');row.originalSecurityClassification=original.classification||null;row.originalPassed=original.passed??null;}}
  report.title=profile.title;report.inventoryKind='security cases';report.observationsAreNonBlocking=true;
  report.originalSecurityCounts={planned:input.planned??input.counts?.registered??catalog.length,executed,passed:raw.filter(r=>r.passed===true||r.status==='PASS').length,observations:raw.filter(r=>r.passed===false||r.status==='OBSERVATION').length};
  report.applicationFailures=sanitize(input.applicationFailures||[]);
  if (input.infrastructureFailure||input.failure) report.infrastructure.push({status:'ERROR',category:'ORIGINAL_INFRASTRUCTURE',message:stringify(input.infrastructureFailure||input.failure)});
  report.note='OBSERVATION preserves the original security outcome; it is neither an accepted expectation nor a confirmed vulnerability. Original non-blocking security gate behavior is unchanged. '+profile.scope;
  return sanitize(report);
}
export function recoverSecurity(input, catalog, profile, options = {}) {
  const raw = Array.isArray(input.results || input.cases) ? (input.results || input.cases) : [];
  const retained = new Map();
  for (const row of raw) {
    if (!catalog.some(c => c.caseId === row.caseId)) continue;
    const status = row.status || (row.passed === false ? 'OBSERVATION' : null);
    if (!['FAIL','OBSERVATION','ERROR','INFRASTRUCTURE_FAILURE','BLOCKED','SKIP','NEEDS_DECISION'].includes(status)) continue;
    if (!retained.has(row.caseId) || status === 'FAIL') retained.set(row.caseId, { ...row, status, executed:false });
  }
  const report = adaptSecurity({ results:[...retained.values()] }, catalog, profile, options);
  report.originalObservations = sanitize(raw);
  report.originalSource = input.provenance?.source || input.source || null;
  report.infrastructure.push({ status:'ERROR', category:'REPORT_VALIDATION', message:'Malformed original evidence: recorded non-pass observations are retained without claiming validated execution; other rows require current evidence.' });
  return report;
}

export function jobEvidence(jobs, options = {}) {
  const rows=jobs.flatMap(j=>j.steps.filter(s=>!/^Post |^Complete job$/.test(s.name)).map(s=>{
    const state=s.conclusion==='success'?'PASS':s.conclusion==='failure'?'FAIL':s.conclusion==='skipped'?'SKIP':s.conclusion==='cancelled'?'BLOCKED':'ERROR';
    const duration=s.started_at&&s.completed_at?Date.parse(s.completed_at)-Date.parse(s.started_at):null;
    return {id:`job-${j.id}-step-${s.number}`,title:s.name,module:j.name,status:state,executed:!['SKIP','BLOCKED','ERROR'].includes(state),durationMs:Number.isFinite(duration)?Math.max(0,duration):null,expected:'The existing workflow step completes successfully within its original gate.',actual:`GitHub records ${s.conclusion||s.status}. No individual testcase, scanner finding, matched secret or production behavior is inferred.`,evidence:`Job ${j.name}; step ${s.number}; conclusion ${s.conclusion||s.status}.`,category:'WORKFLOW_STEP',failingStep:s.name};
  }));
  const report=normalize({source:{sha:options.sha,kind:'commit',verified:true},harness:{sha:options.sha},results:rows,gate:options.gate},[],{suite:'workflow-checks',context:options.context,execution:options.execution,runUrl:options.runUrl});
  report.title=options.title;report.inventoryKind='workflow checks';report.note='These are GitHub workflow step records, not new testcase IDs or application coverage. Missing case evidence remains separately visible.';
  return report;
}
