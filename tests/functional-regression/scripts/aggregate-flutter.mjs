import { captureContext, executionIdentity } from '../../developer-workflow/context.mjs';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const [input, outputBase] = process.argv.slice(2);
if (!input || !outputBase) {
  console.error('Usage: node aggregate-flutter.mjs <flutter-json-ndjson> <output-base>');
  process.exit(2);
}

const catalog = JSON.parse(fs.readFileSync(new URL('../catalog.json', import.meta.url), 'utf8'));
const flutterCatalog = new Map(catalog.cases.filter((item) => item.tier === 'F').map((item) => [item.id, item]));
const events = fs.readFileSync(input, 'utf8').split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
const starts = new Map();
const startedAt = new Map();
const prints = new Map();
const errors = new Map();
const results = [];
const seenIds = new Set();
for (const event of events) {
  if (event.type === 'testStart') {
    starts.set(event.test.id, event.test);
    startedAt.set(event.test.id, event.time ?? 0);
  } else if (event.type === 'print') {
    prints.set(event.testID, [...(prints.get(event.testID) ?? []), event.message]);
  } else if (event.type === 'error') {
    errors.set(event.testID, [...(errors.get(event.testID) ?? []), event]);
  } else if (event.type === 'testDone') {
    const started = starts.get(event.testID);
    const id = started?.name.match(/\bFR-[A-Z]+-\d{2}\b/)?.[0];
    if (!id) continue;
    if (!flutterCatalog.has(id)) throw new Error(`Unknown Flutter catalog ID ${id}`);
    if (seenIds.has(id)) throw new Error(`Duplicate Flutter test ID ${id}`);
    seenIds.add(id);
    const testErrors = errors.get(event.testID) ?? [];
    const log = [...(prints.get(event.testID) ?? []), ...testErrors.map((error) => error.error)].join('\n');
    const decision = started.name.includes('[NEEDS_DECISION ');
    if (decision && flutterCatalog.get(id).questionIds.length === 0) {
      throw new Error(`${id} marked NEEDS_DECISION without a catalog question`);
    }
    let status;
    if (event.skipped || event.result === 'skipped') status = 'SKIP';
    else if (event.result === 'success') status = decision ? 'NEEDS_DECISION' : 'PASS';
    else if (event.result === 'failure' || event.result === 'error') {
      status = testErrors.some((error) => error.isFailure === true) ||
        /TestFailure|EXCEPTION CAUGHT BY FLUTTER FRAMEWORK|EXCEPTION CAUGHT BY RENDERING LIBRARY/.test(log)
        ? 'FAIL' : 'ERROR';
    } else status = 'ERROR';
    results.push({
      id, status, title: started.name, priority: flutterCatalog.get(id).priority,
      questionIds: flutterCatalog.get(id).questionIds,
      durationMs: Math.max(0, (event.time ?? 0) - (startedAt.get(event.testID) ?? 0)),
      evidence: status === 'PASS' ? '' : log.slice(0, 8000),
    });
  }
}
results.sort((a, b) => a.id.localeCompare(b.id));
const done = events.findLast((event) => event.type === 'done');
if (!done) throw new Error('Flutter reporter did not emit a done event');
if (results.length === 0) throw new Error('No Flutter catalog test events found');
const counts = Object.fromEntries(['PASS', 'FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP'].map((status) =>
  [status, results.filter((item) => item.status === status).length]));
const complete = results.length === flutterCatalog.size;
const fullSuccess = complete && counts.PASS === flutterCatalog.size && done.success === true;
const repositoryRoot = path.resolve(import.meta.dirname, '../../..');
const sourceSha = execFileSync('git', ['-C', repositoryRoot, 'rev-parse', 'HEAD'], { encoding: 'utf8', windowsHide: true }).trim();
const report = { context: captureContext(repositoryRoot), execution: executionIdentity(), sourceKind: process.env.GITHUB_RUN_ID ? 'pr-head' : 'commit', source: { sha: sourceSha, kind: 'commit', verified: true }, harnessSha: sourceSha,
  schemaVersion: 1,
  tier: 'F',
  input: path.basename(input),
  planned: flutterCatalog.size,
  implementedAndExecuted: results.length,
  notImplemented: flutterCatalog.size - results.length,
  complete,
  fullSuccess,
  flutterReporterSuccess: done.success,
  counts,
  cases: results,
};
fs.mkdirSync(path.dirname(outputBase), { recursive: true });
fs.writeFileSync(`${outputBase}.json`, `${JSON.stringify(report, null, 2)}\n`);
const lines = [
  '# Vocle Flutter functional regression', '',
  `Implemented/executed: ${report.implementedAndExecuted}/${report.planned}; not implemented: ${report.notImplemented}.`,
  `Complete: ${complete}; full success: ${fullSuccess}; Flutter reporter success: ${done.success}.`,
  `PASS ${counts.PASS}; FAIL ${counts.FAIL}; ERROR ${counts.ERROR}; BLOCKED ${counts.BLOCKED}; NEEDS_DECISION ${counts.NEEDS_DECISION}; SKIP ${counts.SKIP}.`,
  '', '| ID | Status | Product questions |', '| --- | --- | --- |',
  ...results.map((item) => `| ${item.id} | ${item.status} | ${item.questionIds.join(', ')} |`),
];
fs.writeFileSync(`${outputBase}.md`, `${lines.join('\n')}\n`);
const escape = (value) => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const junit = [
  '<?xml version="1.0" encoding="UTF-8"?>',
  `<testsuite name="Vocle Flutter functional regression" tests="${results.length}" failures="${counts.FAIL + counts.NEEDS_DECISION}" errors="${counts.ERROR + counts.BLOCKED}" skipped="${counts.SKIP}">`,
  ...results.map((item) => {
    const head = `  <testcase name="${escape(item.id)}" classname="Flutter.${escape(flutterCatalog.get(item.id).module)}">`;
    if (item.status === 'PASS') return `${head}</testcase>`;
    if (item.status === 'SKIP') return `${head}<skipped/></testcase>`;
    const tag = item.status === 'FAIL' || item.status === 'NEEDS_DECISION' ? 'failure' : 'error';
    return `${head}<${tag} message="${escape(item.status)}">${escape(item.evidence || item.questionIds.join(', '))}</${tag}></testcase>`;
  }),
  '</testsuite>', '',
];
fs.writeFileSync(`${outputBase}.xml`, junit.join('\n'));
console.log(JSON.stringify({ input, outputBase, counts, complete, fullSuccess }));
