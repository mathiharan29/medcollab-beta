'use strict';
// Offline infrastructure probes only. No MongoDB, provider client or credential use.
const assert = require('node:assert/strict'); const fs = require('node:fs'); const path = require('node:path'); const os = require('node:os');
const guard = require('./guard'); const h = require('./helpers');
const env = { NODE_ENV: 'test', MONGODB_URI: guard.URI, API_BASE_URL: guard.BASE, JWT_SECRET: guard.JWT };
guard.environment(env, []);
for (const key of ['CLOUDINARY_URL', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET', 'FIREBASE_PROJECT_ID', 'MSG91_AUTH_KEY', 'HTTPS_PROXY']) {
  assert.throws(() => guard.environment({ ...env, [key]: 'prohibited-input' }, []));
}
assert.throws(() => guard.environment({ ...env, MONGODB_URI: 'mongodb://example.invalid/vocle_ci' }, []));
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'vocle-media-guard-'));
fs.writeFileSync(path.join(root, '.env'), 'inert file, no credentials'); assert.throws(() => guard.environment(env, [root])); fs.unlinkSync(path.join(root, '.env'));
assert.throws(() => guard.contained(root, path.join(root, '..', 'foreign')));
const sentinel = path.join(root, 'canary'); fs.writeFileSync(sentinel, 'synthetic'); assert.equal(guard.contained(root, sentinel), sentinel); fs.unlinkSync(sentinel); fs.rmdirSync(root);
const telemetry = guard.network();
for (const probe of [
  () => require('node:net').connect({ host: 'res.cloudinary.com', port: 443 }),
  () => require('node:net').connect({ host: '127.0.0.1', port: 443 }),
  () => require('node:https').request('https://api.cloudinary.com'),
  () => require('node:dns').lookup('res.cloudinary.com', () => {}),
  () => fetch('https://res.cloudinary.com/inert', { redirect: 'error' }),
  () => fetch(guard.BASE + '/health'),
]) assert.throws(probe, { code: 'MEDIA_NETWORK_BLOCKED' });
assert.equal(telemetry.blocked, 6);
const Module = require('node:module'), double = require('./sdk-double')(), original = Module._load;
Module._load = function (name, ...args) { if (name === 'cloudinary') return { v2: double.sdk }; return Reflect.apply(original, this, [name, ...args]); };
const config = require('../../src/config/cloudinary'); assert.equal(config.cloudinary, double.sdk); config.isCloudinaryConfigured = () => true;
const controller = require('../../src/features/media/media.controller');
async function smoke() {
  const invoke = req => new Promise((resolve, reject) => {
    let status; controller.uploadFile(req, { status(n) { status = n; return this; }, json(body) { resolve({ status, body }); } }, reject);
  });
  for (const [mime, name, bytes, type] of [['image/png', 'synthetic.png', h.png, 'image'], ['application/pdf', 'synthetic.pdf', h.pdf, 'raw'], ['video/mp4', 'synthetic.mp4', h.video, 'video'], ['application/octet-stream', 'synthetic.pdf', h.pdf, 'raw']]) {
    double.reset(); const r = await invoke({ body: {}, file: { mimetype: mime, originalname: name, buffer: bytes, size: bytes.length }, user: { _id: '7ed000000000000000000001' } });
    assert.equal(r.status, 200); assert.equal(double.state().calls[0].options.resource_type, type); assert.equal(double.state().calls[0].sha256, h.hash(bytes));
  }
  assert.ok(!Object.keys(require.cache).some(p => /node_modules[\\/]cloudinary[\\/]/.test(p)));
  console.log('Offline guard probes passed: prohibited configuration/file/path rejected; six network attempts intercepted before I/O; real controller smoke via SDK replacement passed. No credentials or provider requests.');
}
smoke().catch((error) => { console.error(`Offline infrastructure self-test failed: ${error.message}`); process.exitCode = 1; });
