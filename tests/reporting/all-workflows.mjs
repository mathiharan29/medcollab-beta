import { captureContext, executionIdentity } from '../developer-workflow/context.mjs';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { compare, root } from './report.mjs';
import { hash } from './scenarios.mjs';
import { priorCompatible } from './history.mjs';
// Independent reporting job: read existing evidence, never run application/provider code.
import { api, artifactReports } from './history.mjs';
import { profiles, catalogFor, adaptSecurity, recoverSecurity, jobEvidence, jobOutcomeEvidence, settledWorkflowJobs } from './workflow-adapters.mjs';
import { sanitize, writeReports, summary } from './report.mjs';
import { writeFile } from 'node:fs/promises';
const workflow=process.env.VOCLE_REPORT_FILE, profile=profiles[workflow];
if (!profile || process.env.GITHUB_REPOSITORY !== 'mathiharan29/medcollab-beta') throw new Error('Reporting restricted to authorized repository and included workflows');
const runId=process.env.GITHUB_RUN_ID, runUrl=`https://github.com/mathiharan29/medcollab-beta/actions/runs/${runId}`;
const needs=JSON.parse(process.env.VOCLE_REPORT_NEEDS || '{}');
const originalGate=Object.values(needs).some(n=>['failure','cancelled'].includes(n.result))?'FAILURE':Object.values(needs).every(n=>n.result==='skipped')?'SKIP':'SUCCESS';
const fingerprint=execFileSync(process.execPath,[join(root,'tests/functional-regression/scripts/fingerprint.mjs')],{encoding:'utf8',windowsHide:true,timeout:30000}).trim();
const options={context:captureContext(root),execution:executionIdentity(),fingerprint, environmentFingerprint:hash(JSON.stringify({version:1,scope:profile.kind,platform:process.platform,node:process.versions.node,backendLock:await (await import('node:fs/promises')).readFile(join(root,'medcollab-backend/package-lock.json'),'utf8')})),sha:process.env.VOCLE_REPORT_SHA||process.env.GITHUB_SHA,runUrl,title:profile.title,gate:originalGate};
const errors=[];let jobs=[],artifacts=[],jobMetadataUnavailable=null;
try { jobs=await settledWorkflowJobs(attempt=>api(`/actions/runs/${runId}/attempts/${process.env.GITHUB_RUN_ATTEMPT}/jobs?per_page=100&inspection=${Date.now()}-${attempt}`)); } catch(e){jobMetadataUnavailable=e.message;}
try { artifacts=(await api(`/actions/runs/${runId}/artifacts?per_page=100`)).artifacts.filter(a=>!a.expired); } catch(e){errors.push({status:'ERROR',category:'ARTIFACT_EVIDENCE',message:e.message});}
let report=jobMetadataUnavailable?jobOutcomeEvidence(needs,options):jobEvidence(jobs,options);report.workflowJobs=jobs.map(j=>({name:j.name,conclusion:j.conclusion,steps:j.steps}));report.lanes=[];
if(originalGate==='SKIP')report.infrastructure=[{status:'SKIP',category:'WORKFLOW',message:'Original workflow jobs intentionally skipped; no test execution claimed.'}];
if (profile.artifact && originalGate!=='SKIP') {
  let input={};const a=artifacts.find(a=>a.name===`${profile.artifact}-${runId}-${process.env.GITHUB_RUN_ATTEMPT}`);
  if (a) { try { const raw=await artifactReports(a.id,true);if(raw.length!==1)throw new Error('Expected exactly one structured case report');input=raw[0]; }catch(e){errors.push({status:'ERROR',category:'CASE_EVIDENCE',message:e.message});} }
  else errors.push({status:'ERROR',category:'MISSING_CASE_EVIDENCE',message:'The original workflow did not upload usable case evidence; prerequisites or artifact hygiene may have failed. No case execution is claimed.'});
  try { report=adaptSecurity(input,await catalogFor(profile),profile,options); }catch(e){errors.push({status:'ERROR',category:'REPORT_VALIDATION',message:e.message});report=recoverSecurity(input,await catalogFor(profile),profile,options);}
  report.workflowJobs=jobs.map(j=>({name:j.name,conclusion:j.conclusion,steps:j.steps}));
  if(a)report.lanes=[{suite:profile.kind,counts:report.counts,artifact:{name:a.name,id:a.id,runUrl},comparison:report.comparison}];
}
if(profile.kind==='developer')for(const a of artifacts.filter(a=>a.name.startsWith('developer-qa-'))){
  try { for(const r of await artifactReports(a.id))report.lanes.push({suite:a.name+' / '+r.scope,counts:r.counts,artifact:{name:a.name,id:a.id,runUrl},comparison:r.comparison}); }
  catch(e){errors.push({status:'ERROR',category:'DEVELOPER_EVIDENCE',message:e.message});}
}
report.title=profile.title;report.runUrl=runUrl;report.infrastructure.push(...errors);report.originalGate=originalGate;
report.workflowNeeds=needs;
if(jobMetadataUnavailable)report.jobMetadata={source:'github.needs',stepDetailsAvailable:false,reason:jobMetadataUnavailable};
report.comparison={available:false,reason:'Workflow/provider/scanner reports are not compared to functional case baselines. Original lane comparison is retained when supplied.'};
report= sanitize(report);
const artifact=`vocle-qa-dashboard-${workflow}-${runId}-${process.env.GITHUB_RUN_ATTEMPT}`;
await writeReports(process.argv[2]||'vocle-visual-report',report,{artifact});
if (report.suite === 'security') {
  try {
    const previous = await priorCompatible(report, compare);
    report.comparison = previous ? { ...compare(report, previous.report), baselineRunId:previous.runId, baselineAttempt:previous.attempt } : { available:false,reason:'History credentials or execution identity unavailable' };
  } catch(error) { report.comparison={available:false,reason:sanitize(error.message)}; }
  report.comparison.status=report.comparison.available?'AVAILABLE':'UNAVAILABLE';
  if(report.comparison.available)for(const row of report.results)row.change=report.comparison.rows.find(r=>r.id===row.id)?.classification;
  await writeReports(process.argv[2]||'vocle-visual-report',report,{artifact});
}
if(process.env.GITHUB_STEP_SUMMARY)await writeFile(process.env.GITHUB_STEP_SUMMARY,summary(report,artifact),{flag:'a'});
if(errors.length)process.exitCode=1;
