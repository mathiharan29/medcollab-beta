'use strict';
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const BASE = 'http://127.0.0.1:5102';
module.exports = async function localSupervisor(c, mode = 'socket', devTools = false) {
  assert.equal(process.env.NODE_ENV, 'test');
  assert.equal(process.env.MONGODB_URI, 'mongodb://127.0.0.1:27017/vocle_ci');
  assert.ok(['socket', 'production-routes'].includes(mode));
  const cwd = path.resolve(__dirname, '../..');
  assert.ok(!fs.existsSync(path.join(cwd, '.env')), 'Supervisor requires absence of a dotenv credential file');
  const env = { ...process.env, NODE_ENV: mode === 'socket' ? 'test' : 'production', PORT: '5102', API_BASE_URL: BASE,
    MONGODB_URI: 'mongodb://127.0.0.1:27017/vocle_ci', OTP_BYPASS: 'false', ENABLE_DEV_TOOLS: String(devTools),
    VOCLE_SECURITY_CONFIGURATION_PROBE: 'disposable-local-only',
    CLOUDINARY_CLOUD_NAME: '', CLOUDINARY_API_KEY: '', CLOUDINARY_API_SECRET: '', MSG91_AUTH_KEY: '', MSG91_TEMPLATE_ID: '',
    FIREBASE_PROJECT_ID: '', FIREBASE_CLIENT_EMAIL: '', FIREBASE_PRIVATE_KEY: '' };
  const child = spawn(process.execPath, [mode === 'socket' ? 'src/server.js' : 'scripts/security/configuration-server.js'], { cwd, env, stdio: ['ignore', 'pipe', 'pipe'] });
  const diagnostics = { uncaughtExceptions: 0, unhandledRejections: 0 };
  // Only retain diagnostic categories, never log text or payloads/credentials.
  const retain = chunk => { const text = chunk.toString(); diagnostics.uncaughtExceptions += (text.match(/Uncaught Exception:/g) || []).length; diagnostics.unhandledRejections += (text.match(/Unhandled Promise Rejection:/g) || []).length; };
  child.stdout.on('data', retain); child.stderr.on('data', retain);
  let spawnError = false; child.on('error', () => { spawnError = true; });
  const api = { base: BASE, child, diagnostics,
    http: async (actor, method, endpoint, body, header) => {
      const url = new URL(endpoint, BASE); assert.equal(url.origin, BASE);
      assert.ok(endpoint.startsWith('/api/') || endpoint === '/health');
      const headers = { 'Content-Type': 'application/json' };
      if (actor !== 'anonymous') headers.Authorization = `Bearer ${c.tokens[actor]}`;
      if (header) headers.Authorization = header;
      const response = await fetch(url, { method, headers, body: body === undefined ? undefined : JSON.stringify(body), redirect: 'error', signal: AbortSignal.timeout(5000) });
      return { status: response.status, data: await response.json() };
    },
    stop: async () => {
      if (child.exitCode !== null || child.signalCode || spawnError) return;
      const exited = new Promise(resolve => child.once('exit', resolve)); child.kill('SIGTERM');
      await Promise.race([exited, wait(1500)]);
      if (child.exitCode === null && !child.signalCode) { child.kill('SIGKILL'); await Promise.race([exited, wait(3000)]); }
      assert.ok(child.exitCode !== null || child.signalCode, 'Supervisor termination unconfirmed');
    },
  };
  c.cleanup.push(api.stop);
  for (let i = 0; i < 50; i++) {
    assert.ok(!spawnError && child.exitCode === null, 'Supervisor exited before readiness');
    try { const r = await api.http('anonymous', 'GET', '/health');
      if (r.status === 200 && r.data.database === 'connected' && r.data.environment === env.NODE_ENV && r.data.firebase === false && r.data.cloudinary === false) return api;
    } catch { /* bounded retry on exact local port */ }
    await wait(100);
  }
  throw new Error('Supervisor readiness/safety control failed');
};
