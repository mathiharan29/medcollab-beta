// Re-render older evidence into a new directory; never rewrite the original artifact.
import { readFile, access, mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { writeReports, sanitize } from './report.mjs';
import { profiles, catalogFor, adaptSecurity } from './workflow-adapters.mjs';
const [inputPath, outputPath, workflowFile, sourceSha] = process.argv.slice(2);
if(!inputPath||!outputPath)throw new Error('Usage: refresh.mjs INPUT_JSON NEW_OUTPUT_DIR [SECURITY_WORKFLOW_FILE SOURCE_SHA]');
const output=resolve(outputPath),input=JSON.parse(await readFile(inputPath,'utf8'));
if(output===resolve(inputPath,'..'))throw new Error('Original evidence directory must remain intact');
try{await access(output);throw new Error('Choose a new output directory; existing reports are never overwritten');}catch(e){if(e.code!=='ENOENT')throw e;}
let report=sanitize(input);
if(workflowFile){const profile=profiles[workflowFile];if(!profile?.artifact)throw new Error('Unknown structured security workflow');report=adaptSecurity(input,await catalogFor(profile),profile,{sha:sourceSha||'UNKNOWN',gate:'See original historical workflow gate'});}
if(report.reportingContractVersion!==1||!Array.isArray(report.results)||!report.counts)throw new Error('Supply original normalized report or specify its supported security workflow');
// A presentation refresh cannot create execution provenance for legacy inputs.
if (!input.context || !input.execution) { report.context = input.context || null; report.execution = input.execution || null; }
report={...report,presentation:{style:'Vocle quality analytics',refreshedFrom:inputPath,note:'Visual presentation refreshed; recorded execution revisions/outcomes unchanged. This is not a new test run.'}};
await mkdir(output,{recursive:true});await writeReports(output,report);
await writeFile(join(output,'presentation-provenance.json'),JSON.stringify(report.presentation,null,2)+'\n');
console.log(JSON.stringify({output,inventory:report.results.length,counts:report.counts,originalGate:report.originalGate}));
