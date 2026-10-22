import { captureContext, executionIdentity, historyProblem, sealReport, verifiedReport } from '../developer-workflow/context.mjs';
import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { resolve, join, relative, basename, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { scenarioMetadata, hash } from './scenarios.mjs';
import { compareReports } from '../developer-workflow/evidence.mjs';
import { selectBackend } from '../functional-regression/scripts/ci-contracts.mjs';

export const statuses = ['PASS', 'FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP'];
export const root = resolve(fileURLToPath(new URL('../../', import.meta.url)));
const names = ['vocle-regression-dashboard.html', 'vocle-regression-detailed-report.md', 'vocle-regression-results.json', 'vocle-regression-junit.xml', 'vocle-regression-summary.md'];
const escape = value => String(value ?? '').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
const md = value => escape(value).replace(/[\\`*_{}\[\]()!#|]/g, '\\$&');
const json = value => JSON.stringify(value, null, 2) + '\n';
export const safePath = path => {
  if (typeof path !== 'string' || /[\u0000-\u001f<>"'`()\[\]]/.test(path)) return false;
  let decoded;
  try { decoded = decodeURIComponent(path); } catch { return false; }
  return !/^(?:[a-z]+:|[\\/])/i.test(decoded) && !decoded.split(/[\\/]/).includes('..');
};

export function sanitize(value) {
  if (Array.isArray(value)) return value.map(sanitize);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, /(?:password|secret|authorization|api[_-]?key|auth[_-]?key|^(?:access|refresh|device|widget|id|fcm|push|session)?[_-]?tokens?$|^otp(?:Hash)?$|^(?:set[-_]?)?cookie$|signedUrl)/i.test(k) ? '[REDACTED]' : sanitize(v)]));
  if (typeof value !== 'string') return value;
  return value.replace(/Bearer\s+[^\s'"<>]+/gi, 'Bearer [REDACTED]')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[JWT REDACTED]')
    .replace(/((?:password|secret|authorization|api[_-]?key|auth[_-]?key|(?:access|refresh|device|widget|fcm|push|session)?[_-]?tokens?|otp(?:Hash)?|(?:set[-_]?)?cookie|code)['"]?\s*[:=]\s*['"]?)[^\s'",;\n}]+/gi, '$1[REDACTED]')
    .replace(/\b(?:synthetic|dummy|sanity|test)[-_](?:access[-_]|refresh[-_]|device[-_]|widget[-_])?(?:secret|token|key)[A-Za-z0-9_-]*/gi, '[SYNTHETIC CREDENTIAL REDACTED]')
    .replace(/\b\d{6}\b/g, '[SIX-DIGIT CODE REDACTED]')
    .replace(/https?:\/\/[^\s<>"']+/g, raw => {
      try { const u = new URL(raw); if (u.username || u.password) { u.username = ''; u.password = ''; } if ([...u.searchParams.keys()].some(k => /token|sig|key|auth|password|code|secret|skt|ske|skoid/i.test(k))) u.search = '?REDACTED'; if (/^\/(?:[A-Za-z0-9_-]{8,}=?)\/ws$/.test(u.pathname)) u.pathname = '/REDACTED/ws'; return u.toString(); } catch { return '[URL REDACTED]'; }
    }).replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '');
}
function rowsOf(input) {
  return Array.isArray(input.results) ? input.results : input.results?.results || input.cases || input.scenarios || [];
}
const alias = { passed: 'PASS', failed: 'FAIL', blocked: 'BLOCKED', planned: 'SKIP', skipped: 'SKIP', error: 'ERROR' };
const tally = (rows, outcomes = statuses) => Object.fromEntries(outcomes.map(s => [s, rows.filter(r => r.status === s).length]));

export function normalize(input, metadata, options = {}) {
  const outcomes = options.statuses || statuses;
  const original = input.results?.results ? input.results : input;
  const provenance = input.provenance || options.provenance || original.provenance || {};
  if (options.suite === 'device' && process.env.GITHUB_RUN_ID) throw new Error('Android execution is LOCAL_ONLY; hosted relabeling is forbidden');
  const suite = options.suite || (original.tier === 'F' ? 'flutter' : original.tier === 'D' ? 'device' : original.scenarios ? 'sanity' : 'backend');
  const scope = original.scope || options.scope || (suite === 'backend' ? 'backend-all' : suite);
  const selected = suite === 'backend' ? selectBackend(metadata, scope, options.affected || []) : suite === 'sanity' ? metadata.filter(c => c.coverage === 'EXISTING') : suite === 'flutter' ? metadata.filter(c => c.tier === 'F') : suite === 'device' ? metadata.filter(c => c.tier === 'D') : [];
  const declared = original.selectedIds || (suite === 'device' ? original.selected : null);
  const requiredIds = declared || selected.map(c => c.id);
  if (declared && (new Set(declared).size !== declared.length || declared.some(id => !metadata.some(c => c.id === id)))) throw new Error('Invalid declared catalog selection');
  const byId = new Map(metadata.map(c => [c.id, c]));
  const rows = rowsOf(input);
  if (!Array.isArray(rows) || new Set(rows.map(r => r.id)).size !== rows.length) throw new Error('Duplicate or invalid evidence rows');
  const source = input.source || original.source || { sha: original.targetSha || original.sourceSha || original.metadata?.upstreamSha || provenance.targetSha || options.sourceSha || 'UNKNOWN', kind: original.sourceKind || provenance.sourceKind || options.sourceKind || 'UNKNOWN' };
  const harness = input.harness || original.harness || { sha: original.harnessSha || original.metadata?.harnessSha || provenance.harnessSha || options.harnessSha || 'UNKNOWN', fingerprint: original.fingerprint || provenance.fingerprint || options.fingerprint || null };
  const infra = [];
  if (original.integrityError) infra.push({ status: 'ERROR', category: 'INTEGRITY', message: original.integrityError });
  if (provenance.status === 'ERROR' || input.cleanup?.status === 'ERROR' || original.cleanup?.status === 'ERROR') infra.push({ status: 'ERROR', category: 'PROVENANCE_OR_CLEANUP', message: 'Original evidence reports failed provenance or cleanup; inspect the original report. Case statuses are preserved.' });
  if (!rows.length) infra.push({ status: suite === 'workflow' && options.skipped ? 'SKIP' : 'ERROR', category: 'EXECUTION', message: options.reason || 'Setup/execution did not produce case evidence. No test is claimed to have executed.' });
  const present = new Set(rows.map(r => r.id));
  const all = [...rows, ...requiredIds.filter(id => !present.has(id)).map(id => ({ id, status: options.skipped ? 'SKIP' : 'ERROR', executed: false, errorCategory: 'REPORT_MISSING', error: options.reason || 'No execution evidence was produced for this required case.' }))];
  const results = all.map(row => {
    if (!row.id) throw new Error('Missing testcase ID');
    const status = alias[row.status] || row.status;
    if (!outcomes.includes(status)) throw new Error(`Unknown status for ${row.id}`);
    const definition = byId.get(row.id);
    if (!definition && ['backend', 'flutter', 'device', 'sanity'].includes(suite)) throw new Error(`Unknown catalog ID ${row.id}`);
    if (requiredIds.length && !requiredIds.includes(row.id)) throw new Error(`Unselected evidence ID ${row.id}`);
    const executed = row.executed ?? (!['BLOCKED', 'SKIP'].includes(status) && !['REPORT_MISSING', 'SETUP', 'DEVICE_PREREQUISITE', 'DEPENDENCY'].includes(row.errorCategory));
    if (definition?.tier === 'D' && executed && process.env.GITHUB_RUN_ID) throw new Error('Local Android evidence cannot be relabeled as hosted execution');
    if (status === 'PASS' && !executed) throw new Error(`Unexecuted PASS ${row.id}`);
    const diagnostic = row.error || row.evidence || row.exclusion || '';
    const text = typeof diagnostic === 'string' ? diagnostic : JSON.stringify(diagnostic, null, 2);
    const http = /((?:GET|POST|PUT|DELETE|PATCH)\s+\S+) expected (\d+), got (\d+)/.exec(text);
    const type = row.category || (status === 'FAIL' ? 'APPLICATION_DEFECT_RECORDED' : status === 'ERROR' ? /HARNESS|INVALID_CASE/.test(row.errorCategory || '') ? 'TEST_HARNESS_PROBLEM' : 'INFRASTRUCTURE_OR_HARNESS_ERROR' : status === 'BLOCKED' ? 'BLOCKED_DEPENDENCY' : status === 'NEEDS_DECISION' ? 'UNRESOLVED_PRODUCT_DECISION' : status);
    const outcome = status === 'PASS' ? 'The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.' : status === 'NEEDS_DECISION' ? 'The full expectation is undecided. Only explicitly recorded safe subassertions receive credit; the disputed expectation has not passed.' : !executed ? 'No execution is claimed. Resolve the missing evidence or prerequisite before judging application behavior.' : 'The runner recorded a non-passing case. Later actions may not have been reached; diagnostic evidence is shown without changing its classification.';
    return {
      ...definition, id: row.id, title: definition?.title || row.title || row.name || row.id, module: definition?.module || row.module || 'TOOLING', priority: definition?.priority || row.priority || 'UNSPECIFIED', tier: definition?.tier || 'TOOLING',
      status, executionMode: row.executionMode || (suite === 'device' ? 'LOCAL_ONLY' : 'HOSTED_OR_LOCAL'), originalStatus: row.status, errorCategory: row.errorCategory || null, executed, durationMs: Number.isFinite(row.durationMs) ? row.durationMs : null, source, harness,
      scenario: definition?.scenario || `Automated environment/tooling check: ${row.title || row.id}.`, prerequisites: definition?.prerequisites || 'Use the original reproduction command and isolated environment recorded by the runner.',
      steps: definition?.steps || [{ number: 1, action: input.reproduction || 'Use the recorded tooling command; no UI reproduction is claimed.', expected: row.expected || 'Required tooling check completes with valid evidence.' }],
      expected: row.expected || definition?.expected || 'See the original check definition.', actual: row.actual != null ? (typeof row.actual === 'string' ? row.actual : JSON.stringify(row.actual, null, 2)) : status === 'PASS' ? outcome : text || (status === 'NEEDS_DECISION' ? `Pending ${definition?.questionIds?.join(', ') || 'product clarification'}. No additional observed values recorded.` : 'No diagnostic detail was captured; inspect original runner output.'),
      comparisonExpected: http ? `${http[1]} HTTP ${http[2]}` : row.assertionExpected ?? 'Individual assertion expected value not captured; use the case contract and definition.',
      comparisonActual: http ? `HTTP ${http[3]}` : row.assertionActual ?? 'Individual actual value not captured beyond the diagnostic above.',
      failingStep: row.failingStep || (http ? http[1] : status === 'PASS' ? 'None reported' : 'Exact step index not captured by the original runner; inspect diagnostic and definition.'),
      category: type, rootCause: row.rootCause ? `Explicit runner finding (not independently confirmed here): ${row.rootCause}` : 'UNKNOWN. This report does not infer a root cause from a status or similar message.',
      userImpact: status === 'PASS' ? 'This recorded execution protects the described scenario within its stated scope.' : `Inferred consequence, not an observed production/UI incident: the described ${definition?.moduleName || row.module || 'tooling'} scenario is not fully verified. ${!executed ? 'Missing execution cannot establish an application defect.' : status === 'NEEDS_DECISION' ? 'The intended user-visible contract requires product agreement.' : 'The diagnostic identifies the observed failure; its wider impact requires investigation.'}`,
      outcome, verifiedSubassertions: row.verifiedSubassertions || (Array.isArray(row.evidence) ? row.evidence : []), prerequisiteSeed: row.prerequisiteSeed || null,
      diagnostic: text, evidenceFiles: (row.evidenceFiles || []).filter(safePath), owner: 'UNASSIGNED',
    };
  });
  const rawCounts = tally(results.filter(r => present.has(r.id)), outcomes);
  const declaredCounts = original.tally || original.counts;
  if (declaredCounts && outcomes.some(s => (declaredCounts[s] || 0) !== rawCounts[s])) throw new Error('Original status counts disagree with rows');
  const definitionSet = hash(JSON.stringify(results.map(r => [r.id, r.definitionFingerprint || null]).sort()));
  const environmentFingerprint = original.environmentFingerprint || options.environmentFingerprint || (original.environmentContractVersion ? hash(JSON.stringify({ version: original.environmentContractVersion, suite, platform: original.platform || null })) : options.environmentFingerprint || null);
  const report = { context: original.context || provenance.context || options.context || null, execution: original.execution || provenance.execution || options.execution || null, schemaVersion: 1, reportingContractVersion: 1, suite, scope, sourceKind: original.sourceKind || source.kind || options.sourceKind || 'UNKNOWN', source, harness, environmentFingerprint,
    definitionSet, generatedAt: original.generatedAt || original.createdAt || options.generatedAt || null, runUrl: /^https:\/\/github\.com\/mathiharan29\/medcollab-beta\/actions\/runs\/\d+$/.test(options.runUrl || '') ? options.runUrl : null,
    originalGate: original.result || original.gate || (original.fullSuccess === true ? 'PASS' : original.fullSuccess === false ? 'NON_SUCCESS' : 'UNKNOWN'),
    selected: requiredIds.length || rows.length, recorded: rows.length, attempted: results.filter(r => r.executed).length, counts: tally(results, outcomes), originalCounts: rawCounts,
    catalogCoverage: { total: 187, hosted: 179, localOnly: 8, cases: metadata.filter(c => c.tier === 'D').map(c => ({ id: c.id, executionMode: 'LOCAL_ONLY', executed: results.find(r => r.id === c.id)?.executed || false, status: results.find(r => r.id === c.id)?.status || 'SKIP' })) }, infrastructure: infra, results, comparison: { available: false, reason: 'No compatible baseline was supplied.' },
    note: 'Reporting does not change test exit codes, success-history evidence, assertions or original classifications. Definition/procedure text is not a per-step execution trace. Ownership requires an approved mapping.' };
  if (options.statuses) report.statuses = outcomes;
  report.synthetic = input.synthetic === true || original.synthetic === true;
  if (report.synthetic) report.note = 'Synthetic reporter fixture; no application execution evidence. ' + report.note;
  return sanitize(report);
}

export function compare(current, previous) {
  if (current.synthetic || previous?.synthetic) return { available:false, status:'UNAVAILABLE', reason:'Synthetic reporter fixtures are not execution evidence' };
  const problem = historyProblem(current, previous);
  if (problem || !verifiedReport(previous)) return { available: false, status: 'UNAVAILABLE', reason: problem || 'Previous report integrity is missing or invalid' };
  const committed = r => ['upstream-read-only', 'pr-head', 'committed-fork-archive'].includes(r.sourceKind) || (r.source.kind === 'commit' && r.source.verified === true);
  const compatible = previous?.reportingContractVersion === current.reportingContractVersion && committed(current) && committed(previous) && ![...current.infrastructure, ...previous.infrastructure].some(e=>e.status==='ERROR') && previous.suite === current.suite && previous.scope === current.scope && previous.sourceKind === current.sourceKind && previous.definitionSet === current.definitionSet && current.environmentFingerprint && previous.environmentFingerprint === current.environmentFingerprint && current.harness.fingerprint && previous.harness?.fingerprint === current.harness.fingerprint && [current.source.sha, previous.source?.sha, current.harness.sha, previous.harness?.sha].every(v => /^[a-f0-9]{40}$/.test(v || ''));
  if (!compatible) return { available: false, status: 'UNAVAILABLE', reason: 'Baseline has incompatible or missing suite/scope, definitions, source kind, harness fingerprint or environment evidence.' };
  // Reuse the repository's existing conservative comparison contract.
  const adapt = r => ({ ...r, source: { ...r.source, kind: 'commit' }, results: r.results.map(x => ({ ...x, required: true, environmentFingerprint: r.environmentFingerprint })) });
  const comparison = compareReports(adapt(previous), adapt(current));
  // The existing comparator's catch-all label also covers identical non-pass
  // statuses. Make that stable uncertainty explicit without changing outcomes.
  comparison.rows = comparison.rows.map(r=>r.classification === 'STATUS_CHANGED' && r.oldStatus === r.newStatus ? {...r, classification:'UNCHANGED_NONPASS', reason:'The same non-passing status remains; no fix or new functional regression is inferred.'} : r);
  return { available: true, ...comparison };
}

export function summary(report, artifact = 'Vocle report artifact') {
  const localOnly = report.catalogCoverage?.cases || report.results.filter(r => r.executionMode === 'LOCAL_ONLY');
  const localCoverage = localOnly.length ? '\n\nAndroid local availability: ' + localOnly.map(r => `${r.id} — LOCAL_ONLY; executed ${Boolean(r.executed)}; ${r.status}`).join('; ') + '.' : '';
  return `# Vocle regression report\n\nArtifact: **${md(artifact)}**. Download and extract it, then open \`vocle-regression-dashboard.html\` locally.\n\n${report.runUrl ? `[GitHub Actions run](${report.runUrl})\n\n` : ''}Suite: ${md(report.suite)}; scope: ${md(report.scope)}; original gate: **${md(report.originalGate)}**.\n\nSource: \`${md(report.source.sha)}\`; harness: \`${md(report.harness.sha)}\`.\n\n| ${(report.statuses || statuses).join(' | ')} |\n| ${(report.statuses || statuses).map(()=>'---').join(' | ')} |\n| ${(report.statuses || statuses).map(s => report.counts[s]).join(' | ')} |\n\nFunctional catalog: 187 total / 179 hosted / 8 LOCAL_ONLY.\n\n${localCoverage}\n\nSelected ${report.selected}; recorded rows ${report.recorded}; attempted ${report.attempted}. Missing evidence never means PASS.\n\n${(report.applicationFailures || []).map(e => `- FAIL ${md(e.category || 'APPLICATION_FAILURE')}: ${md(JSON.stringify(e))}`).join('\n')}\n\n${report.infrastructure.map(e => `- ${e.status} ${md(e.category)}: ${md(e.message)}`).join('\n')}\n\n${report.comparison.available ? 'Compatible baseline comparison included; changes are evidence classifications, not root-cause confirmation.' : 'historical comparison: UNAVAILABLE\nreason: ' + md(report.comparison.reason)}\n\n${md(report.note)}\n`;
}
export function detailed(report) {
  return `${summary(report)}\n${report.results.map(r => `## ${md(r.id)} — ${md(r.title)}\n\n**${r.status}**${r.executionMode === 'LOCAL_ONLY' ? ' (LOCAL_ONLY)' : ''}; module ${md(r.module)}; tier ${r.tier}; priority ${r.priority}; owner ${md(r.owner)}; attempted ${r.executed}; duration ${r.durationMs ?? 'not recorded'} ms.\n\nSource ${md(r.source.sha)}; harness ${md(r.harness.sha)}.\n\n### Real-life scenario\n\n${md(r.scenario)}\n\n### Prerequisites and reproduction\n\n${md(r.prerequisites)}\n\n${md(r.reproduction || '')}\n\n${r.prerequisiteSeed ? `Component prerequisite: ${md(r.prerequisiteSeed)}\n\n` : ''}${r.steps.map(s => `${s.number}. ${md(s.action)}\n   Expected: ${md(s.expected)}`).join('\n')}\n\n### Expected and observed results\n\nContract: ${md(r.expected)}\n\nObserved: ${md(r.actual)}\n\nFailing step: ${md(r.failingStep)}\n\nAssertion expected: ${md(r.comparisonExpected)}\n\nAssertion actual: ${md(r.comparisonActual)}\n\nClassification: ${md(r.category)}\n\nRoot cause: ${md(r.rootCause)}\n\n${md(r.outcome)}\n\n${md(r.userImpact)}\n\nExplicit subassertion evidence: ${md(JSON.stringify(r.verifiedSubassertions))}\n\nScope/limitations: ${md(r.limitations || 'See original runner scope.')}\n\nProduct questions: ${md((r.questionIds || []).join(', ') || 'none linked')}\n\nEvidence files: ${r.evidenceFiles.map(f => `[${md(f)}](${encodeURI(f)})`).join(', ') || 'No additional files available.'}\n\n### Sanitized diagnostic\n\n<pre>${escape(r.diagnostic || 'No additional diagnostic recorded.')}</pre>\n\n### Executable definition (procedure, not execution log)\n\n${(r.definitions || []).map(d => `${md(d.path)}:${d.line}; SHA-256 ${d.fileHash}\n\n<pre>${escape(d.excerpt)}</pre>`).join('\n\n') || 'Definition location unavailable; original tooling reproduction is shown above.'}\n`).join('\n')}`;
}

export function junit(report) {
  const c = report.counts;
  const infra = report.infrastructure.filter(i => i.status === 'ERROR');
  const app = report.applicationFailures || [];
  return `<?xml version="1.0" encoding="UTF-8"?>\n<testsuites><testsuite name="Vocle.${escape(report.suite)}" tests="${report.results.length}" failures="${c.FAIL + c.BLOCKED + c.NEEDS_DECISION}" errors="${c.ERROR}" skipped="${c.SKIP + (c.OBSERVATION || 0)}">\n${report.results.map(r => `<testcase classname="${escape(r.module)}" name="${escape(r.id)}"${r.durationMs !== null ? ` time="${r.durationMs / 1000}"` : ''}><properties><property name="vocle.status" value="${r.status}"/><property name="vocle.attempted" value="${r.executed}"/></properties>${r.status === 'PASS' ? '' : `<${['SKIP','OBSERVATION'].includes(r.status) ? 'skipped' : r.status === 'ERROR' ? 'error' : 'failure'} message="${escape(r.status)}">${escape(r.actual)}</${['SKIP','OBSERVATION'].includes(r.status) ? 'skipped' : r.status === 'ERROR' ? 'error' : 'failure'}>`}</testcase>`).join('\n')}\n</testsuite><testsuite name="Vocle.infrastructure" tests="${infra.length}" errors="${infra.length}">${infra.map(i => `<testcase name="${escape(i.category)}"><error>${escape(i.message)}</error></testcase>`).join('')}</testsuite><testsuite name="Vocle.application-prerequisites" tests="${app.length}" failures="${app.length}">${app.map(i => `<testcase name="${escape(i.category)}"><failure>${escape(JSON.stringify(i))}</failure></testcase>`).join('')}</testsuite></testsuites>\n`;
}

export async function writeReports(output, report, options = {}) {
  await mkdir(output, { recursive: true });
  sealReport(report);
  const template = await readFile(new URL('dashboard.html', import.meta.url), 'utf8');
  // A non-executable JSON script plus escaped '<' prevents a test log closing it.
  const embedded = JSON.stringify(report).replaceAll('<', '\\u003c').replaceAll('>', '\\u003e').replaceAll('&', '\\u0026').replaceAll('\u2028', '\\u2028').replaceAll('\u2029', '\\u2029');
  const html = template.replace('REPORT_JSON_PLACEHOLDER', () => embedded);
  await Promise.all(names.map((n, i) => writeFile(join(output, n), [html, detailed(report), json(report), junit(report), summary(report, options.artifact)][i])));
  return report;
}

async function logs(directory, output) {
  const links = [];
  async function walk(p) {
    for (const e of await readdir(p, { withFileTypes: true }).catch(() => [])) {
      if (['node_modules', 'target', 'runtime', 'mongo-binaries', 'logs', '.git'].includes(e.name)) continue;
      const f = join(p, e.name);
      if (e.isSymbolicLink()) continue;
      if (e.isDirectory()) await walk(f);
      else if (/\.(?:log|ndjson|ndjsonl|txt)$/.test(e.name) || e.name === 'triage.md') {
        const rel = relative(directory, f).replaceAll('\\', '/');
        const dest = join(output, 'logs', rel);
        await mkdir(resolve(dest, '..'), { recursive: true });
        await writeFile(dest, sanitize(await readFile(f, 'utf8')));
        links.push('logs/' + rel);
      }
    }
  }
  await walk(directory);
  return links.sort();
}

export async function generate(options) {
  const metadata = await scenarioMetadata(root);
  let input = options.inputObject || {}, readError;
  if (options.input) { try { input = JSON.parse(await readFile(options.input, 'utf8')); } catch (error) { readError = error.code === 'ENOENT' ? 'Result file absent: setup or execution did not produce evidence.' : 'Result file unreadable or malformed; original diagnostics are required.'; } }
  let provenance = {};
  if (options.evidenceDir) { try { provenance = JSON.parse(await readFile(join(options.evidenceDir, 'provenance.json'), 'utf8')); } catch { /* report carries its own source when available */ } }
  let report;
  try { report = normalize(input, metadata, { ...options, provenance, reason: readError || options.reason }); }
  catch (error) {
    // Preserve independently recorded failures when a different row or tally is
    // malformed. The separate reporting error prevents any suite success claim.
    const outcomes = options.statuses || statuses;
  const original = input.results?.results ? input.results : input;
    const groups = new Map();
    for (const row of rowsOf(input)) {
      if (!row?.id || (!metadata.some(c=>c.id===row.id) && options.suite !== 'developer')) continue;
      const group = groups.get(row.id) || []; group.push(row); groups.set(row.id, group);
    }
    const recovered = [...groups].map(([id, group]) => {
      const failure = group.find(r => (alias[r.status] || r.status) === 'FAIL');
      if (failure) return failure;
      if (group.length === 1 && statuses.includes(alias[group[0].status] || group[0].status) && !((alias[group[0].status] || group[0].status) === 'PASS' && group[0].executed === false)) return group[0];
      return { id, status: 'ERROR', executed: false, errorCategory: 'REPORT_MISSING', error: 'Conflicting or invalid original observations; inspect reporting validation evidence.' };
    });
    const selectedIds = original.selectedIds && new Set(original.selectedIds).size === original.selectedIds.length && original.selectedIds.every(id=>metadata.some(c=>c.id===id)) ? [...new Set([...original.selectedIds, ...recovered.map(r=>r.id)])] : undefined;
    const recovery = { ...original, results: recovered, selectedIds, tally: undefined, counts: undefined, ...(options.suite === 'backend' && !['backend-all','backend-p0'].includes(original.scope) ? {scope:'backend-all'} : {}) };
    report = normalize(recovery, metadata, { ...options, provenance, reason: `Reporting validation error: ${error.message}` });
    report.infrastructure.push({ status: 'ERROR', category: 'REPORT_VALIDATION', message: sanitize(error.message) });
    report.originalObservations = sanitize(rowsOf(input));
    options.validationFailed = true;
  }
  try { report.metadataRevision = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8', windowsHide: true }).trim(); }
  catch { report.metadataRevision = 'UNKNOWN'; }
  report.note += ` Procedure metadata was read from the reporter checkout ${report.metadataRevision}; recorded execution revisions remain separate. Older evidence does not prove newly changed definitions passed.`;
  let owner = {};
  try { owner = JSON.parse(await readFile(join(root, 'tests/developer-workflow/ownership.json'))); } catch { /* unknown remains unassigned */ }
  if (owner.approved) for (const r of report.results) r.owner = sanitize(owner.modules?.[r.module] || 'UNASSIGNED');
  if (!report.environmentFingerprint && options.evidenceDir) {
    try { report.environmentFingerprint = hash(await readFile(join(options.evidenceDir, 'sdk.txt'))); } catch { /* no invented compatibility */ }
  }
  if (!report.harness.fingerprint) {
    try { report.harness.fingerprint = execFileSync(process.execPath, [join(root, 'tests/functional-regression/scripts/fingerprint.mjs')], { encoding: 'utf8', timeout: 30000, windowsHide: true }).trim(); } catch { /* missing fingerprint makes comparison unavailable */ }
  }
  // Persist complete current reports before any optional network enrichment.
  await writeReports(resolve(options.output), report, options);
  if (options.history === 'true' && !options.baseline) {
    try {
      const { priorCompatible } = await import('./history.mjs');
      const previous = await priorCompatible(report, compare);
      report.comparison = previous ? { ...compare(report, previous.report), baselineRunId: previous.runId, baselineAttempt: previous.attempt, baselineArtifactId: previous.artifactId } : { available: false, reason: 'No compatible completed execution in the same development context.' };
      if (report.comparison.available) for (const r of report.results) r.change = report.comparison.rows.find(x => x.id === r.id)?.classification;
    } catch (error) { report.comparison = { available: false, reason: `Optional baseline lookup unavailable: ${sanitize(error.message)}. No change classification inferred.` }; }
  }
  if (options.baseline) {
    try { report.comparison = compare(report, JSON.parse(await readFile(options.baseline, 'utf8'))); }
    catch { report.comparison = { available: false, reason: 'Baseline unavailable or invalid; no change classification inferred.' }; }
    if (report.comparison.available) for (const r of report.results) r.change = report.comparison.rows.find(x => x.id === r.id)?.classification;
  }
  report.comparison.status = report.comparison.available ? 'AVAILABLE' : 'UNAVAILABLE';
  const output = resolve(options.output);
  if (options.evidenceDir) {
    const evidenceDirectory = resolve(options.evidenceDir);
    if (evidenceDirectory.startsWith(output + sep)) throw new Error('Evidence directory cannot be a descendant of report output');
    const available = await logs(evidenceDirectory, output);
    for (const r of report.results) r.evidenceFiles = available.filter(safePath); // Available run logs, not claimed per-case correlation.
  }
  await writeReports(output, report, options);
  if (options.stepSummary) await writeFile(options.stepSummary, summary(report, options.artifact), { flag: 'a' });
  return { report, validationFailed: Boolean(options.validationFailed) };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const options = {};
  for (let i = 2; i < process.argv.length; i += 2) {
    if (!process.argv[i].startsWith('--') || process.argv[i + 1] === undefined) throw new Error('Use --name value arguments');
    const key = process.argv[i].slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    options[key] = process.argv[i + 1];
  }
  options.output ||= 'tests/reporting/output';
  options.affected = (options.affected || process.env.VOCLE_AFFECTED_MODULES || '').split(',').filter(Boolean);
  options.sourceSha ||= process.env.VOCLE_TARGET_SHA;
  options.harnessSha ||= process.env.VOCLE_HARNESS_SHA || process.env.GITHUB_SHA;
  options.sourceKind ||= process.env.VOCLE_TARGET_KIND;
  options.scope ||= process.env.VOCLE_SCOPE;
  options.stepSummary ||= process.env.GITHUB_STEP_SUMMARY;
  options.runUrl ||= process.env.GITHUB_RUN_ID ? `https://github.com/mathiharan29/medcollab-beta/actions/runs/${process.env.GITHUB_RUN_ID}` : null;
  options.skipped = options.skipped === 'true';
  if (options.current === 'true') {
    const checkoutSha = execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8', windowsHide: true }).trim();
    if (!process.env.GITHUB_RUN_ID || checkoutSha !== options.sourceSha || checkoutSha !== options.harnessSha) throw new Error('Current hosted reporting requires the exact checked-out PR source/harness');
    options.context = captureContext(root);
    options.execution = executionIdentity();
  }
  const { report, validationFailed } = await generate(options);
  console.log(JSON.stringify({ suite: report.suite, counts: report.counts, attempted: report.attempted, output: options.output, validationFailed }));
  // Case failure exits remain owned by original gates; a broken reporter still fails.
  if (validationFailed) process.exitCode = 1;
}
