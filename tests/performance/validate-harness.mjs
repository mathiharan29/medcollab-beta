// Static inspection only: never import or invoke lib/, application or workloads.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
const read = (filename) => readFileSync(path.join(root, filename), 'utf8');
const json = (filename) => JSON.parse(read(filename));
const pkg = json('package.json');
const lock = json('package-lock.json');
assert.equal(pkg.private, true);
assert.deepEqual(pkg.dependencies, { artillery: '2.0.34', 'socket.io-client': '4.8.3' });
assert.deepEqual(lock.packages[''].dependencies, pkg.dependencies);
assert.equal(lock.lockfileVersion, 3);
// Future separately authorized installations may exist; inspect JSON only.
const dependenciesPresent = existsSync(path.join(root, 'node_modules'));
for (const [name, entry] of Object.entries(lock.packages)) {
  if (!name) continue;
  assert.match(entry.version, /^\d+\.\d+\.\d+/);
  assert.ok(entry.resolved.startsWith('https://registry.npmjs.org/'));
  assert.match(entry.integrity, /^sha512-[A-Za-z0-9+/]+=*$/);
}
for (const [name, version] of Object.entries(pkg.dependencies)) assert.equal(lock.packages[`node_modules/${name}`].version, version);
if (dependenciesPresent) for (const [name, version] of Object.entries(pkg.dependencies)) assert.equal(json(`node_modules/${name}/package.json`).version, version);
assert.ok(read('.npmrc').includes('ignore-scripts=true'));
assert.deepEqual(Object.keys(pkg.scripts), ['validate:static']);

const libs = ['actors.mjs', 'config.mjs', 'core.mjs', 'index.mjs', 'journal.mjs', 'ledger.mjs', 'metrics.mjs', 'provenance.mjs', 'result.mjs', 'scenario.mjs', 'target.mjs'];
assert.deepEqual(readdirSync(path.join(root, 'lib')).sort(), libs);
for (const file of libs.map((name) => `lib/${name}`).concat(['validate-foundation.mjs', 'validate-harness.mjs'])) {
  execFileSync(process.execPath, ['--check', path.join(root, file)], { stdio: 'pipe' });
  const text = read(file);
  if (!file.startsWith('lib/')) continue;
  assert.ok(!/\b(?:fetch|listen|connect|createConnection|createServer|spawn|execFile|eval)\s*\(/.test(text), `Unexpected execution/traffic primitive: ${file}`);
  assert.ok(!/process\.env|dotenv|console\./.test(text), `Environment/logging leakage: ${file}`);
  for (const match of text.matchAll(/(?:from\s+|import\s+)['"]([^'"]+)['"]/g)) {
    const specifier = match[1];
    assert.ok(specifier.startsWith('node:') || specifier.startsWith('.'), `Unexpected dependency import: ${file}`);
    if (specifier.startsWith('.')) assert.ok(existsSync(path.resolve(root, path.dirname(file), specifier)), `Missing import: ${file} -> ${specifier}`);
  }
}
const policy = json('config/target-policy.json');
assert.deepEqual(policy.targets, []);
assert.deepEqual(policy.trustedKeys, []);
assert.ok(policy.productionHosts.includes('medcollab.up.railway.app'));
const template = json('config/run-template.json');
assert.equal(template.executionAuthorized, false);
assert.equal(template.target.redirects, false);
assert.equal(template.baseline, null);
assert.equal(template.thresholds, null);
assert.ok(Object.values(template.providers).every((provider) => provider.egress === false && provider.budget === 0));
assert.ok(Object.values(template.budgets).filter((value) => typeof value === 'number').every(Number.isFinite));

const keywords = new Set(['$schema', '$id', '$ref', '$defs', 'type', 'additionalProperties', 'properties', 'required', 'enum', 'const', 'minimum', 'maximum', 'minLength', 'maxLength', 'pattern', 'items', 'minItems', 'maxItems', 'uniqueItems', 'anyOf', 'description', 'title']);
function inspectSchema(schema) {
  assert.ok(schema && typeof schema === 'object');
  for (const key of Object.keys(schema)) assert.ok(keywords.has(key), `Unsupported runtime schema keyword: ${key}`);
  if (schema.$ref) assert.ok(schema.$ref.startsWith('#/'));
  if (schema.type === 'object') assert.equal(schema.additionalProperties, false, 'Open-ended report/config object');
  for (const nested of Object.values(schema.properties ?? {})) inspectSchema(nested);
  for (const nested of Object.values(schema.$defs ?? {})) inspectSchema(nested);
  if (schema.items) inspectSchema(schema.items);
  for (const nested of schema.anyOf ?? []) inspectSchema(nested);
}
const schemas = readdirSync(path.join(root, 'schemas')).map((name) => `schemas/${name}`).concat(['reporting/schema.json']);
for (const filename of schemas) inspectSchema(json(filename));
const report = json('reporting/schema.json');
assert.deepEqual(report.properties.ledger, json('schemas/ledger-snapshot.schema.json') && Object.fromEntries(Object.entries(json('schemas/ledger-snapshot.schema.json')).filter(([key]) => key !== '$schema')));
assert.deepEqual(report.properties.metrics, Object.fromEntries(Object.entries(json('schemas/metrics-snapshot.schema.json')).filter(([key]) => key !== '$schema')));
assert.deepEqual(report.properties.provenance.anyOf[0], json('schemas/provenance.schema.json'));
assert.deepEqual(report.properties.configuration, json('schemas/run-config.schema.json'));
const signatures = {
  'config.mjs': ['validateRunConfig(raw)', 'assertValidatedConfig(config)', 'createBudgetGuard(config)'],
  'target.mjs': ['assertIsolatedTarget(config, identityEvidence)', 'assertPinnedDestination(authorization,'],
  'provenance.mjs': ['captureProvenance(inputs)'],
  'actors.mjs': ['allocateActors(seed, profile, workerPartition)'],
  'journal.mjs': ['registerOwnedResource(journal, resource)', 'cleanupOwnedResources(journal, authorization)'],
  'ledger.mjs': ['recordStage: stage', 'recordOutcome(actionId, outcome)'],
  'result.mjs': ['finalizeRun(run, oracleResults, cleanup)'],
  'scenario.mjs': ['defineScenario(definition)'],
};
for (const [file, fragments] of Object.entries(signatures)) for (const fragment of fragments) assert.ok(read(`lib/${file}`).includes(fragment), `Missing interface: ${fragment}`);
assert.ok(read('lib/target.mjs').includes("publicKey.asymmetricKeyType === 'ed25519'"));
assert.ok(read('lib/target.mjs').includes('TARGET_ADDRESS_DRIFT'));
assert.ok(read('lib/journal.mjs').includes('fsyncSync(fd)'));
assert.ok(read('lib/journal.mjs').includes('INDEPENDENT_OWNERSHIP_CHECK_FAILED'));
assert.ok(read('lib/ledger.mjs').includes('SUCCESS_REQUIRES_RECONCILIATION'));
assert.ok(read('lib/result.mjs').includes('INCOMPLETE_REQUIRED_EVIDENCE'));
assert.ok(read('lib/result.mjs').includes('primaryFailures'));
console.log(`STATICALLY VALIDATED: ${libs.length} shared modules, ${schemas.length} schemas, ${Object.keys(lock.packages).length - 1} integrity-pinned dependency entries, denied-by-default policy, interface signatures and local imports.`);
console.log('No harness functions, dependency code, scenario hooks, target adapters or application modules imported/executed. Runtime validation: NOT_EXECUTED.');
console.log(`Installed dependency directory present: ${dependenciesPresent}.`);
