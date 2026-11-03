// Aggregate existing execution evidence only. Does not run or retry application actions.
import { readFile, readdir, writeFile, mkdir } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { createHash } from 'node:crypto';
import { generate } from '../../reporting/report.mjs';
const [backendArg, flutterArg, outputArg] = process.argv.slice(2);
if (!backendArg || !flutterArg || !outputArg) throw new Error('Usage: report-needl.mjs BACKEND_OUTPUT_DIR FLUTTER_REPORT_JSON REPORT_DIRECTORY');
const backend=resolve(backendArg),output=resolve(outputArg),parts=[],inputs=[];
for(const entry of await readdir(backend,{withFileTypes:true})){
  if(!entry.isDirectory()||!/^needl-\d\d-/.test(entry.name))continue;
  const path=join(backend,entry.name,'results.json'),bytes=await readFile(path),report=JSON.parse(bytes);
  if(report.cleanup?.status!=='PASS'||report.provenance?.status!=='PASS')throw new Error('Backend cleanup/provenance did not pass: '+entry.name);
  parts.push(report);inputs.push({path,sha256:createHash('sha256').update(bytes).digest('hex')});
}
const bytes=await readFile(resolve(flutterArg)),flutter=JSON.parse(bytes);
if(flutter.source?.verified!==true||!flutter.complete||flutter.implementedAndExecuted!==56)throw new Error('Full Flutter execution/source evidence required');
const catalog=JSON.parse(await readFile(new URL('../catalog.json',import.meta.url))).cases;
const selected=catalog.filter(c=>c.module==='NDL').map(c=>c.id);
const rows=[...parts.flatMap(p=>p.results),...flutter.cases.filter(r=>r.id.startsWith('FR-NDL-'))];
if(rows.length!==54||new Set(rows.map(r=>r.id)).size!==54||rows.some(r=>!selected.includes(r.id)))throw new Error('Missing, duplicate or unexpected Needl case evidence');
const harnessSha=flutter.harnessSha,sourceSha=flutter.source.sha;
if(parts.some(p=>p.harnessSha!==harnessSha||p.targetSha!==sourceSha))throw new Error('Mixed source/harness revisions: generate lane reports separately');
inputs.push({path:resolve(flutterArg),sha256:createHash('sha256').update(bytes).digest('hex')});
const counts=Object.fromEntries(['PASS','FAIL','ERROR','BLOCKED','NEEDS_DECISION','SKIP'].map(s=>[s,rows.filter(r=>r.status===s).length]));
await mkdir(output,{recursive:true});
const input={scope:'needl-functional-subset',source:{sha:sourceSha,kind:'commit',verified:true},harness:{sha:harnessSha},selectedIds:selected,results:rows,tally:counts,gate:Object.entries(counts).some(([s,n])=>s!=='PASS'&&n)?'FAIL':'PASS',reproduction:'Run suites/needl.mjs and Flutter test/functional_regression, then report-needl.mjs with their exact output paths.'};
const {report}=await generate({inputObject:input,suite:'developer',output,artifact:'Needl local functional regression'});
report.title='Vocle Needl functional regression';
await (await import('../../reporting/report.mjs')).writeReports(output,report);
await writeFile(join(output,'execution-inputs.json'),JSON.stringify({sourceSha,harnessSha,baselineApplicationSha:'4c01dc24247aa95a73e286a2b42c7f2f81257c7a',scope:input.scope,selected:54,counts,fullFlutterCounts:flutter.counts,backendCleanup:parts.map(p=>({selectedIds:p.selectedIds,...p.cleanup})),inputs},null,2)+'\n');
console.log(JSON.stringify({scope:input.scope,sourceSha,harnessSha,counts,fullCatalogSuccessClaimed:false}));
if(input.gate!=='PASS')process.exitCode=1;
