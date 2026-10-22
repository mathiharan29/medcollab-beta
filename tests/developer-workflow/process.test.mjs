import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { run, cleanEnvironment } from './process.mjs';

test('cancellation stops the running command and its child before workspace cleanup', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'vocle-cancel-test-'));
  const pidFile = join(directory, 'child.pid');
  const controller = new AbortController();
  const pending = run(process.execPath, ['-e', `
    const child = require('node:child_process').spawn(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], { stdio: 'ignore' });
    require('node:fs').writeFileSync(process.argv[1], String(child.pid));
    setInterval(() => {}, 1000);
  `, pidFile], { signal: controller.signal, timeout: 15000 });
  try {
    let pid;
    for (let n = 0; n < 100; n++) {
      pid = Number(await readFile(pidFile, 'utf8').catch(() => 0));
      if (pid) break;
      await delay(50);
    }
    assert(pid, 'test process must actually spawn a descendant');
    controller.abort();
    const result = await pending;
    assert.equal(result.aborted, true);
    // Some Unix kernels briefly retain a reparented child as a zombie.
    for (let n = 0; n < 40; n++) {
      try { process.kill(pid, 0); } catch { return; }
      if (process.platform === 'linux') {
        const state = await readFile(`/proc/${pid}/stat`, 'utf8').catch(() => '');
        if (/\) Z /.test(state)) return;
      }
      await delay(50);
    }
    assert.fail('cancelled command left its descendant running');
  } finally { controller.abort(); await pending; await rm(directory, { recursive: true, force: true }); }
});

test('timeouts and unavailable commands remain non-success and pre-cancelled commands do not launch', async () => {
  const timeout = await run(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], { timeout: 150 });
  assert.equal(timeout.timedOut, true);
  assert.notEqual(timeout.code, 0);
  const missing = await run('vocle-no-such-executable-12345', []);
  assert(missing.error);
  const controller = new AbortController(); controller.abort();
  assert.equal((await run(process.execPath, ['-e', 'process.exit(0)'], { signal: controller.signal })).aborted, true);
});

test('disposable caches survive environment sanitization without application secrets', () => {
  const original = { ...process.env };
  try {
    process.env.PUB_CACHE = '/disposable/pub'; process.env.NPM_CONFIG_CACHE = '/disposable/npm';
    process.env.PIP_CACHE_DIR = '/disposable/pip';
    process.env.GRADLE_USER_HOME = '/disposable/gradle'; process.env.TMPDIR = '/disposable/tmp';
    process.env.VOCLE_TEST_SECRET = 'not-forwarded';
    const env = cleanEnvironment();
    assert.equal(env.PUB_CACHE, '/disposable/pub');
    assert.equal(env.NPM_CONFIG_CACHE, '/disposable/npm');
    assert.equal(env.PIP_CACHE_DIR, '/disposable/pip');
    assert.equal(env.GRADLE_USER_HOME, '/disposable/gradle');
    assert.equal(env.TMPDIR, '/disposable/tmp');
    assert.equal(env.VOCLE_TEST_SECRET, undefined);
  } finally { process.env = original; }
});
