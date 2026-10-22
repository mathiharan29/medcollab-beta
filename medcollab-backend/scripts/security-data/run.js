'use strict';
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto'), { fork } = require('node:child_process');
const guard = require('../security-media/guard');
const { cases, manifest } = require('./cases');
const fixtures = require('./fixtures');
function fingerprint() {
  const root = path.resolve(__dirname, '../../src');
  const walk = p => fs.readdirSync(p, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap(e => e.isDirectory() ? walk(path.join(p, e.name)) : [path.join(p, e.name)]);
  return createHash('sha256').update(walk(root).map(p => path.relative(root, p).replace(/\\/g, '/') + ':' + createHash('sha256').update(fs.readFileSync(p)).digest('hex')).join('\n')).digest('hex');
}
async function main() {
  const results = [], applicationFailures = []; let stage = 'preflight', fatal = null, child, mongoose, scratch, telemetry, isolation, sourceBefore, sourceAfter;
  const dir = path.join(process.env.RUNNER_TEMP || os.tmpdir(), 'vocle-data-results');
  const stop = async () => {
    if (!child || child.exitCode !== null || child.signalCode) return;
    const done = new Promise(resolve => child.once('exit', resolve)); child.kill('SIGTERM');
    await Promise.race([done, new Promise(resolve => setTimeout(resolve, 3000))]);
    if (child.exitCode === null && !child.signalCode) { child.kill('SIGKILL'); await Promise.race([done, new Promise(resolve => setTimeout(resolve, 3000))]); }
    assert.ok(child.exitCode !== null || child.signalCode, 'Unconfirmed backend termination');
  };
  const backendSafety = () => new Promise((resolve, reject) => {
    const listener = message => { if (message.id !== 1) return; clearTimeout(timer); child.off('message', listener); message.failure ? reject(new Error('Backend safety failure')) : resolve(message.safety); };
    const timer = setTimeout(() => { child.off('message', listener); reject(new Error('Safety IPC timeout')); }, 5000);
    child.on('message', listener); child.send({ id: 1, action: 'state' });
  });
  try {
    guard.environment(); isolation = guard.isolatedLinux(); telemetry = guard.network(); sourceBefore = fingerprint();
    scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'vocle-data-scratch-')); fs.mkdirSync(path.join(scratch, 'uploads'));
    process.chdir(scratch);
    stage = 'connect disposable MongoDB';
    mongoose = require('mongoose'); await mongoose.connect(guard.URI, { serverSelectionTimeoutMS: 10000 });
    assert.equal(mongoose.connection.name, 'vocle_ci');
    // Expiry tests must not race the TTL background monitor. This disposable
    // server disables only physical sweeping; actual TTL indexes and application
    // expiry checks remain real. Never apply this option to a deployed database.
    stage = 'verify disposable TTL monitor';
    const ttl = await mongoose.connection.db.admin().command({ getParameter: 1, ttlMonitorEnabled: 1 });
    assert.equal(ttl.ttlMonitorEnabled, false, 'Disposable TTL sweep must be paused');
    isolation.ttlMonitorEnabled = ttl.ttlMonitorEnabled;
    const models = fixtures.models();
    applicationFailures.push(...await fixtures.initializeIndexes(models, value => { stage = value; }));
    if (applicationFailures.length) process.exitCode = 1;
    stage = 'start isolated backend';
    child = fork(path.resolve(__dirname, '../security-media/server.js'), [], { cwd: scratch, env: { NODE_ENV: 'test', MONGODB_URI: guard.URI, API_BASE_URL: guard.BASE, PORT: '5000', JWT_SECRET: guard.JWT, JWT_REFRESH_SECRET: 'ci-test-only-refresh-secret-not-for-production-000000000002', OTP_BYPASS: 'false', VOCLE_MEDIA_MODE: 'local' }, stdio: ['ignore', 'pipe', 'pipe', 'ipc'] });
    child.stdout.resume(); child.stderr.resume();
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Backend readiness timeout')), 15000);
      child.once('message', message => { clearTimeout(timer); message.ready && message.sdkReplaced ? resolve() : reject(new Error('Backend readiness invalid')); });
      child.once('error', () => { clearTimeout(timer); reject(new Error('Backend spawn failure')); });
      child.once('exit', () => { clearTimeout(timer); reject(new Error('Backend exited')); });
    });
    for (const test of cases) {
      stage = `${test.caseId} fixture`; let tokens = {};
      const api = async (actor, method, endpoint, body) => {
        assert.ok(endpoint.startsWith('/api/'));
        const r = await fetch(guard.BASE + endpoint, { method, redirect: 'error', signal: AbortSignal.timeout(12000), headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokens[actor]}` }, body: body === undefined ? undefined : JSON.stringify(body) });
        assert.notEqual(r.status, 429, 'Limiter prevented execution');
        return { status: r.status, data: await r.json() };
      };
      const c = await fixtures.context(models, api);
      try {
        await c.seed();
        for (const actor of ['A', 'B', 'C']) tokens[actor] = require('jsonwebtoken').sign({ userId: String(c[actor]._id) }, guard.JWT, { expiresIn: '1h' });
        assert.equal((await api('A', 'GET', '/api/users/me')).status, 200);
        stage = `${test.caseId} action`;
        let result, failure;
        try { result = await test.run(c); }
        catch (error) {
          const missingApplicationMethod = error instanceof TypeError && /Channel\.directMemberKey is not a function/.test(error.message);
          if (!(error instanceof assert.AssertionError) && !missingApplicationMethod) throw error;
          // The case's original assertion remains unchanged and failing. Keep
          // the gate red, but do not abort independent cases as infrastructure.
          failure = { status: 'FAIL', errorType: error.name, executed: true,
            actual: error instanceof assert.AssertionError ? { assertionFailed: true,
              actual: typeof error.actual === 'number' || typeof error.actual === 'boolean' ? error.actual : 'See case assertion',
              expected: typeof error.expected === 'number' || typeof error.expected === 'boolean' ? error.expected : test.expected }
              : { missingApplicationMethod: 'Channel.directMemberKey' } };
          process.exitCode = 1;
        }
        if (!failure) { assert.equal(typeof result.secure, 'boolean'); assert.ok(result.evidence); }
        const safety = await backendSafety(); assert.equal(telemetry.blocked, 0); assert.equal(safety.network.blocked, 0);
        results.push({ ...manifest.cases.find(x => x.caseId === test.caseId), ...(failure || { passed: result.secure, actual: result.evidence }), safety });
      } finally {
        stage = `${test.caseId} cleanup`;
        const cleanup = await c.cleanup(); if (results.at(-1)?.caseId === test.caseId) results.at(-1).cleanup = cleanup;
        tokens = {};
      }
      console.log(`${test.caseId}: ${results.at(-1).status || (results.at(-1).passed ? 'PASS' : 'OBSERVATION')}`);
    }
    sourceAfter = fingerprint(); assert.equal(sourceBefore, sourceAfter);
  } catch (error) {
    // Mongo error codes and controlled stage names identify setup failures
    // without publishing documents, index values, credentials or child logs.
    fatal = { stage, errorType: error.name, errorCode: Number.isInteger(error.code) ? error.code : null,
      errorCodeName: /^[A-Za-z]+$/.test(error.codeName || '') ? error.codeName : null,
      category: 'prerequisite/execution/safety failure' }; process.exitCode = 1;
    console.error(JSON.stringify(fatal));
  } finally {
    try { await stop(); if (mongoose) await mongoose.disconnect(); if (scratch) { guard.contained(scratch, path.join(scratch, 'uploads')); assert.equal(fs.readdirSync(path.join(scratch, 'uploads')).length, 0); fs.rmdirSync(path.join(scratch, 'uploads')); fs.rmdirSync(scratch); } }
    catch { fatal ||= { stage: 'final cleanup', category: 'unconfirmed cleanup' }; process.exitCode = 1; }
    fs.mkdirSync(dir, { recursive: true });
    const report = { planned: cases.length, executed: results.length, passed: results.filter(r => r.passed === true).length, observations: results.filter(r => r.passed === false).length, failed: results.filter(r => r.status === 'FAIL').length, applicationFailures, notExecuted: cases.length - results.length, combinedCatalogCount: manifest.combinedCatalogCount, infrastructureFailure: fatal, sourceBefore, sourceAfter, isolation, parentNetwork: telemetry, provenance: { runId: process.env.GITHUB_RUN_ID || null, source: process.env.VOCLE_SOURCE_SHA || null }, results };
    fs.writeFileSync(path.join(dir, 'results.json'), JSON.stringify(report, null, 2) + '\n');
    fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
    fs.writeFileSync(path.join(dir, 'summary.md'), `# Vocle MongoDB/data security\n\n${report.executed}/${report.planned} executed; ${report.passed} passes; ${report.observations} observations; ${report.failed} assertion failures; infrastructure ${fatal ? 'FAILED' : 'healthy'}.\n\nNo production connections or provider calls. App observations do not block CI; assertion failures and application index conflicts do. Model/handler probes are labeled separately from real HTTP.\n\n` + applicationFailures.map(r => `- FAIL ${r.category}: ${r.model}; MongoDB ${r.errorCode}; ${r.actual}`).join('\n') + '\n' + results.map(r => `- ${r.caseId}: ${r.name} — ${r.status || (r.passed ? 'PASS' : 'OBSERVATION')} (${r.scope})`).join('\n') + '\n');
    console.log(`Data security: ${report.executed}/${report.planned}; ${report.passed} passes; ${report.observations} observations; infrastructure ${fatal ? 'FAILED' : 'healthy'}`);
  }
}
main();
