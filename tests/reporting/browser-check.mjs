import { functionalInput } from './fixtures/synthetic-inputs.mjs';
// Optional real offline browser check, using a dedicated headless browser profile.
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { generate } from './report.mjs';

const browser = process.argv[2] || (existsSync('C:/Program Files/Google/Chrome/Application/chrome.exe') ? 'C:/Program Files/Google/Chrome/Application/chrome.exe' : 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe');
if (!existsSync(browser)) throw new Error('Pass the path to a compatible Chromium/Chrome/Edge binary');
const output = resolve(process.argv[4] || 'tests/reporting/output/browser-check');
await mkdir(output,{recursive:true});
const report=process.argv[3] ? JSON.parse(await readFile(process.argv[3],'utf8')) : (await generate({inputObject:await functionalInput('backend'),suite:'backend',output})).report;
const caseCount=report.results.length;
// A controlled hostile diagnostic verifies text-only rendering in a real engine.
report.results[0].diagnostic='</script><img src=x onerror="window.reportXss=true">\nmultiline & diagnostic';
await (await import('./report.mjs')).writeReports(output,report);
let html=await readFile(join(output,'vocle-regression-dashboard.html'),'utf8');
const check=`<script>
setTimeout(()=>{
 const errors=[];const check=(v,m)=>{if(!v)errors.push(m);};
 check(document.querySelectorAll('#cases details').length===report.results.length,'all IDs rendered');
 check(document.querySelectorAll('#outcome-donut circle[role=button]').length>0,'outcome chart');check(document.querySelectorAll('#module-chart button').length>0,'module chart');check(document.querySelectorAll('#file-links a[download]').length===5,'local download links');check(document.querySelectorAll('#lane-links a').length===(report.lanes||[]).filter(l=>/^\\d+$/.test(String(l.artifact.id))).length,'artifact download links');
 document.querySelector('#module-chart button')?.click();check(document.getElementById('module').value!==''&&Number(document.getElementById('record-count').textContent)<=report.results.length,'module chart drilldown');document.getElementById('reset').click();check(Number(document.getElementById('record-count').textContent)===report.results.length,'reset charts');
 document.getElementById('search').value=report.results.find(r=>r.id==='FR-REQ-05')?.id||report.results[0].id;document.getElementById('search').dispatchEvent(new Event('input'));
 check(document.querySelectorAll('#cases details:not([hidden])').length===1,'ID search');
 document.getElementById('search').value='';document.getElementById('status').value='FAIL';document.getElementById('status').dispatchEvent(new Event('input'));
 check(document.querySelectorAll('#cases details:not([hidden])').length===report.counts.FAIL,'status counts');
 if(report.runUrl)check(document.querySelectorAll('#artifact-links a').length===1,'run artifact link');
 document.getElementById('status').value='';document.getElementById('module').value=report.results[0].module;document.getElementById('priority').value=report.results[0].priority;document.getElementById('module').dispatchEvent(new Event('input'));
 check(document.querySelectorAll('#cases details:not([hidden])').length>0,'module and priority filters');
 document.getElementById('module').value='';document.getElementById('priority').value='';document.getElementById('module').dispatchEvent(new Event('input'));
 document.getElementById('expand').click();
 setTimeout(()=>{check(document.querySelectorAll('#cases details[open]').length===report.results.length,'expand');check(document.querySelectorAll('#cases img').length===0&&!window.reportXss,'hostile text inert');check(document.querySelectorAll('#cases .body').length===report.results.length,'lazy details populated');check(performance.getEntriesByType('resource').every(r=>r.name.startsWith('file:')),'offline no resources');document.body.dataset.browserCheck=errors.length?'FAIL':'PASS';document.body.dataset.browserErrors=errors.join('; ');},100);
},100);
</script>`;
html=html.replace('</body>',check+'</body>');
const probe=join(output,'browser-probe.html');await writeFile(probe,html);
const common=['--headless','--disable-gpu','--no-first-run','--disable-background-networking','--host-resolver-rules=MAP * ~NOTFOUND','--user-data-dir='+join(output,'browser-profile'),'--virtual-time-budget=3000'];
const dom=execFileSync(browser,[...common,'--dump-dom',pathToFileURL(probe).href],{encoding:'utf8',maxBuffer:24*1024*1024,timeout:45000,windowsHide:true,stdio:['ignore','pipe','pipe']});
await writeFile(join(output,'offline-dom.html'),dom);
const pass=dom.includes('data-browser-check="PASS"');
await writeFile(join(output,'browser-check.json'),JSON.stringify({browser,offline:true,source:report.source,harness:report.harness,caseCount,pass,checks:['all IDs','outcome/module charts','chart drilldown/reset','five local download links','validated artifact hyperlinks','search','status/module/priority filters','expand/lazy details','hostile markup inert','run/artifact link when present','no external resource requests']},null,2)+'\n');
if(!pass)throw new Error('Offline dashboard browser check failed: '+dom.match(/data-browser-errors="([^"]*)"/)?.[1]);
execFileSync(browser,[...common,'--window-size=1440,1000','--screenshot='+join(output,'dashboard.png'),pathToFileURL(join(output,'vocle-regression-dashboard.html')).href],{timeout:45000,windowsHide:true,stdio:['ignore','pipe','pipe']});
console.log('Offline Edge/Chromium dashboard PASS; evidence '+output);
