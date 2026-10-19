'use strict';
// Offline transport double exercises the REAL SDK, controller, broker and janitor.
// It proves harness wiring only, never provider decoding/storage/delivery behavior.
const assert = require('node:assert/strict'); const fs = require('node:fs'); const os = require('node:os'); const path = require('node:path');
const { Writable, PassThrough } = require('node:stream'); const { createHash } = require('node:crypto');
const fixtures = require('./fixtures'); const { manifest, context, execute } = require('./cases');
const inventory = new Map(); let sequence = 0, wireRequests = 0;
const sha = text => createHash('sha256').update(text).digest('hex');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'vocle-cloudinary-offline-'));
const root = 'medcollab/security-test/12345-1-00000000-0000-4000-8000-000000000000';
Object.assign(process.env, { NODE_ENV: 'test', CLOUDINARY_CLOUD_NAME: 'synthetic-offline-cloud', CLOUDINARY_TEST_CLOUD_NAME: 'synthetic-offline-cloud', CLOUDINARY_API_KEY: 'offline-key-sentinel', CLOUDINARY_API_SECRET: 'offline-secret-sentinel' });
const cloud = process.env.CLOUDINARY_CLOUD_NAME;
function dispatch(opts, body) {
  const url = typeof opts === 'string' ? new URL(opts) : { hostname: opts.hostname, pathname: opts.pathname || opts.path, method: opts.method };
  const parts = url.pathname.split('/').filter(Boolean).map(decodeURIComponent); const method = opts.method || 'GET';
  if (url.hostname === 'res.cloudinary.com') {
    const start = parts.indexOf('medcollab'); const publicPath = parts.slice(start).join('/');
    const match = [...inventory.values()].find(a => a.resource_type === parts[1] && (a.public_id === publicPath || publicPath.startsWith(a.public_id + '.')));
    if (!match) return [404, Buffer.from('not found'), 'text/plain'];
    const transform = parts.slice(3, start).join('/');
    return [200, match.bytesBuffer, transform.includes('so_0') ? 'image/jpeg' : publicPath.endsWith('.webp') ? 'image/webp' : match.resource_type === 'image' ? 'image/png' : match.resource_type === 'video' ? 'video/mp4' : 'application/pdf'];
  }
  assert.equal(url.hostname, 'api.cloudinary.com'); assert.equal(parts[1], cloud);
  if (method === 'GET') {
    const r = inventory.get(parts[3] + ':' + parts[5]); return r ? [200, r] : [404, { error: { message: 'offline missing', http_code: 404 } }];
  }
  const raw = body.toString('latin1'); const fields = {};
  for (const m of raw.matchAll(/name="([^"\r\n]+)"\r\n\r\n([^\r\n]*)/g)) fields[m[1]] = m[2];
  const type = parts[2];
  if (parts[3] === 'destroy') { const key = type + ':' + fields.public_id; const exists = inventory.delete(key); return [200, { result: exists ? 'ok' : 'not found' }]; }
  assert.equal(parts[3], 'upload'); assert.ok(fields.signature && fields.api_key && fields.folder.startsWith(root + '/'));
  const publicId = fields.folder + '/' + (fields.public_id || 'file_' + (++sequence)); const key = type + ':' + publicId;
  const prior = inventory.get(key); if (prior && ['false', '0'].includes(fields.overwrite)) return [200, { ...prior, existing: true }];
  const fileMatch = /name="file"; filename="file"\r\nContent-Type: application\/octet-stream\r\n\r\n([\s\S]*)\r\n--[^\r\n]+--\s*$/.exec(raw);
  assert.ok(fileMatch, 'Real SDK multipart file body missing');
  const bytesBuffer = Buffer.from(fileMatch[1], 'latin1'); assert.ok([fixtures.png, fixtures.alternatePNG, fixtures.pdf, fixtures.video].some(b => b.equals(bytesBuffer)));
  const r = { public_id: publicId, asset_id: prior?.asset_id || sha(key).slice(0, 32), version: ++sequence, resource_type: type, type: 'upload', format: type === 'image' ? 'png' : type === 'video' ? 'mp4' : undefined, bytes: bytesBuffer.length, width: 1, height: 1, secure_url: `https://res.cloudinary.com/${cloud}/${type}/upload/v${sequence}/${publicId}${type === 'image' ? '.png' : type === 'video' ? '.mp4' : ''}`, bytesBuffer };
  inventory.set(key, r); return [200, r];
}
require('node:https').request = function (first, options, callback) {
  if (typeof options === 'function') { callback = options; options = {}; }
  const opts = typeof first === 'string' ? { ...options, ...Object.fromEntries(['hostname', 'pathname'].map(k => [k, new URL(first)[k]])) } : { ...first, ...options };
  wireRequests++; const chunks = [];
  const request = new Writable({ write(b, enc, done) { chunks.push(Buffer.from(b)); done(); }, final(done) {
    try {
      const [status, value, contentType] = dispatch(opts, Buffer.concat(chunks)); const response = new PassThrough(); response.statusCode = status; response.headers = { 'content-type': contentType || 'application/json' };
      callback(response); response.end(Buffer.isBuffer(value) ? value : Buffer.from(JSON.stringify(value))); done();
    } catch (e) { done(e); }
  } });
  request.setTimeout = () => request; request.abort = () => request.destroy(); return request;
};
async function main() {
  const { Broker } = require('./broker'); const broker = new Broker({ out: directory, cloud, root, runId: '12345', attempt: '1', source: 'a'.repeat(40) });
  const c = context(broker);
  try {
    for (let i = 0; i < manifest.count - 1; i++) { const result = await execute(i, c); assert.equal(broker.infrastructureError, undefined); if ([26, 27, 29].includes(i)) assert.equal(result.pass, true, `Strengthened control ${i}: ${JSON.stringify(result.actual)}`); }
    const cleanup = await broker.cleanup(); assert.equal(cleanup.proven, true); assert.equal(inventory.size, 0); assert.equal(broker.network.telemetry.blocked, 0);
    assert.ok(wireRequests > 50); const names = fs.readdirSync(directory); assert.ok(names.includes('resources.json'));
    console.log(`Offline transport roundtrip passed: real controller/SDK serialization, ${wireRequests} intercepted requests, all recorded types cleaned; zero network I/O.`);
  } finally {
    // Exact temporary files created here only; no recursive filesystem deletion.
    for (const name of ['resources.json', 'resources.json.tmp']) { const file = path.join(directory, name); if (fs.existsSync(file)) fs.unlinkSync(file); }
    fs.rmdirSync(directory);
  }
}
main().catch(e => { console.error(e.message || e.code || 'OFFLINE_TRANSPORT_TEST_FAILED'); process.exitCode = 1; });
