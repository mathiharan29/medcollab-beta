'use strict';
const fs = require('node:fs'); const path = require('node:path'); const { Writable } = require('node:stream');
const { createHash } = require('node:crypto'); const { requireSafe, namespace, installNetwork } = require('./guard');
const { png, alternatePNG, pdf, video, hash } = require('./fixtures');
const TYPES = ['image', 'video', 'raw'];
class Broker {
  constructor(c) {
    this.c = c; this.file = path.join(c.out, 'resources.json'); this.network = installNetwork(c);
    this.journal = fs.existsSync(this.file) ? JSON.parse(fs.readFileSync(this.file)) : { runId: c.runId, attempt: c.attempt, source: c.source, root: c.root, intents: [], resources: [] };
    requireSafe(this.journal.runId === c.runId && this.journal.attempt === c.attempt && this.journal.source === c.source && this.journal.root === c.root, 'JOURNAL_RUN_MISMATCH');
    this.urls = new Map(); this.calls = [];
    // No dotenv/server startup. The real config predicate and real SDK remain in use.
    const logger = require('../../src/utils/logger'); for (const key of Object.keys(logger)) logger[key] = () => {};
    const config = require('../../src/config/cloudinary'); config.connectCloudinary(); requireSafe(config.isCloudinaryConfigured(), 'REAL_CONFIG_REQUIRED');
    this.sdk = config.cloudinary;
    this.sdk.config({ upload_prefix: 'https://api.cloudinary.com', secure_distribution: 'res.cloudinary.com', secure: true, private_cdn: false, debug: false, hide_sensitive: true, api_proxy: null, analytics: false, urlAnalytics: false });
    this.uploadStream = this.sdk.uploader.upload_stream.bind(this.sdk.uploader);
    this.destroyResource = this.sdk.uploader.destroy.bind(this.sdk.uploader);
    this.readResource = this.sdk.api.resource.bind(this.sdk.api);
    this.buildURL = this.sdk.url.bind(this.sdk);
    this.sdk.uploader.upload_stream = (options, callback) => {
      const chunks = [];
      return new Writable({ write(chunk, enc, done) { chunks.push(Buffer.from(chunk)); done(); }, final: done => {
        this.appUpload(Buffer.concat(chunks), options).then(result => { callback(null, result); done(); }, error => { if (error.infrastructure) this.infrastructureError = error.code; callback(new Error('SYNTHETIC_PROVIDER_FAILURE')); done(); });
      } });
    };
    this.sdk.uploader.destroy = async (id, options) => { try { return await this.appDestroy(id, options); } catch (e) { this.infrastructureError = e.infrastructure ? e.code : 'APP_DESTROY_TRANSPORT'; throw new Error('SYNTHETIC_PROVIDER_FAILURE'); } };
    this.sdk.url = (id, options) => { try { return this.url(id, options); } catch (e) { this.infrastructureError = e.infrastructure ? e.code : 'URL_GUARD_FAILURE'; throw new Error('SYNTHETIC_DELIVERY_FAILURE'); } };
    this.save();
  }
  save() {
    const text = JSON.stringify(this.journal, null, 2) + '\n'; this.hygiene(text);
    const fd = fs.openSync(this.file + '.tmp', 'w', 0o600);
    try { fs.writeFileSync(fd, text); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
    fs.renameSync(this.file + '.tmp', this.file);
  }
  hygiene(text) {
    for (const secret of [process.env.CLOUDINARY_CLOUD_NAME, process.env.CLOUDINARY_API_KEY, process.env.CLOUDINARY_API_SECRET]) requireSafe(!secret || !text.includes(secret), 'REPORT_SECRET_LEAK');
  }
  safeResource(r) {
    namespace(this.c.root, r.publicId); requireSafe(TYPES.includes(r.resourceType) && r.deliveryType === 'upload' && /^[a-f0-9]{32}$/.test(r.assetId), 'RESOURCE_IDENTITY_INVALID');
    requireSafe(this.journal.intents.some(i => r.publicId.startsWith(i.folder + '/') && i.resourceType === r.resourceType && i.state === 'created'), 'RESOURCE_NOT_CREATED_BY_RUN');
    return r;
  }
  resource(id, type) { const r = this.journal.resources.find(r => r.publicId === id && (!type || r.resourceType === type)); requireSafe(r, 'UNREGISTERED_RESOURCE'); return this.safeResource(r); }
  evidence(r) { return { publicId: r.publicId, resourceType: r.resourceType, deliveryType: r.deliveryType, format: r.format, bytes: r.bytes, width: r.width, height: r.height, secureURLApproved: true }; }
  api(type, action, fn) {
    requireSafe(TYPES.includes(type) && ['upload', 'destroy'].includes(action), 'API_OPERATION_DENIED');
    return this.network.permit('api.cloudinary.com', 'POST', `/v1_1/${this.c.cloud}/${type}/${action}`, fn);
  }
  async upload(bytes, options, { folder, explicitId, lane = 'provider' } = {}) {
    requireSafe([png, alternatePNG, pdf, video].some(b => b.equals(bytes)), 'NON_SYNTHETIC_BYTES');
    requireSafe(TYPES.includes(options.resource_type), 'RESOURCE_TYPE_DENIED');
    const seq = this.journal.intents.length + 1;
    folder ||= `${this.c.root}/op-${String(seq).padStart(3, '0')}`; namespace(this.c.root, folder);
    if (explicitId) namespace(this.c.root, folder + '/' + explicitId);
    const effective = { ...options, folder, timeout: 20000 };
    if (explicitId) effective.public_id = explicitId;
    const intent = { operation: seq, folder, resourceType: options.resource_type, lane, sha256: hash(bytes), byteCount: bytes.length, state: 'pending', originalOptions: options, effectiveOptions: effective };
    this.journal.intents.push(intent); this.save();
    let result;
    try {
      result = await this.api(options.resource_type, 'upload', () => new Promise((resolve, reject) => {
        const stream = this.uploadStream(effective, (e, r) => e ? reject(e) : resolve(r)); stream.on('error', reject); stream.end(bytes);
      }));
    } catch (e) {
      const status = Number(e.http_code);
      // Only explicit provider 4xx rejections establish no successful creation.
      if ([400, 401, 403, 404, 409, 420, 429].includes(status)) { intent.state = 'rejected'; intent.providerStatus = status; this.save(); }
      if (e.infrastructure || ![400, 409].includes(status)) throw Object.assign(new Error('PROVIDER_UPLOAD_INFRASTRUCTURE'), { infrastructure: true, code: e.code || 'PROVIDER_UPLOAD_INFRASTRUCTURE' });
      return { rejected: true, providerStatus: status };
    }
    // Persist identity before any controller URL work. An unsafe result never triggers guessed deletion.
    requireSafe(result && result.resource_type === options.resource_type && result.type === 'upload', 'UPLOAD_TYPE_IDENTITY_MISMATCH');
    namespace(this.c.root, result.public_id); requireSafe(result.public_id.startsWith(folder + '/'), 'PROVIDER_FOLDER_INCOMPATIBLE');
    requireSafe(/^[a-f0-9]{32}$/.test(result.asset_id) && Number.isInteger(result.version), 'UPLOAD_IDENTITY_INVALID');
    const r = { publicId: result.public_id, resourceType: result.resource_type, deliveryType: result.type, assetId: result.asset_id, version: result.version, folder, format: result.format || null, bytes: result.bytes, width: result.width || null, height: result.height || null, originalSHA256: hash(bytes), removed: false };
    const prior = this.journal.resources.find(a => a.publicId === r.publicId && a.resourceType === r.resourceType);
    if (prior) requireSafe(prior.assetId === r.assetId, 'OVERWRITE_IDENTITY_CHANGED');
    if (prior && result.existing) r.originalSHA256 = prior.originalSHA256;
    intent.state = 'created'; intent.publicId = r.publicId;
    if (prior) Object.assign(prior, r); else this.journal.resources.push(r);
    this.save();
    this.registerURL(result.secure_url, r);
    this.calls.push({ operation: 'upload', lane, ...this.evidence(r) });
    return result;
  }
  async appUpload(bytes, options) {
    requireSafe(Object.keys(options).sort().join(',') === 'filename_override,folder,resource_type,unique_filename,use_filename', 'APPLICATION_OPTIONS_CHANGED');
    requireSafe(/^medcollab\/(messages|avatars)\/7ec[a-f0-9]{21}$/.test(options.folder) || options.folder === 'medcollab/handoffs', 'APPLICATION_FOLDER_DENIED');
    const folder = `${this.c.root}/app-${this.journal.intents.length + 1}/${options.folder}`;
    const result = await this.upload(bytes, options, { folder, lane: 'application-controller' });
    if (result.rejected) throw Object.assign(new Error('SYNTHETIC_PROVIDER_REJECTION'), { http_code: result.providerStatus });
    return result;
  }
  registerURL(value, r) {
    requireSafe(typeof value === 'string', 'DELIVERY_URL_MISSING'); const u = new URL(value);
    requireSafe(u.protocol === 'https:' && u.hostname === 'res.cloudinary.com' && !u.port && !u.username && !u.password && !u.search && !u.hash, 'DELIVERY_ENDPOINT_DENIED');
    const parts = u.pathname.split('/').slice(1).map(decodeURIComponent);
    requireSafe(parts[0] === this.c.cloud && TYPES.includes(parts[1]) && parts[2] === 'upload', 'DELIVERY_CLOUD_TYPE_DENIED');
    const prefix = parts.findIndex((s, i) => i > 2 && s === 'medcollab'); requireSafe(prefix >= 3, 'DELIVERY_RESOURCE_DENIED');
    const delivered = parts.slice(prefix).join('/');
    const suffixes = [r.publicId, `${r.publicId}.png`, `${r.publicId}.jpg`, `${r.publicId}.webp`, `${r.publicId}.mp4`, `${r.publicId}.pdf`];
    requireSafe(suffixes.includes(delivered), 'DELIVERY_UNREGISTERED_RESOURCE');
    for (const segment of parts.slice(3, prefix)) requireSafe(/^v\d+$/.test(segment) || segment.split(',').every(t => /^(w_400|h_400|h_300|c_limit|c_fill|q_auto|pg_1|so_0|fl_attachment|fl_attachment:synthetic[\w.()-]*)$/.test(t)), 'TRANSFORMATION_DENIED');
    this.urls.set(value, { publicId: r.publicId, resourceType: r.resourceType, deliveredType: parts[1] }); return value;
  }
  url(id, options = {}) { const r = this.resource(id); return this.registerURL(this.buildURL(id, options), r); }
  async retrieve(value) {
    const item = this.urls.get(value); requireSafe(item, 'UNREGISTERED_DELIVERY_URL'); this.resource(item.publicId, item.resourceType);
    const u = new URL(value);
    return this.network.permit(u.hostname, 'GET', u.pathname, () => new Promise((resolve, reject) => {
      const req = require('node:https').request(value, { method: 'GET', timeout: 15000 }, res => {
        const buffers = []; let size = 0;
        res.on('data', b => { size += b.length; if (size > 2 * 1024 * 1024) { res.destroy(); reject(Object.assign(new Error('DELIVERY_SIZE_LIMIT'), { infrastructure: true, code: 'DELIVERY_SIZE_LIMIT' })); } else buffers.push(b); });
        res.on('error', reject); res.on('end', () => {
          const body = Buffer.concat(buffers);
          resolve({ status: res.statusCode, contentType: String(res.headers['content-type'] || '').split(';')[0], bytes: body.length, sha256: hash(body), redirected: res.statusCode >= 300 && res.statusCode < 400 });
        });
      });
      req.on('timeout', () => req.destroy(new Error('DELIVERY_TIMEOUT'))); req.on('error', e => reject(Object.assign(new Error('DELIVERY_TRANSPORT'), { infrastructure: true, code: e.code || 'DELIVERY_TRANSPORT' }))); req.end();
    }));
  }
  async read(r) {
    this.safeResource(r); const p = `/v1_1/${this.c.cloud}/resources/${r.resourceType}/${r.deliveryType}/${encodeURIComponent(r.publicId).replace(/'/g, '%27')}`;
    try {
      const result = await this.network.permit('api.cloudinary.com', 'GET', p, () => this.readResource(r.publicId, { resource_type: r.resourceType, type: r.deliveryType, timeout: 15000 }));
      requireSafe(result.public_id === r.publicId && result.asset_id === r.assetId && result.resource_type === r.resourceType && result.type === r.deliveryType, 'READ_IDENTITY_MISMATCH');
      return { exists: true, identityMatched: true, bytes: result.bytes, format: result.format || null };
    } catch (e) { if (Number(e.http_code || e.error?.http_code) === 404) return { exists: false }; throw Object.assign(new Error('EXACT_RESOURCE_READ_FAILED'), { infrastructure: true, code: e.code || 'EXACT_RESOURCE_READ_FAILED' }); }
  }
  async destroy(r, { invalidate = false } = {}) {
    this.safeResource(r);
    const result = await this.api(r.resourceType, 'destroy', () => this.destroyResource(r.publicId, { resource_type: r.resourceType, type: r.deliveryType, invalidate, timeout: 15000 }));
    requireSafe(['ok', 'not found'].includes(result.result), 'DESTROY_RESULT_INVALID');
    this.calls.push({ operation: 'destroy', resourceType: r.resourceType, publicId: r.publicId, invalidate, result: result.result });
    return { result: result.result };
  }
  async appDestroy(id, options) {
    const r = this.resource(id); requireSafe(['image', 'raw'].includes(options.resource_type), 'APP_DESTROY_TYPE_CHANGED');
    this.calls.push({ operation: 'application-destroy', publicId: id, resourceType: options.resource_type });
    // Preserve actual image/raw guessing even for a recorded video. Exact public ID remains bounded.
    const result = await this.api(options.resource_type, 'destroy', () => this.destroyResource(id, { ...options, timeout: 15000 }));
    requireSafe(['ok', 'not found'].includes(result.result), 'APP_DESTROY_RESULT_INVALID');
    this.calls.push({ operation: 'application-destroy-result', publicId: id, resourceType: options.resource_type, result: result.result });
    return { result: result.result };
  }
  async cleanup() {
    const results = []; let failed = false;
    for (const r of this.journal.resources) {
      try {
        this.safeResource(r); const destroyed = await this.destroy(r, { invalidate: true });
        let state = await this.read(r);
        for (let i = 0; state.exists && i < 3; i++) { await new Promise(resolve => setTimeout(resolve, 1500)); state = await this.read(r); }
        r.removed = !state.exists; this.save(); failed ||= !r.removed;
        results.push({ publicId: r.publicId, resourceType: r.resourceType, destroyResult: destroyed.result, originAbsent: r.removed });
      } catch (e) { failed = true; results.push({ publicId: r.publicId, resourceType: r.resourceType, originAbsent: false, failure: e.infrastructure ? e.code : 'CLEANUP_OPERATION_FAILED' }); }
    }
    const pending = this.journal.intents.filter(i => i.state === 'pending').length;
    return { attempted: true, resources: results, pendingUnresolved: pending, proven: !failed && pending === 0, broadDeletionUsed: false };
  }
}
module.exports = { Broker, TYPES };
