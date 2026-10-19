'use strict';
const fs = require('node:fs'); const path = require('node:path'); const os = require('node:os');
const assert = require('node:assert/strict'); const { fork } = require('node:child_process'); const { createHash } = require('node:crypto');
const guard = require('./guard'); const fixtures = require('./fixtures'); const h = require('./helpers');
const { catalog, manifest } = require('./catalog'); const data = catalog();
if (process.argv.includes('--list')) { console.log(JSON.stringify(manifest(data), null, 2)); } else { main(); }
async function main() {
  const results = []; let fatal = null, stage = 'safety preflight', mongoose, child, scratch, telemetry, isolation;
  const directory = path.join(process.env.RUNNER_TEMP || os.tmpdir(), 'vocle-media-results');
  let sequence = 0;
  const rpc = (action, value) => new Promise((resolve, reject) => {
    const id = ++sequence; const timer = setTimeout(() => { child.off('message', listener); reject(new Error('IPC timeout')); }, 5000);
    const listener = message => { if (message.id !== id) return; clearTimeout(timer); child.off('message', listener); message.failure ? reject(new Error('Backend safety invariant failed')) : resolve(message); };
    child.on('message', listener); child.send({ id, action, value });
  });
  const stop = async () => {
    if (!child) return;
    if (child.exitCode === null && !child.signalCode) {
      const exited = new Promise(resolve => child.once('exit', resolve)); child.kill('SIGTERM');
      await Promise.race([exited, new Promise(resolve => setTimeout(resolve, 3000))]);
      if (child.exitCode === null && !child.signalCode) { child.kill('SIGKILL'); await Promise.race([exited, new Promise(resolve => setTimeout(resolve, 3000))]); }
    }
    assert.ok(child.exitCode !== null || child.signalCode, 'Backend termination unconfirmed'); child = null;
  };
  const start = async mode => {
    child = fork(path.resolve(__dirname, 'server.js'), [], { cwd: scratch, env: { NODE_ENV: 'test', MONGODB_URI: guard.URI, API_BASE_URL: guard.BASE, PORT: '5000', JWT_SECRET: guard.JWT, JWT_REFRESH_SECRET: 'ci-test-only-refresh-secret-not-for-production-000000000002', OTP_BYPASS: 'true', VOCLE_MEDIA_MODE: mode, ALLOWED_ORIGINS: 'http://localhost:3000' }, stdio: ['ignore', 'pipe', 'pipe', 'ipc'] });
    // Discard backend logs: raw error messages/response bodies are not artifacts.
    child.stdout.resume(); child.stderr.resume();
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Backend readiness timeout')), 15000);
      child.once('error', () => { clearTimeout(timer); reject(new Error('Backend spawn failed')); });
      child.once('exit', () => { clearTimeout(timer); reject(new Error('Backend exited before readiness')); });
      child.once('message', message => { clearTimeout(timer); message.ready && message.sdkReplaced ? resolve() : reject(new Error('SDK replacement not ready')); });
    });
  };
  const http = (tokens) => async (actor, method, endpoint, body, header) => {
    assert.ok(endpoint.startsWith('/api/') || endpoint === '/health');
    const headers = { 'Content-Type': 'application/json' };
    if (actor !== 'anonymous') headers.Authorization = header || `Bearer ${tokens[actor]}`;
    const response = await fetch(guard.BASE + endpoint, { method, headers, body: body === undefined ? undefined : JSON.stringify(body), redirect: 'error', signal: AbortSignal.timeout(12000) });
    assert.notEqual(response.status, 429, 'Limiter prevented scenario execution');
    return { status: response.status, data: await response.json() };
  };
  const sourceFingerprint = () => {
    const root = path.resolve(__dirname, '../../src');
    const walk = p => fs.readdirSync(p, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap(e => e.isDirectory() ? walk(path.join(p, e.name)) : [path.join(p, e.name)]);
    return createHash('sha256').update(walk(root).map(p => path.relative(root, p).replace(/\\/g, '/') + ':' + h.hash(fs.readFileSync(p))).join('\n')).digest('hex');
  };
  let sourceBefore, sourceAfter;
  try {
    guard.environment(); isolation = guard.isolatedLinux(); telemetry = guard.network();
    assert.ok(fs.existsSync(h.videoPath) && h.video.length > 100, 'Authored MP4 fixture required');
    sourceBefore = sourceFingerprint();
    scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'vocle-media-scratch-')); fs.mkdirSync(path.join(scratch, 'uploads'));
    process.chdir(scratch);
    mongoose = require('mongoose'); await mongoose.connect(guard.URI, { serverSelectionTimeoutMS: 10000 });
    const models = fixtures.load();
    for (const test of data.cases) {
      stage = `${test.caseId} fixture/startup`; const users = await fixtures.reset(models); await start(test.mode);
      const tokens = {}, api = http(tokens);
      // Real test-only OTP HTTP authentication; tokens never leave memory/log.
      for (const actor of ['A', 'B', 'C', 'U']) {
        const auth = await api('anonymous', 'POST', '/api/auth/verify-otp', { phone: users[actor].phone, otp: '123456' });
        assert.equal(auth.status, 200); assert.equal(auth.data.data.user._id, String(users[actor]._id)); tokens[actor] = auth.data.data.accessToken;
        assert.equal((await api(actor, 'GET', '/api/users/me')).status, 200);
      }
      const jwt = require('jsonwebtoken'); tokens.I = jwt.sign({ userId: String(users.I._id) }, guard.JWT, { expiresIn: '1h' });
      const c = { mode: test.mode, users, models, ids: fixtures.ids, tokens, http: api, evidence: {}, cleanup: [],
        expiredHeader: 'Bearer ' + jwt.sign({ userId: String(users.A._id) }, guard.JWT, { expiresIn: -60 }),
        invalidHeader: `Bearer ${tokens.A.slice(0, -8)}AAAAAAAA`, state: async () => (await rpc('state')).state, fault: value => rpc('fault', value) };
      const health = await api('anonymous', 'GET', '/health'); assert.equal(health.status, 200); assert.equal(health.data.database, 'connected'); assert.equal(health.data.firebase, false); assert.equal(health.data.cloudinary, test.mode === 'contract');
      let cleanupDone = false;
      try {
        if (test.prepare) await test.prepare(c);
        const before = await fixtures.settled(models), filesBefore = h.files();
        stage = `${test.caseId} action`;
        const body = typeof test.body === 'function' ? await test.body(c) : test.body;
        const endpoint = typeof test.endpoint === 'function' ? test.endpoint(c) : test.endpoint;
        const response = test.run ? await test.run(c) : await api(test.actor, test.method, endpoint, body);
        const after = await fixtures.settled(models); const state = await rpc('state'); c.sdkState = state.state;
        const filesAfter = h.files();
        const semantic = test.check ? !!(await test.check(response.data, c, response)) : true;
        const denial = test.statuses.every(s => s >= 400), unchanged = before === after;
        const passed = test.statuses.includes(response.status) && response.data.success === !denial && semantic && (!denial || (unchanged && response.data.data == null));
        assert.equal((await api('anonymous', 'GET', '/health')).status, 200);
        results.push({ caseId: test.caseId, name: test.name, actor: test.actor, endpoint, method: test.method, module: test.module, mode: test.mode, legacy: test.legacy,
          expected: { statuses: test.statuses, semanticCheck: !!test.check, deniedWritesMustPreserveDatabase: denial },
          actual: { status: response.status, success: response.data.success, stateUnchanged: unchanged, semanticCheckPassed: semantic, evidence: c.evidence, filesBefore, filesAfter, sdkCalls: c.sdkState.calls, simulatedAssets: c.sdkState.assets, safety: state.safety },
          sources: test.sources, passed, classification: passed ? 'confirmed expected behavior' : test.failureClassification || 'application observation requiring review' });
        if (test.mode === 'local') assert.equal(c.sdkState.calls.length, 0, 'Local fallback called SDK');
      } finally {
        stage = `${test.caseId} cleanup`;
        for (const clean of c.cleanup.reverse()) await clean();
        await fixtures.settled(models); await stop();
        for (const item of h.files()) fs.unlinkSync(h.file(item.id));
        assert.equal(h.files().length, 0); cleanupDone = true;
        if (results.at(-1)?.caseId === test.caseId) results.at(-1).cleanup = { filesRemoved: true, backendStopped: true, simulatedStateDiscarded: true };
      }
      assert.ok(cleanupDone); console.log(`${test.caseId}: ${results.at(-1).passed ? 'PASS' : 'OBSERVATION'}`);
    }
    sourceAfter = sourceFingerprint(); assert.equal(sourceAfter, sourceBefore); assert.equal(telemetry.blocked, 0);
  } catch (error) {
    fatal = { stage, category: error.code === 'MEDIA_NETWORK_BLOCKED' ? 'blocked network attempt' : 'fixture/transport/assertion prerequisite', errorType: error.name || 'Error' };
    // Only controlled stage/category/name; no assertion values, bodies or secrets.
    console.error(JSON.stringify(fatal)); process.exitCode = 1;
  } finally {
    try { await stop(); if (mongoose) await mongoose.disconnect(); } catch { fatal = { stage: 'final process cleanup', category: 'cleanup failure' }; process.exitCode = 1; }
    if (scratch && fs.existsSync(scratch)) {
      try { const uploadRoot = path.join(scratch, 'uploads'); guard.contained(scratch, uploadRoot); assert.ok(fs.readdirSync(uploadRoot, { recursive: true }).every(p => fs.statSync(path.join(uploadRoot, p)).isDirectory()), 'Unexpected residue after case cleanup'); fs.rmSync(uploadRoot, { recursive: true }); fs.rmdirSync(scratch); } catch { fatal ||= { stage: 'final scratch cleanup', category: 'unremoved residue' }; process.exitCode = 1; }
    }
    fs.mkdirSync(directory, { recursive: true });
    const observations = results.filter(r => !r.passed);
    const moduleBreakdown = Object.fromEntries([...new Set(results.map(r => r.module))].map(m => [m, { executed: results.filter(r => r.module === m).length, passed: results.filter(r => r.module === m && r.passed).length, observations: results.filter(r => r.module === m && !r.passed).length }]));
    const report = { planned: data.cases.length, executed: results.length, passed: results.length - observations.length, unexpected: observations.length, notExecuted: data.cases.length - results.length, combinedCatalogCount: data.count, baselineCount: 691, infrastructureFailure: fatal, isolation, parentNetwork: telemetry, sourceBefore, sourceAfter, moduleBreakdown, results };
    fs.writeFileSync(path.join(directory, 'results.json'), JSON.stringify(report, null, 2) + '\n');
    if (fs.existsSync(h.videoPath)) fs.copyFileSync(h.videoPath, path.join(directory, 'synthetic-fixture.mp4'));
    const summary = ['# Vocle media storage and offline Cloudinary contracts', '', `Executed ${report.executed}/${report.planned}; passes ${report.passed}; observations ${report.unexpected}; infrastructure ${fatal ? 'FAILED' : 'healthy'}.`, '', 'The 691-case baseline is preserved; this dedicated run executes selected existing media cases plus new append-only cases. It does not re-execute the general API suite.', '', 'No real SDK, credentials or provider requests. SDK output/asset state is simulated; only call intent and local application behavior are measured.', '', '| Module | Executed | Pass | Observation |', '| --- | --- | --- | --- |', ...Object.entries(moduleBreakdown).map(([m, n]) => `| ${m} | ${n.executed} | ${n.passed} | ${n.observations} |`), '', ...observations.map(r => `- ${r.caseId}: ${r.name}; expected ${r.expected.statuses.join('/')}, actual ${r.actual.status}; ${r.classification}.`), ''].join('\n');
    fs.writeFileSync(path.join(directory, 'summary.md'), summary);
    fs.writeFileSync(path.join(directory, 'security-test-report.md'), summary + results.map(r => `\n## ${r.caseId} — ${r.name}\n\n${r.passed ? 'PASS' : 'OBSERVATION'}; expected HTTP ${r.expected.statuses.join('/')}, actual ${r.actual.status}; semantic ${r.actual.semanticCheckPassed}; database unchanged ${r.actual.stateUnchanged}.\n\nSources: ${r.sources.join(', ')}.\n\nEvidence: \`${JSON.stringify(r.actual.evidence)}\`\n\nSDK calls (simulated boundary): \`${JSON.stringify(r.actual.sdkCalls)}\`\n`).join(''));
    fs.writeFileSync(path.join(directory, 'manifest.json'), JSON.stringify(manifest(data), null, 2) + '\n');
    console.log(`Media: ${report.executed}/${report.planned}, ${report.passed} passes, ${report.unexpected} observations; infrastructure ${fatal ? 'FAILED' : 'healthy'}`);
  }
}
