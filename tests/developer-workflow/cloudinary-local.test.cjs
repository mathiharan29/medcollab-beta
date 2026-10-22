const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const fs = require('node:fs');
const path = require('node:path');
const { configuration, preflight } = require('../../medcollab-backend/scripts/security-cloudinary/guard');

const local = {
  CLOUDINARY_TEST_CLOUD_NAME: 'synthetic-offline-cloud', CLOUDINARY_CLOUD_NAME: 'synthetic-offline-cloud',
  CLOUDINARY_API_KEY: 'offline-key-sentinel', CLOUDINARY_API_SECRET: 'offline-secret-sentinel',
  NODE_ENV: 'test', VOCLE_CLOUDINARY_LIVE: 'isolated-synthetic-only', VOCLE_CLOUDINARY_LOCAL: 'isolated-synthetic-only',
  VOCLE_LOCAL_APPROVED_CLOUD: 'synthetic-offline-cloud', VOCLE_LOCAL_RUN_ID: '12345', VOCLE_LOCAL_SOURCE: 'a'.repeat(40),
  RUNNER_TEMP: os.tmpdir(),
};
const deny = (env, code) => assert.throws(() => configuration(env), error => error.infrastructure && error.code === code);

test('local provider identity requires explicit isolated approval and cannot bypass hosted identity', () => {
  const c = configuration(local);
  assert.equal(c.executionMode, 'local');
  assert.equal(c.source, local.VOCLE_LOCAL_SOURCE);
  for (const key of ['GITHUB_ACTIONS', 'GITHUB_REPOSITORY', 'GITHUB_RUN_ID']) deny({ ...local, [key]: 'hosted' }, 'LOCAL_HOSTED_IDENTITY_DENIED');
  deny({ ...local, VOCLE_LOCAL_APPROVED_CLOUD: 'another-cloud' }, 'LOCAL_CLOUD_APPROVAL_REQUIRED');
  deny({ ...local, VOCLE_LOCAL_SOURCE: 'HEAD' }, 'RUN_IDENTITY_INVALID');
  deny({ ...local, VOCLE_LOCAL_RUN_ID: '../unsafe' }, 'RUN_IDENTITY_INVALID');
  deny({ ...local, VOCLE_CLOUDINARY_LOCAL: 'true' }, 'LOCAL_MODE_INVALID');
  deny({ ...local, HTTPS_PROXY: 'https://proxy.invalid' }, 'FORBIDDEN_ENVIRONMENT');
  deny({ ...local, CLOUDINARY_CLOUD_NAME: 'foreign-cloud' }, 'TEST_CLOUD_MISMATCH');
  deny({ ...local, CLOUDINARY_API_SECRET: '' }, 'CREDENTIALS_MISSING');
});

test('local cleanup journal binds source, run and execution mode without credentials', () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'vocle-cloudinary-guard-'));
  try {
    const env = { ...local, RUNNER_TEMP: scratch };
    const c = preflight(env);
    const safety = fs.readFileSync(path.join(c.out, 'safety.json'), 'utf8');
    for (const secret of [local.CLOUDINARY_CLOUD_NAME, local.CLOUDINARY_API_KEY, local.CLOUDINARY_API_SECRET]) assert.equal(safety.includes(secret), false);
    assert.equal(preflight(env).root, c.root);
    assert.throws(() => preflight({ ...env, VOCLE_LOCAL_SOURCE: 'b'.repeat(40) }), { code: 'JOURNAL_RUN_MISMATCH' });
    const journal = JSON.parse(safety); journal.executionMode = 'hosted';
    fs.writeFileSync(path.join(c.out, 'safety.json'), JSON.stringify(journal));
    assert.throws(() => preflight(env), { code: 'JOURNAL_MODE_MISMATCH' });
  } finally { fs.rmSync(scratch, { recursive: true, force: true }); }
});
