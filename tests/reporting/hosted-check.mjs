// Authorized repository only. Uses the existing Git credential helper in memory;
// never prints credentials or forwards them to artifact storage.
import { execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { sanitize, root } from './report.mjs';
import { hash } from './scenarios.mjs';
const repository = 'mathiharan29/medcollab-beta';
if (execFileSync('git',['-C',root,'remote','get-url','origin'],{encoding:'utf8'}).trim() !== `https://github.com/${repository}.git`) throw new Error('Authorized repository origin required');
const [action,arg,directory] = process.argv.slice(2);
if (!['inspect','download','job-log'].includes(action)) throw new Error('Use inspect RUN_ID, download RUN_ID OUTPUT_DIR, or job-log JOB_ID OUTPUT_DIR');
const credential = execFileSync('git',['credential','fill'],{cwd:root,input:`protocol=https\nhost=github.com\npath=${repository}.git\n\n`,encoding:'utf8',env:{...process.env,GIT_TERMINAL_PROMPT:'0',GCM_INTERACTIVE:'Never'},windowsHide:true,stdio:['pipe','pipe','pipe']});
const token=credential.split(/\r?\n/).find(l=>l.startsWith('password='))?.slice(9);
if(!token)throw new Error('Stored GitHub authentication unavailable');
const headers={Accept:'application/vnd.github+json',Authorization:'Bearer '+token,'X-GitHub-Api-Version':'2022-11-28'};
async function request(path,options={}){const response=await fetch(`https://api.github.com/repos/${repository}${path}`,{headers,...options,redirect:'manual',signal:AbortSignal.timeout(30000)});if(response.status===204)return null;if(!response.ok&&response.status!==302)throw new Error(`GitHub operation ${action} returned ${response.status}`);return response;}
{
 if(!/^\d+$/.test(arg||''))throw new Error('Numeric run/job ID required');
 if(action==='job-log'){
  if(!directory)throw new Error('Output directory required');const response=await request(`/actions/jobs/${arg}/logs`);let raw;
  if(response.status===302){const u=new URL(response.headers.get('location'));if(u.protocol!=='https:')throw new Error('Unsafe log redirect');const r=await fetch(u,{signal:AbortSignal.timeout(30000)});if(!r.ok)throw new Error('Log storage read failed');raw=await r.text();}else raw=await response.text();
  await mkdir(directory,{recursive:true});await writeFile(join(directory,arg+'.log'),sanitize(raw));console.log('Sanitized job log saved.');
 }else{
  const run=await(await request('/actions/runs/'+arg)).json();const jobs=await(await request('/actions/runs/'+arg+'/jobs?per_page=100')).json();const artifacts=await(await request('/actions/runs/'+arg+'/artifacts?per_page=100')).json();
  const metadata=sanitize({run:{id:run.id,headSha:run.head_sha,event:run.event,status:run.status,conclusion:run.conclusion,url:run.html_url},jobs:jobs.jobs.map(j=>({id:j.id,name:j.name,status:j.status,conclusion:j.conclusion,steps:j.steps})),artifacts:artifacts.artifacts.map(a=>({id:a.id,name:a.name,digest:a.digest,size:a.size_in_bytes,expired:a.expired}))});
  if(directory){await mkdir(directory,{recursive:true});await writeFile(join(directory,'hosted-metadata.json'),JSON.stringify(metadata,null,2)+'\n');}
  if(action==='download'){
   if(!directory)throw new Error('Output directory required');
   for(const a of artifacts.artifacts.filter(a=>!a.expired&&/^(vocle-functional-report-|vocle-flutter-report-|vocle-sanity-diagnostics-|vocle-regression-dashboard-|vocle-qa-dashboard-|developer-qa-|vocle-mongodb-data-security-|vocle-offline-media-security-|vocle-security-discovery-)/.test(a.name))){
    const response=await request('/actions/artifacts/'+a.id+'/zip');if(response.status!==302)throw new Error('Artifact redirect required');const u=new URL(response.headers.get('location'));if(u.protocol!=='https:')throw new Error('Unsafe artifact redirect');const r=await fetch(u,{signal:AbortSignal.timeout(60000)});if(!r.ok)throw new Error('Artifact storage read failed');const bytes=Buffer.from(await r.arrayBuffer());if(a.digest&&a.digest!=='sha256:'+hash(bytes))throw new Error('Downloaded artifact digest mismatch');await writeFile(join(directory,a.name+'.zip'),bytes);
   }
  }
  console.log(JSON.stringify({run:metadata.run,jobs:metadata.jobs.map(j=>({id:j.id,name:j.name,status:j.status,conclusion:j.conclusion,attention:j.steps.filter(s=>s.status==='in_progress'||s.conclusion==='failure').map(s=>s.name)})),artifacts:metadata.artifacts},null,2));
 }
}
