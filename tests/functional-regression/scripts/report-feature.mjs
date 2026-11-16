import { appendFile, readFile, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { generate } from '../../reporting/report.mjs';
import { captureContext, executionIdentity } from '../../developer-workflow/context.mjs';
import { catalogCases } from './ci-contracts.mjs';
import { collectFeatureEvidence } from './feature-evidence.mjs';
import { loadFeature } from './feature-registry.mjs';

const feature = process.env.VOCLE_FEATURE;
const selected = await loadFeature(feature, await catalogCases());
const output = process.env.VOCLE_FEATURE_OUTPUT;
if (!output) throw new Error('VOCLE_FEATURE_OUTPUT is required');
const target = process.env.VOCLE_TARGET_SHA;
const root = resolve(import.meta.dirname, '../../..');
const lanes = [];
const json = filename => readFile(join(output, filename), 'utf8').then(JSON.parse);
if (selected.some(row => row.tier === 'B')) {
  const lane = { tier: 'B', results: [] };
  try {
    const report = await json('backend/results.json');
    lane.results = report.results;
    const [cleanup, provenance] = await Promise.all([json('backend/cleanup.json'), json('backend/provenance.json')]);
    const backendIds = selected.filter(row => row.tier === 'B').map(row => row.id);
    if (report.scope !== 'backend-feature' || report.feature !== feature || JSON.stringify(report.selectedIds) !== JSON.stringify(backendIds) ||
        report.integrityError || cleanup.status !== 'PASS' || (target &&
          (provenance.status !== 'PASS' || report.targetSha !== target || report.harnessSha !== target))) {
      lane.error = 'Backend selection, provenance or cleanup validation failed. See backend manifest and original logs.';
    }
  } catch {
    lane.error = 'Backend report, cleanup or provenance is missing or unreadable.';
  }
  if (!Array.isArray(lane.results)) lane.results = [];
  lanes.push(lane);
}
if (selected.some(row => row.tier === 'F')) {
  const lane = { tier: 'F', results: [] };
  try {
    const report = await json('flutter/report.json');
    lane.results = report.cases;
    if (report.feature !== feature || !report.complete || (target &&
        (report.source?.verified !== true || report.source.sha !== target || report.harnessSha !== target)) ||
        (report.counts.PASS === report.planned && !report.flutterReporterSuccess)) {
      lane.error = 'Flutter selection, reporter completion or provenance validation failed. See Flutter original logs.';
    }
  } catch {
    lane.error = 'Flutter report is missing or unreadable.';
  }
  if (!Array.isArray(lane.results)) lane.results = [];
  lanes.push(lane);
}
const { results, gate, issues } = collectFeatureEvidence(selected, lanes);
const input = {
  scope: `feature-${feature}`, gate, source: { sha: target || 'UNVERIFIED', kind: target ? 'commit' : 'local', verified: Boolean(target) && !issues.length },
  harness: { sha: target || 'UNVERIFIED' }, selectedIds: selected.map(row => row.id), results,
  context: captureContext(root), execution: executionIdentity(), integrityError: issues.join('\n') || null,
};
const { report } = await generate({ inputObject: input, suite: 'developer', output: join(output, 'report'),
  artifact: `Vocle feature regression - ${feature}`,
  runUrl: process.env.GITHUB_RUN_ID && `https://github.com/mathiharan29/medcollab-beta/actions/runs/${process.env.GITHUB_RUN_ID}` });
const markdown = [
  `# Vocle feature regression - ${feature}`, '',
  `**${gate}** across ${selected.length} selected cases. ${report.attempted} executed.`, '',
  '| ID | Layer | Status | Executed |', '|---|---|---|---|',
  ...report.results.map(row => `| ${row.id} | ${row.tier === 'D' ? 'Android (local only)' : row.tier === 'F' ? 'Flutter' : 'Backend'} | ${row.status} | ${row.executed ? 'Yes' : 'No'} |`),
  '', ...issues.map(issue => `- ${issue}`),
].join('\n') + '\n';
await writeFile(join(output, 'feature-summary.md'), markdown);
if (process.env.GITHUB_STEP_SUMMARY) await appendFile(process.env.GITHUB_STEP_SUMMARY, markdown);
console.log(JSON.stringify({ feature, gate, selected: selected.length, attempted: report.attempted, counts: report.counts, issues }));
if (gate !== 'PASS') process.exitCode = 1;
