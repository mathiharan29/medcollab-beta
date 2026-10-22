import assert from 'node:assert/strict';
import { createServer } from 'node:net';
import { spawn } from 'node:child_process';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { backendRoot, harnessRoot, outputRoot, runId, targetRoot, validateConfig } from './config.mjs';
import { startMongo, databaseUri, inspectDatabase } from './db.mjs';
import { createHttp, HttpContractError } from './http.mjs';
import { createIdentity } from './fixtures.mjs';
import { writeReports } from './reporting.mjs';

export class InfrastructureError extends Error { constructor(message) { super(message); this.name = 'InfrastructureError'; } }
export class DecisionPending extends Error { constructor(message, verifiedSubassertions = []) { super(message); this.name = 'DecisionPending'; this.verifiedSubassertions = verifiedSubassertions; } }
export class SkipCase extends Error { constructor(message) { super(message); this.name = 'SkipCase'; } }

function withDeadline(action, milliseconds) {
  let timer;
  return Promise.race([Promise.resolve().then(action), new Promise((_, reject) => { timer = setTimeout(() => reject(new InfrastructureError(`Case timed out after ${milliseconds} ms`)), milliseconds); })]).finally(() => clearTimeout(timer));
}

export async function executeCases(cases, context, timeoutMs = 10000) {
  const results = [];
  for (const item of cases) {
    const started = Date.now();
    const result = { id: item.id || null, module: item.module || 'HARNESS', status: 'PASS', durationMs: 0, ...(item.prerequisiteSeed ? { prerequisiteSeed: item.prerequisiteSeed } : {}) };
    const failedDependency = (item.dependencies || []).find((id) => results.find((row) => row.id === id)?.status !== 'PASS');
    if (!item.id) { result.status = 'ERROR'; result.errorCategory = 'INVALID_CASE_ID'; result.error = 'Case ID is required'; }
    else if (failedDependency) { result.status = 'BLOCKED'; result.errorCategory = 'DEPENDENCY'; result.error = `Blocked by ${failedDependency}`; result.dependencyFailureIds = [failedDependency]; }
    else {
      try { await withDeadline(() => item.run(context), item.timeoutMs || timeoutMs); }
      catch (error) {
        result.status = error instanceof InfrastructureError ? 'ERROR' : error instanceof DecisionPending ? 'NEEDS_DECISION' : error instanceof SkipCase ? 'SKIP' : 'FAIL';
        result.errorCategory = error.name || 'ASSERTION';
        result.error = error.message;
        if (error instanceof DecisionPending) result.verifiedSubassertions = error.verifiedSubassertions;
      }
    }
    result.durationMs = Date.now() - started;
    results.push(result);
  }
  return results;
}

async function freePort() {
  const server = createServer();
  await new Promise((resolve, reject) => server.once('error', reject).listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

async function ready(origin, child) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) throw new InfrastructureError(`Backend exited before health: ${child.exitCode}`);
    try { const response = await fetch(`${origin}/health`, { signal: AbortSignal.timeout(1000) }); if (response.ok) return; } catch { /* startup still pending */ }
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new InfrastructureError('Backend health timed out');
}

export async function startBackend(uri, port, runtimeDirectory, inboxDirectory, { providerPreload, extraEnv = {} } = {}) {
  const preload = providerPreload || fileURLToPath(new URL('../providers/preload.cjs', import.meta.url));
  const env = {
    PATH: process.env.PATH, Path: process.env.Path, SystemRoot: process.env.SystemRoot, TEMP: process.env.TEMP, TMP: process.env.TMP,
    NODE_ENV: 'test', TZ: 'UTC', PORT: String(port), MONGODB_URI: uri,
    JWT_SECRET: 'synthetic-access-secret-00000000000000000000000000000001',
    JWT_REFRESH_SECRET: 'synthetic-refresh-secret-00000000000000000000000000000002',
    OTP_BYPASS: 'false', MSG91_AUTH_KEY: 'synthetic-test-key', MSG91_TEMPLATE_ID: 'synthetic-template',
    API_BASE_URL: `http://127.0.0.1:${port}`, ALLOWED_ORIGINS: `http://127.0.0.1:${port}`,
    VOCLE_BACKEND_DIR: backendRoot, VOCLE_PROVIDER_INBOX: inboxDirectory, NODE_OPTIONS: `--require=${preload}`,
    ...extraEnv,
  };
  const child = spawn(process.execPath, [join(backendRoot, 'src/server.js')], { cwd: runtimeDirectory, env, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });
  const chunks = [];
  const logWaiters = new Set();
  const logs = () => Buffer.concat(chunks).toString('utf8');
  const capture = (data) => {
    chunks.push(data);
    const current = logs();
    for (const waiter of logWaiters) if (current.includes(waiter.text)) { clearTimeout(waiter.timer); logWaiters.delete(waiter); waiter.resolve(current); }
  };
  child.stdout.on('data', capture);
  child.stderr.on('data', capture);
  const waitForLog = (text, timeoutMs = 10000) => new Promise((resolve, reject) => {
    if (logs().includes(text)) return resolve(logs());
    const waiter = { text, resolve, timer: null };
    waiter.timer = setTimeout(() => { logWaiters.delete(waiter); reject(new Error(`Backend log did not contain ${JSON.stringify(text)} within ${timeoutMs} ms`)); }, timeoutMs);
    logWaiters.add(waiter);
  });
  try { await ready(`http://127.0.0.1:${port}`, child); return { child, logs, waitForLog }; }
  catch (error) { child.kill(); throw new InfrastructureError(`${error.message}; backend startup output: ${logs().slice(-3000)}`); }
}

export async function stopChild(child) {
  if (!child || child.exitCode !== null) return;
  child.kill('SIGTERM');
  await Promise.race([new Promise((resolve) => child.once('exit', resolve)), new Promise((resolve) => setTimeout(resolve, 5000))]);
  if (child.exitCode === null) child.kill('SIGKILL');
}

async function classificationSelfCheck() {
  const cases = [
    { id: 'classification-pass', run: () => assert.equal(2 + 2, 4) },
    { id: 'classification-fail', run: () => assert.equal(2 + 2, 5) },
    { id: 'classification-app-http-fail', run: () => { throw new HttpContractError('Valid business request returned 500', { status: 500 }); } },
    { id: 'classification-error', run: () => { throw new InfrastructureError('synthetic setup failure'); } },
    { id: 'classification-blocked', dependencies: ['classification-fail'], run: () => { throw new Error('must not execute'); } },
    { id: 'classification-needs-decision', run: () => { throw new DecisionPending('Q1 pending'); } },
    { id: 'classification-skip', run: () => { throw new SkipCase('unselected tier'); } },
    { id: 'classification-timeout', timeoutMs: 10, run: () => new Promise(() => {}) },
    { run: () => {} },
  ];
  const results = await executeCases(cases, {});
  const expected = ['PASS', 'FAIL', 'FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP', 'ERROR', 'ERROR'];
  assert.deepEqual(results.map((item) => item.status), expected);
  assert.deepEqual(results.slice(-2).map((item) => item.errorCategory), ['InfrastructureError', 'INVALID_CASE_ID']);
  const report = await writeReports(join(outputRoot, 'self-check'), { scope: 'classification-self-check', targetSha: null, harnessSha: null, results, cleanup: { status: 'PASS' }, provenance: { status: 'PASS' }, selectedIds: cases.map((item) => item.id || '__missing_id__') });
  assert.equal(report.success, false);
  console.log('Classification contract PASS: distinct non-green statuses and incomplete report');
}

async function smoke() {
  validateConfig();
  const runtimeDirectory = join(outputRoot, 'runtime', runId);
  if (!resolve(runtimeDirectory).startsWith(`${resolve(outputRoot)}${sep}`)) throw new Error('Unsafe runtime directory');
  await mkdir(runtimeDirectory, { recursive: true });
  const inboxDirectory = join(runtimeDirectory, 'inbox');
  await mkdir(inboxDirectory);
  let mongo, backend, results = [], cleanup = { status: 'ERROR' };
  const port = await freePort();
  const origin = `http://127.0.0.1:${port}`;
  try {
    mongo = await startMongo(backendRoot, join(outputRoot, 'mongo-binaries'));
    const uri = databaseUri(mongo.uri, 'smoke', runId);
    backend = await startBackend(uri, port, runtimeDirectory, inboxDirectory);
    const request = createHttp(origin);
    results = await executeCases([{ id: 'harness-smoke', module: 'HARNESS', run: async () => {
      const health = await request('/health');
      assert.equal(health.payload.status, 'ok');
      const identity = await createIdentity(request, inboxDirectory, 'A');
      await inspectDatabase(backendRoot, uri, async (db) => {
        const stored = await db.collection('users').findOne({ phone: identity.phone });
        assert.equal(String(stored?._id), identity.userId);
        assert.equal(stored.name, 'Dr Synthetic A');
      });
    } }], { origin, request, uri }, 30000);
  } catch (error) {
    results = [{ id: 'harness-smoke', module: 'HARNESS', status: 'ERROR', errorCategory: 'SETUP', error: error.message, durationMs: 0 }];
  } finally {
    try {
      await stopChild(backend?.child);
      if (backend) await writeFile(join(outputRoot, 'backend-smoke.log'), backend.logs());
      await mongo?.server.stop();
      await rm(runtimeDirectory, { recursive: true, force: true });
      cleanup = { status: 'PASS', backendStopped: Boolean(backend), mongoStopped: Boolean(mongo), runtimeRemoved: true };
    } catch (error) { cleanup = { status: 'ERROR', error: error.message }; }
  }
  const report = await writeReports(join(outputRoot, 'smoke'), { scope: 'harness-smoke', targetSha: null, harnessSha: null, results, cleanup, provenance: { status: 'PASS', targetRoot, backendRoot, sourceKind: 'local-checkout' }, selectedIds: ['harness-smoke'] });
  console.log(JSON.stringify({ success: report.success, tally: report.tally, cleanup }, null, 2));
  if (!report.success) process.exitCode = 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.includes('--self-check')) await classificationSelfCheck();
  else if (process.argv.includes('--smoke')) await smoke();
  else throw new Error('Use --self-check or --smoke');
}
