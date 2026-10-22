'use strict';
// Entirely offline harness checks; these are not credited as provider testcase executions.
const assert = require('node:assert/strict'); const os = require('node:os');
const { configuration, namespace, installNetwork } = require('./guard'); const { Broker } = require('./broker');
const fake = { CLOUDINARY_TEST_CLOUD_NAME: 'synthetic-offline-cloud', CLOUDINARY_CLOUD_NAME: 'synthetic-offline-cloud', CLOUDINARY_API_KEY: 'offline-key-sentinel', CLOUDINARY_API_SECRET: 'offline-secret-sentinel', NODE_ENV: 'test', VOCLE_CLOUDINARY_LIVE: 'isolated-synthetic-only', GITHUB_REPOSITORY: 'mathiharan29/medcollab-beta', GITHUB_REF: 'refs/heads/master', GITHUB_EVENT_NAME: 'workflow_dispatch', GITHUB_WORKFLOW: 'Vocle Real Cloudinary Security', GITHUB_RUN_ID: '12345', GITHUB_RUN_ATTEMPT: '1', GITHUB_SHA: 'a'.repeat(40), RUNNER_TEMP: os.tmpdir() };
let checks = 0; const denied = (fn, code) => { assert.throws(fn, e => e.infrastructure && e.code === code); checks++; };
async function main() {
  const c = configuration(fake); assert.equal(c.positiveAllowlistMatched, true); checks++;
  for (const [key, value, code] of [
    ['CLOUDINARY_TEST_CLOUD_NAME', '', 'EXPECTED_TEST_CLOUD_MISSING'], ['CLOUDINARY_CLOUD_NAME', 'other-cloud', 'TEST_CLOUD_MISMATCH'], ['CLOUDINARY_API_KEY', '', 'CREDENTIALS_MISSING'], ['CLOUDINARY_API_SECRET', '', 'CREDENTIALS_MISSING'],
    ['NODE_ENV', 'production', 'TEST_MODE_REQUIRED'], ['GITHUB_REPOSITORY', 'unapproved/repository', 'REPOSITORY_REF_EVENT_DENIED'], ['GITHUB_REF', 'refs/heads/other', 'REPOSITORY_REF_EVENT_DENIED'], ['GITHUB_EVENT_NAME', 'push', 'REPOSITORY_REF_EVENT_DENIED'], ['GITHUB_WORKFLOW', 'other', 'WORKFLOW_DENIED'], ['GITHUB_RUN_ID', '../bad', 'RUN_IDENTITY_INVALID'], ['GITHUB_RUN_ATTEMPT', '0', 'RUN_IDENTITY_INVALID'], ['RUNNER_TEMP', 'relative', 'SCRATCH_REQUIRED'],
  ]) denied(() => configuration({ ...fake, [key]: value }), code);
  for (const key of ['CLOUDINARY_URL', 'CLOUDINARY_UPLOAD_PREFIX', 'CLOUDINARY_API_PROXY', 'MONGODB_URI', 'RAILWAY_ENVIRONMENT', 'FIREBASE_PROJECT_ID', 'MSG91_AUTH_KEY', 'HTTPS_PROXY', 'NODE_OPTIONS']) denied(() => configuration({ ...fake, [key]: 'offline-deny-sentinel' }), 'FORBIDDEN_ENVIRONMENT');
  denied(() => configuration({ ...fake, CLOUDINARY_CLOUD_NAME: 'vocle-production', CLOUDINARY_TEST_CLOUD_NAME: 'vocle-production' }), 'PRODUCTION_LIKE_CLOUD');
  const root = 'medcollab/security-test/12345-1-00000000-0000-4000-8000-000000000000'; namespace(root, root + '/op-1/synthetic'); checks++;
  for (const id of ['medcollab/messages/user/file', root + '-other/file', root + '/../../file', root + '/%2fother', root + '/x\\y', root + '//file', root + '/./file']) denied(() => namespace(root, id), id.startsWith(root + '/') && /^[a-zA-Z0-9_/.()-]+$/.test(id) ? 'RESOURCE_PATH_UNSAFE' : 'RESOURCE_OUTSIDE_RUN');
  const folder = root + '/op-1'; const r = { publicId: folder + '/synthetic', resourceType: 'video', deliveryType: 'upload', assetId: 'a'.repeat(32) };
  const stub = Object.create(Broker.prototype); stub.c = { root, cloud: fake.CLOUDINARY_CLOUD_NAME }; stub.journal = { intents: [{ folder, resourceType: 'video', state: 'created' }], resources: [r] }; stub.calls = []; stub.urls = new Map();
  assert.equal(stub.resource(r.publicId), r); checks++;
  denied(() => stub.resource(root + '/unknown'), 'UNREGISTERED_RESOURCE');
  denied(() => stub.safeResource({ ...r, publicId: 'foreign/file' }), 'RESOURCE_OUTSIDE_RUN');
  denied(() => stub.safeResource({ ...r, resourceType: 'image' }), 'RESOURCE_NOT_CREATED_BY_RUN');
  const url = `https://res.cloudinary.com/${fake.CLOUDINARY_CLOUD_NAME}/video/upload/v1/${r.publicId}.mp4`;
  stub.registerURL(url, r); checks++;
  for (const candidate of [url.replace('https:', 'http:'), url.replace(fake.CLOUDINARY_CLOUD_NAME, 'foreign-cloud'), url + '?redirect=1', url.replace('/v1/', '/l_fetch:foreign/'), url.replace('synthetic.mp4', 'unregistered.mp4')]) {
    assert.throws(() => stub.registerURL(candidate, r), e => e.infrastructure); checks++;
  }
  // Manifest cleanup must visit exact image/video/raw records, continue on failure,
  // and mark uncertain upload responses as unproven without any enumeration.
  const records = ['image', 'video', 'raw'].map((resourceType, i) => ({ ...r, publicId: root + `/op-${i}/synthetic`, resourceType }));
  const cleaned = []; stub.journal.resources = records; stub.journal.intents = []; stub.safeResource = x => x; stub.save = () => {}; stub.destroy = async x => { cleaned.push(x.publicId); return { result: 'ok' }; }; stub.read = async () => ({ exists: false });
  assert.equal((await stub.cleanup()).proven, true); assert.deepEqual(cleaned, records.map(r => r.publicId)); checks++;
  stub.journal.intents.push({ state: 'pending' }); assert.equal((await stub.cleanup()).proven, false); checks++;
  stub.journal.intents = []; stub.destroy = async x => { if (x.resourceType === 'video') throw new Error('offline failure'); return { result: 'ok' }; }; const failed = await stub.cleanup(); assert.equal(failed.proven, false); assert.equal(failed.resources.length, 3); checks++;
  // Replace underlying transport before installing the boundary: no sockets ever opened.
  const https = require('node:https'); let transportCalls = 0; https.request = () => { transportCalls++; return {}; };
  const net = installNetwork({ cloud: fake.CLOUDINARY_CLOUD_NAME });
  denied(() => https.request('https://api.cloudinary.com/foreign/upload'), 'NETWORK_BOUNDARY_DENIED');
  denied(() => fetch('https://example.invalid'), 'NETWORK_BOUNDARY_DENIED');
  await net.permit('api.cloudinary.com', 'POST', `/v1_1/${fake.CLOUDINARY_CLOUD_NAME}/image/upload`, async () => {
    denied(() => https.request({ protocol: 'https:', hostname: 'api.cloudinary.com', path: '/foreign', method: 'POST' }), 'NETWORK_BOUNDARY_DENIED');
    denied(() => https.request({ protocol: 'https:', hostname: 'api.cloudinary.com', path: `/v1_1/${fake.CLOUDINARY_CLOUD_NAME}/image/upload`, method: 'POST', rejectUnauthorized: false }), 'NETWORK_BOUNDARY_DENIED');
    https.request({ protocol: 'https:', hostname: 'api.cloudinary.com', path: `/v1_1/${fake.CLOUDINARY_CLOUD_NAME}/image/upload`, method: 'POST' });
  });
  assert.equal(transportCalls, 1); checks++;
  console.log(`Offline safety self-test: ${checks} checks passed; zero network I/O; provider suite not executed.`);
}
main().catch(e => { console.error(e.code || 'OFFLINE_SAFETY_SELF_TEST_FAILED'); process.exitCode = 1; });
