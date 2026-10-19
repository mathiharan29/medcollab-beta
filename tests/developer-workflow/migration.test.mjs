import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { addLocalOnlyAndroid } from '../reporting/coverage.mjs';
import { normalize, root, summary } from '../reporting/report.mjs';
import { scenarioMetadata } from '../reporting/scenarios.mjs';
import { loadPreviousCatalog, validateCoverage } from './coverage-policy.mjs';

test('workflow entry points and suite ownership require complete PR execution with cleanup-safe concurrency',async()=>{
  const reusable=['vocle-sanity.yml','vocle-security-environment-test.yml','vocle-reporting.yml'];
  const directory=join(root,'.github/workflows');
  for(const file of await readdir(directory)){
    const text=await readFile(join(directory,file),'utf8'),events=text.split('on:\n')[1].split('permissions:')[0];
    assert(!/^  (push|schedule):/m.test(events));assert(!events.includes('paths:'));assert(!text.includes('pull_request_target'));assert(text.includes('cancel-in-progress: false'));
    if(reusable.includes(file)){assert(events.includes('workflow_call:'));assert(!events.includes('pull_request:'));assert(!events.includes('workflow_dispatch:'));}
    else if(file==='vocle-cloudinary-security.yml')assert(events.includes('workflow_dispatch:'));
    else {assert(events.includes('branches: [master]'));assert(events.includes('types: [opened, reopened, ready_for_review, synchronize]'));assert(!events.includes('workflow_dispatch:'));assert(text.includes('QA_HEAD_REPOSITORY'));}
    for(const checkout of text.split(/uses: actions\/checkout@/).slice(1)){
      const config=checkout.split(/\n      - /)[0];assert(config.includes('persist-credentials: false'));assert(config.includes('github.event.pull_request.head.sha || github.sha'));
    }
    assert(!/needs_run|find-baseline|VOCLE_FORCE|status=success/.test(text));
  }
  const functional=await readFile(join(directory,'vocle-functional-regression.yml'),'utf8');
  assert(!functional.includes('affected_modules'));assert(!functional.includes('flutter_changed'));assert(functional.includes('test/functional_regression'));assert(functional.includes('retained_exit'));assert(functional.includes('test "$EXECUTE_RESULT" = success'));assert(functional.includes('test "$FLUTTER_RESULT" = success'));
  const developer=await readFile(join(directory,'vocle-developer-qa.yml'),'utf8');assert.equal((developer.match(/uses: .\/.github\/workflows\/vocle-security-environment-test.yml/g)||[]).length,1);
  for(const file of await readdir(directory)){const text=await readFile(join(directory,file),'utf8');assert(!text.includes('uses: ./.github/workflows/vocle-sanity.yml'));}
});
test('hosted Android inventory is local-only SKIP; 179 hosted passes never become 187 executed passes',async()=>{
  const metadata=await scenarioMetadata(root);
  const hosted=normalize({scope:'full',results:metadata.filter(c=>c.tier!=='D').map(c=>({id:c.id,status:'PASS',executed:true}))},metadata,{suite:'developer'});
  const rows=addLocalOnlyAndroid(hosted.results,metadata,hosted.source,hosted.harness);
  assert.equal(rows.length,187);assert.equal(rows.filter(r=>r.executed).length,179);assert.equal(rows.filter(r=>r.status==='PASS').length,179);
  assert.equal(rows.filter(r=>r.executionMode==='LOCAL_ONLY'&&r.status==='SKIP'&&!r.executed).length,8);
  assert.throws(()=>addLocalOnlyAndroid(rows,metadata,hosted.source,hosted.harness),/cannot be relabeled/);
  assert.equal(normalize({},metadata,{suite:'backend'}).counts.ERROR,147);
  assert.equal(normalize({},metadata,{suite:'flutter'}).counts.ERROR,32);
  assert(summary(hosted).includes('187 total / 179 hosted / 8 LOCAL_ONLY'));
  const old=process.env.GITHUB_RUN_ID;process.env.GITHUB_RUN_ID='42';
  try{assert.throws(()=>normalize({},metadata,{suite:'device'}),/LOCAL_ONLY/);}finally{if(old===undefined)delete process.env.GITHUB_RUN_ID;else process.env.GITHUB_RUN_ID=old;}
});
test('first catalog bootstrap accepts only a genuinely absent base and a validated testing-only change',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'vocle-bootstrap-contract-'));
  const git=args=>execFileSync('git',['-C',directory,...args],{encoding:'utf8',windowsHide:true,stdio:['ignore','pipe','pipe']}).trim();
  const commit=()=>{git(['add','.']);git(['-c','user.name=Synthetic Contract','-c','user.email=synthetic@example.invalid','commit','--no-gpg-sign','--allow-empty','-m','Synthetic contract']);return git(['rev-parse','HEAD']);};
  try{
    git(['init']);const base=commit();await mkdir(join(directory,'tests/functional-regression'),{recursive:true});await writeFile(join(directory,'tests/functional-regression/catalog.json'),JSON.stringify({cases:[{id:'one'}]}));commit();
    let validated=false;assert.deepEqual(loadPreviousCatalog(directory,base,()=>{validated=true;}),[]);assert(validated);
    assert.throws(()=>loadPreviousCatalog(directory,base,()=>{throw new Error('Invalid new catalog');}),/Invalid new catalog/);
    const existing=git(['rev-parse','HEAD']);await mkdir(join(directory,'medcollab-app/lib'),{recursive:true});await writeFile(join(directory,'medcollab-app/lib/example.dart'),'Synthetic');commit();
    assert.throws(()=>loadPreviousCatalog(directory,base,()=>{}),/application changes/);
    assert.deepEqual(loadPreviousCatalog(directory,existing,()=>{assert.fail('Existing catalog must not bootstrap');}),[{id:'one'}]);
    await writeFile(join(directory,'tests/functional-regression/catalog.json'),'malformed');const bad=commit();assert.throws(()=>loadPreviousCatalog(directory,bad,()=>{}));
    assert.throws(()=>loadPreviousCatalog(directory,'f'.repeat(40),()=>{}));
    assert(validateCoverage({oldCases:[{id:'one'}],newCases:[],changedFiles:[]}).some(x=>x.includes('removed')));
  }finally{await rm(directory,{recursive:true,force:true});}
});
