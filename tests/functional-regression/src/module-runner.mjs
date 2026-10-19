import { spawnSync } from 'node:child_process';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { join, resolve, sep } from 'node:path';
import { createServer } from 'node:net';
import { backendRoot, outputRoot, repoRoot, runId, targetRoot, validateConfig } from './config.mjs';
import { startMongo, databaseUri, inspectDatabase } from './db.mjs';
import { createHttp } from './http.mjs';
import { createIdentity } from './fixtures.mjs';
import { executeCases, startBackend, stopChild } from './runner.mjs';
import { writeReports } from './reporting.mjs';

const catalog = JSON.parse(await readFile(join(repoRoot, 'tests/functional-regression/catalog.json'), 'utf8'));
const byId = new Map(catalog.cases.map((item) => [item.id, item]));
const gitSha = (directory) => spawnSync('git', ['rev-parse', 'HEAD'], { cwd: directory, encoding: 'utf8' }).stdout.trim();

async function freePort() {
  const server = createServer();
  await new Promise((resolveListen, reject) => server.once('error', reject).listen(0, '127.0.0.1', resolveListen));
  const port = server.address().port;
  await new Promise((resolveClose) => server.close(resolveClose));
  return port;
}

export async function runModule(moduleName, cases) {
  const selectedIds = process.env.VOCLE_CASE_IDS?.split(',').filter(Boolean);
  if (selectedIds) cases = cases.filter((item) => selectedIds.includes(item.id));
  if (cases.length === 0) return null;
  validateConfig();
  if (!/^[a-z][a-z0-9-]*$/.test(moduleName)) throw new Error('Invalid module name');
  for (const item of cases) {
    const row = byId.get(item.id);
    if (!row || row.tier !== 'B' || row.coverage !== 'NEW') throw new Error(`Unregistered new backend case ${item.id}`);
    if (typeof item.run !== 'function') throw new Error(`${item.id} lacks executable assertions`);
  }
  const runtime = join(outputRoot, 'runtime', `${moduleName}-${runId}`);
  if (!resolve(runtime).startsWith(`${resolve(outputRoot)}${sep}`)) throw new Error('Unsafe runtime path');
  const inbox = join(runtime, 'inbox');
  await mkdir(inbox, { recursive: true });
  const port = await freePort();
  const origin = `http://127.0.0.1:${port}`;
  let mongo, backend, results = [], cleanup = { status: 'ERROR' };
  try {
    mongo = await startMongo(backendRoot, join(outputRoot, 'mongo-binaries'), { enableTestCommands: cases.some((item) => item.mongoFailpoint === true), ...(cases.some((item) => item.mongoRestart === true) ? { dbPath: join(runtime, 'mongo-data') } : {}) });
    const uri = databaseUri(mongo.uri, moduleName, runId);
    backend = await startBackend(uri, port, runtime, inbox, { extraEnv: {
      VOCLE_FAKE_FIREBASE: cases.some((item) => item.fakeFirebase === true) ? '1' : '0',
      VOCLE_FAKE_CLOUDINARY: cases.some((item) => item.fakeCloudinary === true) ? '1' : '0',
      VOCLE_FAKE_CLOCK: cases.some((item) => item.fakeClock === true) ? '1' : '0',
    } });
    const request = createHttp(origin);
    const identities = new Map();
    const context = {
      request, uri, origin, inbox, waitForBackendLog: backend.waitForLog,
      identity: async (label) => {
        if (!identities.has(label)) identities.set(label, await createIdentity(request, inbox, label));
        return identities.get(label);
      },
      db: (action) => inspectDatabase(backendRoot, uri, action),
      restartBackend: async () => {
        await stopChild(backend.child);
        backend = await startBackend(uri, port, runtime, inbox, { extraEnv: {
          VOCLE_FAKE_FIREBASE: cases.some((item) => item.fakeFirebase === true) ? '1' : '0',
          VOCLE_FAKE_CLOUDINARY: cases.some((item) => item.fakeCloudinary === true) ? '1' : '0',
          VOCLE_FAKE_CLOCK: cases.some((item) => item.fakeClock === true) ? '1' : '0',
        } });
      },
      pauseMongo: async () => mongo.server.stop({ doCleanup: false, force: false }),
      resumeMongo: async () => {
        const beforePath = mongo.server.instanceInfo?.dbPath;
        await mongo.server.start(true);
        if (mongo.server.getUri() !== mongo.uri) throw new Error('MongoDB resume changed the disposable URI');
        if (mongo.server.instanceInfo?.dbPath !== beforePath) throw new Error('MongoDB resume changed the disposable data path');
      },
    };
    results = await executeCases(cases, context, 30000);
  } catch (error) {
    results = cases.map((item) => ({ id: item.id, module: moduleName, status: 'ERROR', errorCategory: 'SETUP', error: error.message }));
  } finally {
    try {
      await stopChild(backend?.child);
      if (backend) await writeFile(join(outputRoot, `backend-${moduleName}.log`), backend.logs());
      if (mongo) await mongo.server.stop();
      await rm(runtime, { recursive: true, force: true });
      cleanup = { status: 'PASS', backendStopped: Boolean(backend), mongoStopped: Boolean(mongo), runtimeRemoved: true };
    } catch (error) { cleanup = { status: 'ERROR', error: error.message }; }
  }
  const targetSha = gitSha(targetRoot), harnessSha = gitSha(repoRoot);
  const reportDirectory = join(outputRoot, `${moduleName}-${runId}`);
  const report = await writeReports(reportDirectory, {
    scope: `backend-subset-${moduleName}`, targetSha, harnessSha, selectedIds: cases.map((item) => item.id), results, cleanup,
    provenance: { status: /^[a-f0-9]{40}$/.test(targetSha) ? 'PASS' : 'ERROR', sourceKind: targetRoot === repoRoot ? 'local-fork-checkout' : 'detached-target', targetSha, harnessSha },
  });
  console.log(JSON.stringify({ reportDirectory, tally: report.tally, complete: report.complete, subsetSuccess: report.success, backendAllSuccess: false }, null, 2));
  if (!report.success) process.exitCode = 1;
  return report;
}
