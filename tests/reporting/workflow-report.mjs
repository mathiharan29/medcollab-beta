import { addLocalOnlyAndroid } from './coverage.mjs';
import { captureContext, executionIdentity, verifiedReport } from '../developer-workflow/context.mjs';
// Runs after the original gates, including detection/setup failures and skips.
import { writeReports, sanitize, statuses, root, summary } from './report.mjs';
import { api, artifactReports } from './history.mjs';
import { scenarioMetadata, hash } from './scenarios.mjs';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const output = resolve(process.argv[2] || 'vocle-report-output');
await mkdir(output, { recursive: true });
const runId = process.env.GITHUB_RUN_ID;
const runUrl = `https://github.com/mathiharan29/medcollab-beta/actions/runs/${runId}`;
const isSanity = process.env.VOCLE_REPORT_WORKFLOW === 'sanity';
const suites = isSanity ? ['sanity'] : ['backend', 'flutter'];
const expectedNames = isSanity ? [`vocle-sanity-diagnostics-${runId}-${process.env.GITHUB_RUN_ATTEMPT}`] : [`vocle-functional-report-${runId}-${process.env.GITHUB_RUN_ATTEMPT}`, `vocle-flutter-report-${runId}-${process.env.GITHUB_RUN_ATTEMPT}`];
const metadata = await scenarioMetadata(root);
const reports = [], infrastructure = [], downloadedSuites = new Set();
let artifacts = [];
try { artifacts = (await api(`/actions/runs/${runId}/artifacts`)).artifacts; }
catch (error) { infrastructure.push({ status: 'ERROR', category: 'REPORT_COLLECTION', message: sanitize(error.message) }); }
for (const a of artifacts.filter(a => !a.expired && expectedNames.includes(a.name))) {
  try {
    for (const r of await artifactReports(a.id)) {
      if (!verifiedReport(r) || r.source?.sha !== process.env.VOCLE_TARGET_SHA || r.execution?.id !== `${runId}:${process.env.GITHUB_RUN_ATTEMPT}` || !suites.includes(r.suite) || downloadedSuites.has(r.suite) || r.reportingContractVersion !== 1 || !Array.isArray(r.results)) throw new Error('Incompatible or duplicate report artifact');
      const clean = sanitize(r);
      // Logs are available in the linked lane artifact; avoid broken relative links.
      for (const row of clean.results) row.evidenceFiles = [];
      clean.artifact = { name: a.name, id: a.id, runUrl };
      reports.push(clean); downloadedSuites.add(clean.suite);
    }
  } catch (error) { infrastructure.push({ status: 'ERROR', category: 'REPORT_COLLECTION', message: `${a.name}: ${sanitize(error.message)}` }); }
}
const jobs = JSON.parse(process.env.VOCLE_REPORT_JOBS || '{}');

let rows = reports.flatMap(r => r.results);
for (const suite of suites) {
  if (downloadedSuites.has(suite)) continue;
  const jobName = suite === 'backend' ? 'execute' : suite;
  const skipped = false;
  const selection = metadata.filter(c => suite === 'sanity' ? c.coverage === 'EXISTING' : c.tier === (suite === 'backend' ? 'B' : 'F'));
  for (const c of selection) rows.push({ ...c, status: skipped ? 'SKIP' : 'ERROR', executed: false, actual: skipped ? 'Workflow lane not executed; consult detection and prior validated evidence.' : 'No downloadable normalized execution evidence was produced.', source: { sha: process.env.VOCLE_TARGET_SHA || 'UNKNOWN' }, harness: { sha: process.env.GITHUB_SHA }, durationMs: null, category: skipped ? 'SKIP' : 'INFRASTRUCTURE_OR_HARNESS_ERROR', rootCause: 'UNKNOWN', failingStep: 'Before validated case evidence', comparisonExpected: 'Execution evidence', comparisonActual: 'Not available', outcome: 'No case execution is claimed.', userImpact: 'No coverage claim; missing evidence requires investigation.', verifiedSubassertions: [], evidenceFiles: [], owner: 'UNASSIGNED', diagnostic: '' });
  if (!skipped) infrastructure.push({ status: 'ERROR', category: 'MISSING_LANE_REPORT', message: `${suite}: job ${jobName} is ${jobs[jobName] || 'unknown'}; no case execution evidence was collected.` });
}
if (new Set(rows.map(r => r.id)).size !== rows.length || rows.some(r => !statuses.includes(r.status) || (r.status === 'PASS' && !r.executed))) throw new Error('Invalid merged report IDs/statuses');
const originalGate = Object.values(jobs).some(v => ['failure', 'cancelled'].includes(v)) ? 'FAILURE' : 'See original lane gates';
if (!isSanity) rows = addLocalOnlyAndroid(rows, metadata, { sha: process.env.VOCLE_TARGET_SHA || 'UNKNOWN' }, { sha: process.env.GITHUB_SHA });
const report = sanitize({ context: captureContext(root), execution: executionIdentity(), catalogCoverage: { total: 187, hosted: 179, localOnly: 8 }, schemaVersion: 1, reportingContractVersion: 1, suite: 'workflow', scope: process.env.VOCLE_REPORT_WORKFLOW, sourceKind: process.env.VOCLE_TARGET_KIND || 'pr-head', source: { sha: process.env.VOCLE_TARGET_SHA || 'UNKNOWN' }, harness: { sha: process.env.GITHUB_SHA }, runUrl, originalGate, selected: rows.length, recorded: reports.reduce((n,r)=>n+r.recorded,0), attempted: rows.filter(r=>r.executed).length, counts: Object.fromEntries(statuses.map(s=>[s,rows.filter(r=>r.status===s).length])), infrastructure: [...infrastructure,...reports.flatMap(r=>r.infrastructure)], results: rows, lanes: reports.map(r=>({suite:r.suite,counts:r.counts,source:r.source,harness:r.harness,artifact:r.artifact,comparison:r.comparison})), comparison: { available: false, reason: 'Previous/current comparisons are retained per lane. Open a lane artifact for compatible baseline highlights.' }, definitionSet: hash(JSON.stringify(rows.map(r=>[r.id,r.definitionFingerprint]))), note: 'Combined workflow inventory. Skipped or missing lanes are explicitly unexecuted; they do not become full-suite success. Lane artifacts contain sanitized logs and source/provenance evidence.' });
const artifact = `vocle-regression-dashboard-${runId}-${process.env.GITHUB_RUN_ATTEMPT}`;
await writeReports(output, report, { artifact });
if (process.env.GITHUB_STEP_SUMMARY) await writeFile(process.env.GITHUB_STEP_SUMMARY, summary(report, artifact) + '\nLane artifacts: ' + reports.map(r=>r.artifact.name).join(', ') + '\n', { flag: 'a' });
if (infrastructure.some(i=>i.status==='ERROR')) process.exitCode=1;
