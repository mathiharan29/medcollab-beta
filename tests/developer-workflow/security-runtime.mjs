// Executes existing security assertions in a network-none Linux container only.
import { createRequire } from 'node:module';
import { readdir, readFile, writeFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { run } from './process.mjs';
const backend = '/target/medcollab-backend';
if (process.platform !== 'linux' || JSON.stringify((await readdir('/sys/class/net')).sort()) !== '["lo"]') throw new Error('Linux network-none runtime required');
const require = createRequire(join(backend, 'package.json'));
const { MongoMemoryServer } = require('mongodb-memory-server');
const env = { PATH: process.env.PATH, HOME: '/tmp', NODE_ENV: 'test', PORT: '5000', MONGODB_URI: 'mongodb://127.0.0.1:27017/vocle_ci', API_BASE_URL: 'http://127.0.0.1:5000', JWT_SECRET: 'ci-test-only-jwt-secret-not-for-production-0000000000000001', JWT_REFRESH_SECRET: 'ci-test-only-refresh-secret-not-for-production-000000000002', RUNNER_TEMP: '/output', VOCLE_MEDIA_NETWORK_NONE: 'true', OTP_BYPASS: 'true' };
process.env.MONGOMS_DOWNLOAD_DIR = '/output/mongo-binaries';
process.env.MONGOMS_RUNTIME_DOWNLOAD = 'false';
let mongo, app;
const attempts = [];
const startMongo = (pauseTTL = false) => MongoMemoryServer.create({ instance: { ip: '127.0.0.1', port: 27017, args: pauseTTL ? ['--setParameter', 'ttlMonitorEnabled=false'] : [] } });
const authEnvironment = '/tmp/vocle-auth-environment';
try {
  for (const suite of ['security-media', 'security-data']) {
    // Hosted jobs start separate empty disposable databases. Match that
    // lifecycle; media fixtures must never enter the data suite's preflight.
    mongo = await startMongo(suite === 'security-data');
    try {
      attempts.push(await run(process.execPath, [join(backend, 'scripts', suite, 'run.js')], { cwd: backend, env, timeout: 15 * 60 * 1000, log: '/output/' + suite + '.log' }));
      if (suite === 'security-data') attempts.push(await run(process.execPath, [join(backend, 'scripts', suite, 'check.js'), '--artifacts'], { cwd: backend, env, timeout: 60000, log: '/output/' + suite + '-artifact-hygiene.log' }));
    } finally { await mongo.stop(); mongo = null; }
  }
  // Exact fixture/auth/discovery sequence from the existing hosted workflow.
  mongo = await startMongo();
  // Original discovery reads uploaded fixture bytes relative to its cwd. Both
  // processes share the original backend cwd and a dedicated writable uploads
  // tmpfs; application sources remain mounted read-only.
  app = spawn(process.execPath, [join(backend, 'src/server.js')], { cwd: backend, env, stdio: 'ignore' });
  const deadline = Date.now() + 30000;
  let ready = false;
  while (Date.now() < deadline) {
    try { if ((await fetch('http://127.0.0.1:5000/health')).ok) { ready = true; break; } } catch { /* startup */ }
    await new Promise(r => setTimeout(r, 200));
  }
  if (!ready) throw new Error('Discovery backend health timeout');
  for (const [script, args] of [['security-test-fixtures.js', []], ['security-test-fixtures.js', ['--verify']], ['security-test-auth-smoke.js', []], ['security-api-discovery.js', []], ['security-api-coverage-report.js', []]]) {
    const childEnv = script === 'security-test-auth-smoke.js' ? { ...env, GITHUB_ENV: authEnvironment } : env;
    const result = await run(process.execPath, [join(backend, 'scripts', script), ...args], { cwd: backend, env: childEnv, timeout: 15 * 60 * 1000, log: '/output/' + script + (args.length ? '-verify' : '') + '.log' });
    attempts.push(result);
    if (result.code !== 0 && script !== 'security-api-discovery.js') throw new Error('Existing security prerequisite failed: ' + script);
    if (script === 'security-test-auth-smoke.js') {
      // Reuse the original workflow's environment-file protocol. The file lives
      // only in this container's private tmpfs and is never exported as evidence.
      const lines = (await readFile(authEnvironment, 'utf8')).trim().split(/\r?\n/);
      await rm(authEnvironment);
      if (lines.length !== 8) throw new Error('Expected eight original synthetic authentication identities');
      for (const line of lines) {
        const match = /^(VOCLE_TEST_USER_[A-H]_TOKEN)=([^\r\n]+)$/.exec(line);
        if (!match || env[match[1]]) throw new Error('Invalid original authentication environment export');
        env[match[1]] = match[2];
      }
    }
  }
} finally {
  if (app && app.exitCode === null) { app.kill('SIGTERM'); await new Promise(r => app.once('exit', r)); }
  await mongo?.stop();
  await rm(authEnvironment, { force: true });
  for (const key of Object.keys(env)) if (/^VOCLE_TEST_.*_TOKEN$/.test(key)) delete env[key];
  await writeFile('/output/security-execution.json', JSON.stringify({ attempts: attempts.map(({ code, timedOut, error }) => ({ code, timedOut, error })), cleanup: 'PASS' }, null, 2));
}
if (!attempts.length || attempts.some(r => r.code !== 0 || r.timedOut)) process.exitCode = 1;
