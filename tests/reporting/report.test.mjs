import { functionalInput, syntheticContext, syntheticExecution } from './fixtures/synthetic-inputs.mjs';
import { sealReport } from '../developer-workflow/context.mjs';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFile, mkdtemp, writeFile, mkdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { normalize, sanitize, compare, generate, writeReports, root, safePath, junit, summary, detailed } from './report.mjs';
import { scenarioMetadata } from './scenarios.mjs';
import { stage } from './stage.mjs';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const metadata = await scenarioMetadata(root);
const ids = metadata.filter(c=>c.tier==='B').slice(0,6).map(c=>c.id);
const statuses = ['PASS','FAIL','ERROR','BLOCKED','NEEDS_DECISION','SKIP'];

// These fixtures describe a local report, even when this contract suite runs
// on Actions. Keep the production hosted guard enabled outside this synchronous
// normalization call; never clear CI identity for a real runner or publication.
function normalizeLocalFixture(...args) {
 const runId=process.env.GITHUB_RUN_ID;
 try { delete process.env.GITHUB_RUN_ID; return normalize(...args); }
 finally { if(runId===undefined)delete process.env.GITHUB_RUN_ID;else process.env.GITHUB_RUN_ID=runId; }
}

test('hosted execution rejects Android evidence and fixture isolation restores CI identity',()=>{
 const previous=process.env.GITHUB_RUN_ID;
 try {
  process.env.GITHUB_RUN_ID='synthetic-hosted-contract';
  const input={tier:'D',selected:['FR-MED-08'],cases:[{id:'FR-MED-08',status:'SKIP',executed:false}]};
  assert.throws(()=>normalize(input,metadata,{suite:'device'}),/LOCAL_ONLY/);
  normalizeLocalFixture(input,metadata,{suite:'device'});
  assert.equal(process.env.GITHUB_RUN_ID,'synthetic-hosted-contract');
  assert.throws(()=>normalize({results:[{id:'FR-MED-08',status:'PASS',executed:true}]},metadata,{suite:'developer'}),/cannot be relabeled/);
 } finally { if(previous===undefined)delete process.env.GITHUB_RUN_ID;else process.env.GITHUB_RUN_ID=previous; }
});

test('local-only presentation preserves unexecuted ERROR, BLOCKED and SKIP outcomes',()=>{
 for(const status of ['ERROR','BLOCKED','SKIP']){
  const r=normalizeLocalFixture({tier:'D',selected:['FR-MED-08'],cases:[{id:'FR-MED-08',status,executed:false,errorCategory:'DEVICE_PREREQUISITE'}]},metadata,{suite:'device'});
  assert.equal(r.results[0].status,status);assert.equal(r.attempted,0);
  assert(summary(r).includes(`FR-MED-08 — LOCAL_ONLY; executed false; ${status}`));
  assert(detailed(r).includes(`**${status}** (LOCAL_ONLY)`));
  assert.equal(r.counts[status],1);
 }
});

test('Flutter aggregation leaves unknown application source unverified and preserves failures',async()=>{
 await flutterAggregationFixture(async({run})=>{
  const {report}=await run();assert.deepEqual(report.source,{sha:null,kind:'unverified',verified:false});
  assert.equal(report.sourceKind,'unverified');assert.equal(report.counts.FAIL,1);assert.equal(report.complete,true);assert.equal(report.fullSuccess,false);
 });
});

test('Flutter aggregation binds a different application commit without relabeling it as harness HEAD',async()=>{
 await flutterAggregationFixture(async({run,provenance,harnessSha})=>{
  const {report}=await run(provenance);assert.equal(report.source.sha,provenance.source.sha);
  assert.equal(report.source.verified,true);assert.equal(report.harnessSha,harnessSha);assert.notEqual(report.source.sha,report.harnessSha);
  assert.equal(report.inputSha256,provenance.inputSha256);assert.equal(report.counts.FAIL,1);
 });
});

test('Flutter aggregation preserves working-tree identity and its source fingerprint',async()=>{
 await flutterAggregationFixture(async({run,provenance})=>{
  provenance.source={...provenance.source,kind:'working-tree',fingerprint:'d'.repeat(64)};
  const {report}=await run(provenance);assert.equal(report.sourceKind,'working-tree');assert.equal(report.source.kind,'working-tree');assert.equal(report.source.fingerprint,'d'.repeat(64));
 });
});

test('Flutter aggregation rejects mismatched events, harness, missing fingerprint and unverified source',async()=>{
 await flutterAggregationFixture(async({run,provenance})=>{
  for(const change of [{inputSha256:'0'.repeat(64)},{harnessSha:'0'.repeat(40)},{source:{...provenance.source,verified:false}},{source:{...provenance.source,kind:'working-tree'}}]){
   const {result}=await run({...provenance,...change},false);assert.notEqual(result.status,0);assert.match(result.stderr,/Invalid runner provenance/);
  }
 });
});

async function flutterAggregationFixture(action){
 const directory=await mkdtemp(join(tmpdir(),'vocle-flutter-provenance-'));
 try{
  const harnessSha=execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8',windowsHide:true}).trim();
  const events=metadata.filter(c=>c.tier==='F').flatMap((c,i)=>[
   {type:'testStart',test:{id:i,name:`${c.id}: synthetic provenance contract`},time:i*10},
   ...(c.id==='FR-NAV-02'?[{type:'error',testID:i,error:'Synthetic assertion failure preserved',isFailure:true}]:[]),
   {type:'testDone',testID:i,result:c.id==='FR-NAV-02'?'failure':'success',time:i*10+1}
  ]);
  events.push({type:'done',success:false});
  const input=join(directory,'catalog.ndjson'),bytes=events.map(e=>JSON.stringify(e)).join('\n')+'\n';await writeFile(input,bytes);
  const provenance={source:{sha:harnessSha==='a'.repeat(40)?'b'.repeat(40):'a'.repeat(40),kind:'commit',verified:true},harnessSha,inputSha256:createHash('sha256').update(bytes).digest('hex')};
  let attempt=0;
  const run=async(record,expectReport=true)=>{
   const output=join(directory,'report-'+attempt++),args=[join(root,'tests/functional-regression/scripts/aggregate-flutter.mjs'),input,output];
   if(record){const file=output+'-provenance.json';await writeFile(file,JSON.stringify(record));args.push(file);}
   const result=spawnSync(process.execPath,args,{encoding:'utf8',windowsHide:true,timeout:10000});
   if(!expectReport){await assert.rejects(readFile(output+'.json'),{code:'ENOENT'});return {result};}
   assert.equal(result.status,0,result.stderr);return {result,report:JSON.parse(await readFile(output+'.json','utf8'))};
  };
  await action({run,provenance,harnessSha});
 }finally{await rm(directory,{recursive:true,force:true});}
}
const fixture = () => ({ context: syntheticContext, execution: syntheticExecution(), sourceKind:'pr-head',scope:'backend-all',environmentContractVersion:1,targetSha:'a'.repeat(40),harnessSha:'b'.repeat(40),fingerprint:'c'.repeat(64),selectedIds:ids,results:ids.map((id,i)=>({id,status:statuses[i],durationMs:10+i,error:i?'Synthetic diagnostic\nnext line':'',verifiedSubassertions:i===4?['Safe subassertion recorded']:undefined})),tally:Object.fromEntries(statuses.map(s=>[s,1])) });

test('all 187 scenarios have unique metadata, prerequisites and executable definitions',()=>{
  assert.equal(metadata.length,187);assert.equal(new Set(metadata.map(c=>c.id)).size,187);
  for(const c of metadata){assert(c.scenario.includes(c.actions)||c.id==='message-requests-02'||c.id==='FR-REQ-05'||c.id==='FR-PUSH-05');assert(c.prerequisites.length>60);assert(c.steps.length);assert(c.expected);assert(c.definitions.length,c.id);assert(c.definitionFingerprint);}
});
test('all six classifications and original counts survive normalization',()=>{
 const r=normalize(fixture(),metadata,{suite:'backend'});assert.deepEqual(r.counts,fixture().tally);assert.deepEqual(r.originalCounts,r.counts);assert.equal(r.results.find(x=>x.status==='BLOCKED').executed,false);assert.equal(r.results.find(x=>x.status==='NEEDS_DECISION').status,'NEEDS_DECISION');assert(r.results.every(x=>x.owner==='UNASSIGNED'));
});
test('unexecuted PASS, duplicate IDs, wrong counts and unknown statuses are rejected',()=>{
 let f=fixture();f.results[0].executed=false;assert.throws(()=>normalize(f,metadata),/Unexecuted PASS/);
 f=fixture();f.results[1].id=f.results[0].id;assert.throws(()=>normalize(f,metadata),/Duplicate/);
 f=fixture();f.tally.PASS=99;assert.throws(()=>normalize(f,metadata),/counts disagree/);
 f=fixture();f.results[0].status='green';assert.throws(()=>normalize(f,metadata),/Unknown status/);
});
test('missing setup evidence produces 48 unexecuted ERRORs and a separate infrastructure error',()=>{
 const r=normalize({},metadata,{suite:'sanity',sourceSha:'a'.repeat(40)});assert.equal(r.results.length,48);assert.equal(r.counts.ERROR,48);assert.equal(r.attempted,0);assert.equal(r.infrastructure[0].status,'ERROR');
});
test('sanity planned self-check and explicit skips never become execution',()=>{
 const planned={scenarios:ids.map(id=>({id,status:'planned'}))};const r=normalize(planned,metadata,{suite:'sanity',skipped:true});assert.equal(r.counts.SKIP,48);assert.equal(r.attempted,0);
});
test('HTTP failure records expected/actual operation without inventing root cause',()=>{
 const f=fixture();f.results[1].error='POST /api/message-requests expected 201, got 500';const r=normalize(f,metadata).results[1];assert.equal(r.comparisonActual,'HTTP 500');assert(r.comparisonExpected.includes('201'));assert.equal(r.failingStep,'POST /api/message-requests');assert(r.rootCause.startsWith('UNKNOWN'));
});
test('secrets and signed links are redacted recursively, including opaque credentials',()=>{
 const input={accessToken:'opaque-secret-value',otp:'123456',nested:{password:'private'},log:'Bearer super-private eyJhbGciOi.abc.def code=987654 secret="local-private" https://example.com/path?sig=private&se=tomorrow http://127.0.0.1:1234/abcdefghij=/ws'};
 const out=JSON.stringify(sanitize(input));for(const value of ['opaque-secret-value','123456','private','987654','abcdefghij'])assert(!out.includes(value),value);assert(out.includes('REDACTED'));
});
test('links cannot use javascript, absolute paths or traversal',()=>{
 for(const p of ['javascript:alert(1)','//evil','../outside','logs/../../outside','C:\\outside','logs/line\nfeed','logs/%2e%2e/outside','logs/x) [injected](javascript:evil)','%2f%2fevil'])assert(!safePath(p));assert(safePath('logs/backend.log'));
});
test('comparison reuses strict contract for FIXED, NEW_REGRESSION, STILL_FAILING, STILL_PASSING',()=>{
 const before=normalize(fixture(),metadata);const after=structuredClone(before);after.results[0].status='FAIL';after.results[1].status='PASS';after.results[2].status='FAIL';before.results[2].status='FAIL';after.results[3].status='PASS';before.results[3].status='PASS';before.results[3].executed=true;after.results[3].executed=true;
 after.execution=syntheticExecution();sealReport(before);const c=compare(after,before);assert(c.available);assert.deepEqual(c.rows.slice(0,4).map(r=>r.classification),['NEW_REGRESSION','FIXED','STILL_FAILING','STILL_PASSING']);assert.equal(c.rows.find(r=>r.id===ids[4]).classification,'UNCHANGED_NONPASS');
 after.environmentFingerprint=null;assert.equal(compare(after,before).available,false);after.environmentFingerprint=before.environmentFingerprint;after.sourceKind='working-tree';assert.equal(compare(after,before).available,false);after.sourceKind=before.sourceKind;after.definitionSet='changed';assert.equal(compare(after,before).available,false);
});
test('HTML and Markdown safely handle hostile markup, multiline logs, and missing diagnostics',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'vocle-report-test-'));
 try{const f=fixture();f.results[1].error='</script><img src=x onerror="window.pwned=1"> & multi\nline [execute](javascript:alert(1))';const r=normalize(f,metadata);await writeReports(dir,r);const html=await readFile(join(dir,'vocle-regression-dashboard.html'),'utf8');assert(!html.includes('</script><img'));assert(html.includes('\\u003c/script'));assert(!/https?:\/\/.*(?:\.js|\.css)["']/.test(html));const md=await readFile(join(dir,'vocle-regression-detailed-report.md'),'utf8');assert(md.includes('&lt;img'));assert(md.includes('\\[execute\\]\\(javascript:alert\\(1\\)\\)'));assert(md.includes('UNKNOWN'));assert(junit(r).includes('vocle.status'));}finally{await rm(dir,{recursive:true,force:true});}
});
test('synthetic backend, Flutter, device and sanity formats preserve complete inventories',async()=>{
 for(const [suite,count] of [['backend',147],['flutter',32],['device',8],['sanity',48]]){
  const input=await functionalInput(suite);const r=normalizeLocalFixture(input,metadata,{suite});assert.equal(r.results.length,count);assert.equal(r.recorded,count);assert.equal(Object.values(r.counts).reduce((a,b)=>a+b,0),count);
 }
});

test('large report is generated, deterministic and preserves 187 IDs',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'vocle-large-report-'));
 try{const input={scope:'full',source:{sha:'a'.repeat(40),kind:'commit'},harness:{sha:'b'.repeat(40)},results:metadata.map(c=>({id:c.id,status:'PASS',executed:true,evidence:'x'.repeat(3000)}))};const r=normalizeLocalFixture(input,metadata,{suite:'developer'});await writeReports(dir,r);const a=await readFile(join(dir,'vocle-regression-results.json'),'utf8');await writeReports(dir,r);assert.equal(await readFile(join(dir,'vocle-regression-results.json'),'utf8'),a);assert.equal(JSON.parse(a).results.length,187);}finally{await rm(dir,{recursive:true,force:true});}
});
test('publication excludes binaries/runtime and sanitizes raw logs without altering originals',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'vocle-stage-test-'));
 try{const src=join(dir,'raw'),dst=join(dir,'publish');await mkdir(join(src,'runtime'),{recursive:true});await writeFile(join(src,'runner.log'),'Bearer hidden-credential\nnext');await writeFile(join(src,'runtime','ignore.txt'),'private');await writeFile(join(src,'blob.bin'),'private');const files=await stage(src,dst);assert.deepEqual(files,['runner.log']);assert((await readFile(join(src,'runner.log'),'utf8')).includes('hidden-credential'));assert(!(await readFile(join(dst,'runner.log'),'utf8')).includes('hidden-credential'));await assert.rejects(stage(src,join(src,'child')),/separate/);}finally{await rm(dir,{recursive:true,force:true});}
});
test('invalid result input still writes all five infrastructure reports and signals validation failure',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'vocle-invalid-report-'));
 try{const f=fixture();f.results[0].status='GREEN';const {report,validationFailed}=await generate({inputObject:f,suite:'backend',output:dir});assert(validationFailed);assert.equal(report.counts.FAIL,1);assert.equal(report.results[0].executed,false);assert(report.originalObservations.some(r=>r.status==='FAIL'));assert(report.infrastructure.some(i=>i.category==='REPORT_VALIDATION'));for(const name of ['dashboard.html','detailed-report.md','results.json','junit.xml','summary.md'])assert((await readFile(join(dir,'vocle-regression-'+name))).length);}finally{await rm(dir,{recursive:true,force:true});}
});
test('workflow integration generates/uploads after failure and retains original gates',async()=>{
 for(const name of ['vocle-functional-regression.yml','vocle-sanity.yml']){const text=await readFile(join(root,'.github/workflows',name),'utf8');assert(text.includes('if: always()'));assert(text.includes('tests/reporting/report.mjs'));assert(text.includes('tests/reporting/workflow-report.mjs'));assert(text.includes('vocle-regression-dashboard-'));assert(text.includes('success-manifest'));}
 const workflow=await readFile(join(root,'.github/workflows/vocle-functional-regression.yml'),'utf8');assert(workflow.includes('test "$REPORT_RESULT" = PASS'));assert(workflow.includes('test "$CATALOG_EXIT" = 0'));assert(workflow.includes('test "$RETAINED_EXIT" = 0'));
});
test('CLI optional history import completes without a circular top-level await',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'vocle-history-cli-'));
 try{
  const input=join(dir,'synthetic-flutter.json');await writeFile(input,JSON.stringify(await functionalInput('flutter')));
  const out=execFileSync(process.execPath,[join(root,'tests/reporting/report.mjs'),'--suite','flutter','--input',input,'--output',dir,'--history','true'],{encoding:'utf8',timeout:10000,env:{...process.env,GITHUB_TOKEN:'',GITHUB_RUN_ID:''},windowsHide:true});
  assert(JSON.parse(out).counts.PASS===6);assert((await readFile(join(dir,'vocle-regression-dashboard.html'))).length);
 }finally{await rm(dir,{recursive:true,force:true});}
});
test('a broken aggregate tally does not relabel an observed application FAIL as ERROR',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'vocle-count-error-'));
 try{const f=fixture();f.tally.PASS=40;const {report,validationFailed}=await generate({inputObject:f,suite:'backend',output:dir});assert(validationFailed);assert.equal(report.results.find(r=>r.id===ids[1]).status,'FAIL');assert.equal(report.counts.FAIL,1);assert(report.infrastructure.some(i=>i.category==='REPORT_VALIDATION'));}finally{await rm(dir,{recursive:true,force:true});}
});
