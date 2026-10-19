import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:net';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { backendRoot, outputRoot, repoRoot, runId, targetRoot, validateConfig } from './config.mjs';
import { startMongo, databaseUri } from './db.mjs';
import { startBackend, stopChild } from './runner.mjs';
import { writeReports } from './reporting.mjs';

const sanityRoot = join(repoRoot, 'tests/sanity');
const catalog = JSON.parse(await readFile(join(repoRoot, 'tests/functional-regression/catalog.json'), 'utf8'));
const selectedIds = catalog.cases.filter((item) => item.coverage === 'EXISTING').map((item) => item.id);
const sourceSha = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: targetRoot, encoding: 'utf8' }).stdout.trim();
const harnessSha = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: repoRoot, encoding: 'utf8' }).stdout.trim();

async function requirePort5000() {
  const server = createServer();
  await new Promise((resolve, reject) => server.once('error', reject).listen(5000, '127.0.0.1', resolve));
  await new Promise((resolve) => server.close(resolve));
}

async function executeSanity(outputDirectory, fixtureDirectory, inboxDirectory, uri) {
  const env = {
    PATH: process.env.PATH, Path: process.env.Path, SystemRoot: process.env.SystemRoot, TEMP: process.env.TEMP, TMP: process.env.TMP,
    SANITY_BACKEND_DIR: backendRoot, SANITY_DATABASE_URI: uri, SANITY_ORIGIN: 'http://127.0.0.1:5000',
    SANITY_PROVIDER_INBOX: inboxDirectory, SANITY_FIXTURE_DIR: fixtureDirectory, SANITY_OUTPUT_DIR: outputDirectory,
    SANITY_UPSTREAM_SHA: targetRoot === repoRoot ? '' : sourceSha, SANITY_HARNESS_SHA: harnessSha,
  };
  const child = spawn(process.execPath, [join(sanityRoot, 'src/runner.js'), '--live'], { cwd: sanityRoot, env, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  const chunks = [];
  child.stdout.on('data', (data) => chunks.push(data));
  child.stderr.on('data', (data) => chunks.push(data));
  const exit = await new Promise((resolveExit) => child.once('exit', (code, signal) => resolveExit({ code, signal })));
  await writeFile(join(outputRoot, 'sanity-driver.log'), Buffer.concat(chunks));
  return exit;
}

validateConfig();
await requirePort5000();
const runtime = join(outputRoot, 'runtime', `sanity-${runId}`);
if (!resolve(runtime).startsWith(`${resolve(outputRoot)}${sep}`)) throw new Error('Unsafe runtime path');
await mkdir(runtime, { recursive: true });
const inbox = join(runtime, 'inbox');
const fixture = join(runtime, 'fixture');
const sanityOutput = join(outputRoot, `sanity-original-${runId}`);
await Promise.all([mkdir(inbox), mkdir(fixture), mkdir(sanityOutput, { recursive: true })]);
let mongo, backend, results = [], cleanup = { status: 'ERROR' }, driver;
try {
  mongo = await startMongo(backendRoot, join(outputRoot, 'mongo-binaries'));
  const uri = databaseUri(mongo.uri, 'sanity', runId);
  backend = await startBackend(uri, 5000, runtime, inbox);
  driver = await executeSanity(sanityOutput, fixture, inbox, uri);
  const original = JSON.parse(await readFile(join(sanityOutput, 'sanity-report.json'), 'utf8'));
  results = original.scenarios.map((item) => ({
    id: item.id, module: item.id.replace(/-\d{2}$/, ''),
    status: ({ passed: 'PASS', failed: 'FAIL', blocked: 'BLOCKED' })[item.status] || 'ERROR',
    errorCategory: item.status === 'failed' ? 'APPLICATION_ASSERTION' : item.status === 'blocked' ? 'DEPENDENCY' : undefined,
    error: item.error, durationMs: item.durationMs,
  }));
} catch (error) {
  results = [{ id: 'sanity-adapter-setup', module: 'HARNESS', status: 'ERROR', errorCategory: 'SETUP', error: error.message }];
} finally {
  try {
    await stopChild(backend?.child);
    if (backend) await writeFile(join(outputRoot, 'sanity-backend.log'), backend.logs());
    if (mongo) await mongo.server.stop();
    await rm(runtime, { recursive: true, force: true });
    cleanup = { status: 'PASS', backendStopped: Boolean(backend), mongoStopped: Boolean(mongo), runtimeRemoved: true };
  } catch (error) { cleanup = { status: 'ERROR', error: error.message }; }
}
const report = await writeReports(join(outputRoot, `sanity-adapted-${runId}`), {
  scope: 'retained-sanity-48', targetSha: sourceSha, harnessSha, selectedIds, results, cleanup,
  provenance: { status: /^[a-f0-9]{40}$/.test(sourceSha) && /^[a-f0-9]{40}$/.test(harnessSha) ? 'PASS' : 'ERROR', sourceKind: targetRoot === repoRoot ? 'local-fork-checkout' : 'detached-target', targetSha: sourceSha, harnessSha, originalRunnerExit: driver },
});
console.log(JSON.stringify({ reportDirectory: join(outputRoot, `sanity-adapted-${runId}`), tally: report.tally, complete: report.complete, success: report.success }, null, 2));
if (!report.success) process.exitCode = 1;
