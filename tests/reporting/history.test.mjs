import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, writeFile, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { normalize, compare, root } from './report.mjs';
import { scenarioMetadata } from './scenarios.mjs';
import { sealReport, captureContext } from '../developer-workflow/context.mjs';
import { syntheticContext, syntheticExecution } from './fixtures/synthetic-inputs.mjs';
import { priorCompatible } from './history.mjs';
import { writeEvidence } from '../developer-workflow/evidence.mjs';
import { localComparison } from '../developer-workflow/local-history.mjs';

const metadata = await scenarioMetadata(root), ids = metadata.filter(c => c.tier === 'B').slice(0, 6).map(c => c.id);
function report(runId = '2', attempt = '1', statuses = ['PASS','FAIL','FAIL','PASS','ERROR','SKIP']) {
  return sealReport(normalize({ context: syntheticContext, execution: { id: `${runId}:${attempt}`, runId, attempt, mode:'HOSTED',completed:true,completedAt:'2026-10-19T00:00:00Z' },
    scope:'backend-all',sourceKind:'pr-head',targetSha:'a'.repeat(40),harnessSha:'b'.repeat(40),fingerprint:'c'.repeat(64),environmentContractVersion:1,selectedIds:ids,
    results:ids.map((id,i)=>({id,status:statuses[i],executed:statuses[i]!=='SKIP'})) }, metadata));
}
test('only executed PASS/FAIL assertions produce the four transitions; uncertainty is preserved',()=>{
  const before=report('1'),current=report('2','1',['FAIL','PASS','FAIL','PASS','ERROR','SKIP']);
  const comparison=compare(current,before);assert(comparison.available);
  assert.deepEqual(comparison.rows.slice(0,4).map(r=>r.classification),['NEW_REGRESSION','FIXED','STILL_FAILING','STILL_PASSING']);
  assert.equal(comparison.rows[4].classification,'UNCHANGED_NONPASS');assert.equal(comparison.rows[5].classification,'NOT_COMPARABLE');
  for(const status of ['BLOCKED','NEEDS_DECISION','ERROR','SKIP']){
    const changed=report('2');changed.results[0].status=status;changed.results[0].executed=status!=='BLOCKED'&&status!=='SKIP';
    assert(!['FIXED','NEW_REGRESSION','STILL_FAILING','STILL_PASSING'].includes(compare(changed,before).rows[0].classification));
  }
});
test('different PR, branch, mode, definitions, source kind, environment, incomplete, corrupt and self evidence are unavailable',()=>{
  for(const mutate of [r=>r.context.prNumber++,r=>delete r.context,r=>r.context.repository='other/repo',r=>r.execution.completed=false,r=>r.execution.mode='LOCAL',r=>r.execution.id='2:1',r=>r.definitionSet='changed',r=>r.environmentFingerprint='changed',r=>r.harness.fingerprint='changed',r=>r.sourceKind='working-tree',r=>delete r.evidenceIntegrity]){
    const previous=report('1');mutate(previous);if(previous.evidenceIntegrity)sealReport(previous);assert.equal(compare(report('2'),previous).available,false);
  }
  const previous=report('1');previous.results[0].status='FAIL';assert.equal(compare(report('2'),previous).available,false);
  const a=report('1'),b=report('2');a.context={repository:syntheticContext.repository,kind:'branch',branchRef:'refs/heads/a'};b.context={...a.context,branchRef:'refs/heads/b'};sealReport(a);assert.equal(compare(b,a).available,false);
  b.context={...a.context};assert(compare(b,a).available);a.context.branchRef=null;sealReport(a);assert.equal(compare(b,a).available,false);
});
test('detached local contexts do not infer a development branch',()=>{
  const c=captureContext(join(tmpdir(),'absent-repository'),{},{});assert.equal(c.branchRef,null);
});
test('rendering legacy rows never manufactures trustworthy execution context',()=>{
  const legacy=normalize({sourceKind:'pr-head',targetSha:'a'.repeat(40),harnessSha:'b'.repeat(40),fingerprint:'c'.repeat(64),environmentContractVersion:1,selectedIds:ids,results:ids.map(id=>({id,status:'PASS'}))},metadata);
  assert.equal(legacy.context,null);assert.equal(legacy.execution,null);sealReport(legacy);
  assert.equal(compare(report('2'),legacy).available,false);
});
test('synthetic report inputs cannot become historical execution evidence',()=>{
  const previous=report('1');previous.synthetic=true;sealReport(previous);
  assert.equal(compare(report('2'),previous).available,false);
});

const run = (id, extra = {}) => ({id,status:'completed',conclusion:'failure',run_attempt:1,event:'pull_request',pull_requests:[{number:42}],head_repository:{full_name:syntheticContext.repository},...extra});
async function hosted(fn) {
  const old={GITHUB_TOKEN:process.env.GITHUB_TOKEN,GITHUB_RUN_ID:process.env.GITHUB_RUN_ID};
  process.env.GITHUB_TOKEN='synthetic-history-test';process.env.GITHUB_RUN_ID='99';
  try { return await fn(); } finally { for(const[k,v]of Object.entries(old)) if(v===undefined)delete process.env[k];else process.env[k]=v; }
}
test('paginated newest-compatible completed failure is selected beyond three candidates and incompatible newer executions',async()=>hosted(async()=>{
  const calls=[],downloaded=[];
  const request=async path=>{
    calls.push(path);
    if(path.includes('/workflows/'))return {workflow_runs:path.endsWith('page=1')?Array.from({length:100},(_,i)=>run(1000+i,{pull_requests:[{number:999}]})):[run(5),run(4),run(3),run(2)]};
    const attempt=/runs\/(\d+)\/attempts\/(\d+)/.exec(path);
    if(attempt)return {status:'completed',head_sha:'a'.repeat(40),updated_at:`2026-10-${String(Number(attempt[1])+10).padStart(2,'0')}T00:00:00Z`};
    const id=/runs\/(\d+)\/artifacts/.exec(path)?.[1];
    return {artifacts:[{id:Number(id),name:`vocle-functional-report-${id}-1`,digest:'sha256:'+'d'.repeat(64),expired:false}]};
  };
  const download=async id=>{downloaded.push(id);const p=report(String(id));if(id>2)p.environmentFingerprint='incompatible';return [sealReport(p)];};
  const found=await priorCompatible(report('99'),compare,{request,download});assert.equal(found.runId,2);assert.deepEqual(downloaded,[5,4,3,2]);assert(calls.some(p=>p.endsWith('page=2')));assert(calls.every(p=>!p.includes('status=success')));
}));
test('earlier completed rerun attempt can compare independently of the current attempt',async()=>hosted(async()=>{
  const current=report('99','2');
  const request=async path=>path.includes('/workflows/')?{workflow_runs:[]}:path==='/actions/runs/99'?run(99,{status:'in_progress',run_attempt:2}):path.includes('/attempts/')?{status:'completed',head_sha:'a'.repeat(40),updated_at:'2026-10-18'}:{artifacts:[{id:1,name:'vocle-functional-report-99-1',digest:'sha256:'+'d'.repeat(64)}]};
  const found=await priorCompatible(current,compare,{request,download:async()=>[report('99','1')]});assert.equal(found.attempt,1);
}));
test('cross PR/branch candidates are never downloaded; history errors remain optional',async()=>hosted(async()=>{
  for(const branch of [false,true]){
    const current=report('99');if(branch)current.context={repository:syntheticContext.repository,kind:'branch',branchRef:'refs/heads/a'};
    await assert.rejects(priorCompatible(current,compare,{request:async()=>({workflow_runs:[run(1,{pull_requests:[{number:77}],head_branch:'b',event:branch?'push':'pull_request'})]}),download:async()=>{assert.fail('Cross-context download');}}),/No compatible/);
  }
  for(const message of ['HTTP 403','HTTP 404','HTTP 410','timed out','malformed JSON'])await assert.rejects(priorCompatible(report('99'),compare,{request:async()=>{throw new Error(message);}}),new RegExp(message));
}));
test('expired, inaccessible and corrupt history does not become comparison evidence',async()=>hosted(async()=>{
  for(const mode of ['expired','corrupt','inaccessible']){
    const request=async path=>path.includes('/workflows/')?{workflow_runs:[run(1)]}:path.includes('/attempts/')?{status:'completed',head_sha:'a'.repeat(40)}:{artifacts:[{id:1,name:'vocle-functional-report-1-1',expired:mode==='expired',digest:'sha256:'+'d'.repeat(64)}]};
    await assert.rejects(priorCompatible(report('99'),compare,{request,download:async()=>{if(mode==='inaccessible')throw new Error('HTTP 403');const p=report('1');p.counts.PASS++;return [p];}}));
  }
}));

test('local lookup searches completed repository results and invalid --previous never changes current exit status',async()=>{
  const dir=await mkdtemp(join(tmpdir(),'vocle-local-history-'));
  const row=(status)=>({id:'synthetic',status,executed:true,required:true,definitionFingerprint:'definition',environmentFingerprint:'environment'});
  const local=(status,date)=>({context:{repository:syntheticContext.repository,kind:'branch',branchRef:'refs/heads/dev'},execution:{...syntheticExecution(),completedAt:date},scope:'tooling',source:{sha:'a'.repeat(40),kind:'commit',verified:true,fingerprint:'b'.repeat(64)},harness:{sha:'c'.repeat(40),fingerprint:'d'.repeat(64),verified:true},environment:{node:'22'},integrity:'PASS',results:[row(status)]});
  try {
    const current=join(dir,'current'),prior=join(dir,'older','evidence'),newer=join(dir,'newer','evidence');
    await writeEvidence(current,local('PASS','2026-10-19'));await writeEvidence(prior,local('FAIL','2026-10-17'));
    const incompatible=local('PASS','2026-10-18');incompatible.context.branchRef='refs/heads/other';await writeEvidence(newer,incompatible);
    const found=await localComparison({currentDirectory:current,resultRoot:dir,output:join(current,'comparison')});assert(found.available);assert.equal(found.rows[0].classification,'FIXED');
    const original=await readFile(join(current,'results.json'),'utf8'),exitCode=process.exitCode;
    for(const previousDirectory of [newer,join(dir,'missing')]){
      const result=await localComparison({currentDirectory:current,resultRoot:dir,previousDirectory,output:join(current,'comparison')});assert.equal(result.status,'UNAVAILABLE');assert.equal(process.exitCode,exitCode);assert.equal(await readFile(join(current,'results.json'),'utf8'),original);
    }
    await writeFile(join(prior,'results.json'),'corrupt');const missing=await localComparison({currentDirectory:current,resultRoot:dir,output:join(current,'comparison')});assert.equal(missing.status,'UNAVAILABLE');
  }finally{await rm(dir,{recursive:true,force:true});}
});
