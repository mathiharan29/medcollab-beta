// Phase 00 static metadata inspection only. Never import application modules.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const docs = 'docs/performance/';
const frozen = `${docs}plan/`;
const repository = 'mathiharan29/medcollab-beta';
const base = '4c01dc24247aa95a73e286a2b42c7f2f81257c7a';
const read = (name) => readFileSync(path.join(root, name), 'utf8').replaceAll('\r\n', '\n');
const json = (name) => JSON.parse(read(name));
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
const normalizedHash = (name) => hash(read(name).replaceAll('\r\n', '\n'));
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
const sorted = (values) => [...values].sort();
const unique = (values, label) => assert.equal(new Set(values).size, values.length, `${label}: duplicate`);
const ownership = json(`${frozen}CASE-OWNERSHIP.json`);
const specification = json(`${frozen}PLAN-SPECIFICATION.json`);
const catalog = json('tests/performance/catalog.json');
const sourceMap = json(`${docs}source-map.json`);
const sourceSnapshot = json(`${docs}source-snapshot.json`);
const planManifest = json(`${docs}plan-manifest.json`);
const stale = json(`${docs}stale-references.json`);

assert.equal(git('remote', 'get-url', 'origin'), `https://github.com/${repository}.git`);
assert.equal(git('remote', 'get-url', '--push', 'origin'), `https://github.com/${repository}.git`);
assert.equal(git('branch', '--show-current'), 'testing/vocle-performance-scale');
git('merge-base', '--is-ancestor', base, 'HEAD');
for (const document of [catalog, sourceMap, sourceSnapshot, planManifest]) {
  assert.equal(document.schemaVersion, 1);
  assert.equal(document.repository, repository);
  assert.equal(document.sourceSha, base);
}
assert.equal(stale.investigationSha, base);
assert.equal(stale.sourceSha, base);
assert.equal(stale.comparison, 'IDENTICAL');
assert.deepEqual(stale.changedPaths, []);
assert.deepEqual(stale.entries, []);

assert.equal(planManifest.files.length, 32);
unique(planManifest.files.map((file) => file.path), 'plan files');
assert.deepEqual(sorted(readdirSync(path.join(root, frozen))), sorted(planManifest.files.map((file) => file.path)));
for (const file of planManifest.files) {
  assert.equal(hash(readFileSync(path.join(root, frozen, file.path))), file.sha256, `Frozen plan changed: ${file.path}`);
}
assert.equal(normalizedHash(`${frozen}ORIGINAL-MASTER-REPORT.md`),
  '4be22850ab998a1f55be981af5fc556c244670b3deca6944bb4266abdcfc63c6');
assert.equal(planManifest.files.filter((file) => file.path.startsWith('PHASE-')).length, 23);

assert.equal(catalog.inventoryCount, 45);
assert.equal(catalog.cases.length, 45);
assert.equal(catalog.phase, '00');
assert.equal(catalog.executionAuthorized, false);
unique(catalog.cases.map((entry) => entry.id), 'case IDs');
assert.deepEqual(sorted(catalog.cases.map((entry) => entry.id)), sorted(Object.keys(ownership)));
const caseIds = new Set(Object.keys(ownership));
const operationIds = new Set(sourceMap.operations.map((op) => op.id));
for (const entry of catalog.cases) {
  const original = ownership[entry.id];
  for (const field of ['title', 'priority', 'phase', 'status', 'dependencies']) {
    assert.deepEqual(entry[field], original[field], `${entry.id}: ${field}`);
  }
  assert.equal(entry.ownerPhase, original.phase.split('-')[1]);
  assert.equal(entry.implementation, 'NOT_IMPLEMENTED');
  assert.equal(entry.review, 'NOT_REVIEWED');
  assert.equal(entry.execution, 'NOT_EXECUTED');
  assert.equal(entry.threshold, 'BASELINE_REQUIRED');
  assert.equal(entry.productThreshold, 'PRODUCT_DECISION_REQUIRED');
  assert.equal(entry.staticValidation, 'NOT_VALIDATED'); // No scenario code exists to validate.
  assert.deepEqual(entry.scenarioModules, []);
  assert.deepEqual(entry.variants, []);
  assert.equal(entry.deferred.ownerPhase, original.phase);
  assert.ok(entry.deferred.reason && entry.deferred.prerequisite);
  assert.deepEqual(entry.plannedScenarioSequence, specification.steps[entry.id]);
  assert.ok(entry.originalSpecification.length > 80);
  const matrixRow = read(`${frozen}TEST-CASE-MATRIX.md`).split('\n').find((line) => line.startsWith(`| [${entry.id}]`));
  assert.equal(entry.sourceEvidence, matrixRow.split('|')[6].trim());
  const phaseText = read(`${frozen}${original.phase}`);
  assert.ok(phaseText.includes(entry.originalSpecification), `${entry.id}: original specification changed`);
  assert.equal(entry.specificationRef, `${frozen}${original.phase}#${entry.id.toLowerCase()}`);
  const owners = specification.phases.filter((phase) => phase[3].includes(entry.id));
  assert.equal(owners.length, 1, `${entry.id}: phase ownership`);
  assert.equal(String(owners[0][0]).padStart(2, '0'), entry.ownerPhase);
  for (const dependency of entry.dependencies) assert.ok(caseIds.has(dependency), `${entry.id}: unknown dependency`);
  for (const operation of entry.operationIds) assert.ok(operationIds.has(operation), `${entry.id}: unknown operation`);
  assert.deepEqual(sorted(entry.operationIds), sorted(sourceMap.operations.filter((op) => op.caseIds.includes(entry.id)).map((op) => op.id)));
  assert.ok(entry.inherited.preconditions.length >= 6 && entry.inherited.cleanup.length >= 7);
  assert.equal(entry.inherited.baselineAcceptance, 'BASELINE_REQUIRED');
  assert.equal(entry.inherited.productObjectives, 'PRODUCT_DECISION_REQUIRED');
}
const visited = new Set();
const visiting = new Set();
function visit(id) {
  assert.ok(!visiting.has(id), `Case dependency cycle: ${id}`);
  if (visited.has(id)) return;
  visiting.add(id);
  for (const dependency of ownership[id].dependencies) visit(dependency);
  visiting.delete(id);
  visited.add(id);
}
for (const id of caseIds) visit(id);

assert.equal(sourceMap.featureRouteCount, 87);
assert.equal(sourceMap.operationCount, 124);
assert.equal(sourceMap.operations.length, 124);
unique(sourceMap.operations.map((op) => op.id), 'operation IDs');
for (const [family, count] of Object.entries({ AUTH: 5, USER: 8, SPC: 12, CH: 13, MSG: 8, REQ: 5, HND: 10, NOT: 7, SRC: 1, MED: 2, ADM: 10, SUP: 3, DEV: 3, SYS: 6, RT: 23, BG: 8 })) {
  const expected = Array.from({ length: count }, (_, index) => `OP-${family}-${String(index + 1).padStart(2, '0')}`);
  assert.deepEqual(sorted(sourceMap.operations.filter((op) => op.id.startsWith(`OP-${family}-`)).map((op) => op.id)), expected);
}
const snapshotPaths = new Set(sourceSnapshot.files.map((file) => file.path));
for (const file of sourceSnapshot.files) {
  assert.ok(Number.isInteger(file.line) && file.line > 0 && file.line <= read(file.path).split('\n').length);
  assert.equal(normalizedHash(file.path), file.sha256, `Source drift: ${file.path}; record and review stale references`);
}
const actual = [];
const app = read('medcollab-backend/src/app.js');
const featureFiles = readdirSync(path.join(root, 'medcollab-backend/src/features'), { recursive: true })
  .filter((name) => name.endsWith('.routes.js'));
for (const filename of featureFiles) {
  const relative = `medcollab-backend/src/features/${filename.replaceAll('\\', '/')}`;
  const text = read(relative);
  // Intentionally constrained to the pinned source's literal router syntax.
  // Hash drift above rejects unfamiliar source instead of guessing new semantics.
  for (const match of text.matchAll(/^(\w+)\.(get|post|put|delete|patch)\(\s*'([^']+)'/gm)) {
    actual.push({ relative, router: match[1], method: match[2].toUpperCase(), suffix: match[3], line: text.slice(0, match.index).split('\n').length });
  }
}
assert.equal(actual.length, 87, 'Feature registration count drift');
const used = new Set();
for (const op of sourceMap.operations) {
  assert.match(op.id, /^OP-[A-Z]+-\d{2}$/);
  unique(op.caseIds, `${op.id} cases`);
  for (const id of op.caseIds) assert.ok(caseIds.has(id), `${op.id}: unknown case ${id}`);
  assert.ok(op.caseIds.length || op.exclusion, `${op.id}: silent omission`);
  for (const ref of [...op.sourceRefs, ...(op.routeRef ? [op.routeRef] : [])]) {
    assert.ok(snapshotPaths.has(ref.path), `${op.id}: source outside snapshot ${ref.path}`);
    assert.ok(Number.isInteger(ref.line) && ref.line > 0 && ref.line <= read(ref.path).split('\n').length);
  }
  if (op.kind !== 'feature-route') continue;
  const matches = actual.filter((route) => route.relative === op.routeRef.path && route.router === op.router && route.method === op.method && route.line === op.routeRef.line);
  assert.equal(matches.length, 1, `${op.id}: missing registration`);
  const route = matches[0];
  const mount = [...app.matchAll(/app\.use\('([^']+)',\s*(\w+)\);/g)].find((match) => match[2] === op.mountVariable);
  assert.ok(mount, `${op.id}: missing mount`);
  assert.equal(mount[1] + (route.suffix === '/' ? '' : route.suffix), op.path);
  const key = `${op.method} ${op.path}`;
  assert.ok(!used.has(key), `Duplicate route: ${key}`);
  used.add(key);
  if (op.handler !== 'inline') {
    assert.match(read(op.sourceRefs[0].path).split('\n')[op.sourceRefs[0].line - 1], new RegExp(`^(?:const ${op.handler}\\s*=|(?:async )?function ${op.handler}\\b)`));
  }
  if (op.id.startsWith('OP-DEV-')) {
    assert.deepEqual(op.caseIds, []);
    assert.equal(op.exclusion.runtimeSelection, 'FORBIDDEN_AS_USER_WORKLOAD');
  } else {
    assert.ok(op.caseIds.includes('PERF-API-001'), `${op.id}: baseline traceability`);
  }
}
assert.equal(used.size, 87);
assert.equal(sourceMap.operations.find((op) => op.id === 'OP-CH-06').aliasOf, 'OP-CH-05');
assert.equal(sourceMap.operations.some((op) => op.event === 'send_message'), false);

// Check local Markdown file links and anchors without visiting external URLs.
function slug(heading) {
  return heading.toLowerCase().replace(/[^\p{L}\p{N}_\-\s]/gu, '').replace(/\s/g, '-');
}
for (const filename of readdirSync(path.join(root, docs), { recursive: true }).filter((name) => name.endsWith('.md'))) {
  const relative = `${docs}${filename.replaceAll('\\', '/')}`;
  const text = read(relative);
  for (const match of text.matchAll(/\[[^\]\n]*\]\(([^)\s]+)\)/g)) {
    const target = match[1];
    if (/^(?:https?:|mailto:)/.test(target)) continue;
    const [file, anchor] = target.split('#');
    const resolved = path.resolve(root, path.dirname(relative), decodeURIComponent(file || path.basename(relative)));
    assert.ok(existsSync(resolved), `${relative}: broken local link ${target}`);
    if (anchor) {
      const destination = readFileSync(resolved, 'utf8');
      const headings = [...destination.matchAll(/^#{1,6}\s+(.+)$/gm)].map((heading) => slug(heading[1]));
      assert.ok(headings.includes(anchor) || destination.includes(`id="${anchor}"`), `${relative}: broken anchor ${target}`);
    }
  }
}

// Phase 00 must not modify any pre-existing application, assertion or workflow.
const protectedChanges = git('diff', '--name-only', base, '--', '.', ':!docs/performance', ':!tests/performance');
assert.equal(protectedChanges, '', `Changes outside Phase 00: ${protectedChanges}`);
assert.deepEqual(sorted(readdirSync(path.join(root, 'tests/performance'))), ['catalog.json', 'validate-foundation.mjs']);
console.log('STATICALLY VALIDATED: 32 frozen plan files / 23 phases; 45 uniquely owned cases; 87 feature routes; 124 operation mappings; source hashes; local links; unchanged application/assertions/workflows.');
console.log('Scenario implementation: NOT_IMPLEMENTED. Execution: NOT_EXECUTED. Thresholds: BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED.');
