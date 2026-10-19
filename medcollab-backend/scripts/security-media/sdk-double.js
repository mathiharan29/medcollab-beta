'use strict';
// A call recorder and controlled simulator. No Cloudinary library or credentials.
const { Writable } = require('node:stream');
const { createHash } = require('node:crypto');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const serial = value => JSON.parse(JSON.stringify(value, (_key, v) => typeof v === 'function' ? '[function]' : v));
module.exports = function makeDouble() {
  let calls = [], assets = [], sequence = 0, fault = null, forbidden = 0;
  const unexpected = () => { forbidden++; throw new Error('UNEXPECTED_SDK_METHOD'); };
  const sdk = {
    config: () => { calls.push({ operation: 'config' }); return {}; },
    uploader: new Proxy({
      upload_stream(options, callback) {
        const call = { operation: 'upload_stream', options: serial(options) }; calls.push(call);
        const chunks = [];
        return new Writable({ write(chunk, _encoding, cb) { chunks.push(Buffer.from(chunk)); cb(); }, final(cb) {
          const bytes = Buffer.concat(chunks); call.bytes = bytes.length; call.sha256 = hash(bytes);
          if (fault === 'upload-error') { callback(new Error('synthetic-sdk-failure')); cb(); return; }
          if (typeof options.folder !== 'string') { callback(new Error('synthetic-invalid-folder')); cb(); return; }
          const id = `${options.folder}/canary-${++sequence}${options.resource_type === 'raw' ? '.pdf' : ''}`;
          const asset = { publicId: id, resourceType: options.resource_type, sha256: call.sha256, bytes: bytes.length };
          assets.push(asset);
          callback(null, { public_id: id, secure_url: `https://res.cloudinary.com/offline-contract/${options.resource_type}/upload/${id}`, width: options.resource_type === 'image' ? 1 : null, height: options.resource_type === 'image' ? 1 : null, format: options.resource_type === 'raw' ? null : options.resource_type === 'video' ? 'mp4' : 'png' }); cb();
        } });
      },
      async destroy(publicId, options) {
        calls.push({ operation: 'destroy', publicId, options: serial(options) });
        if (fault === 'destroy-error') throw new Error('synthetic-sdk-failure');
        const index = assets.findIndex(a => a.publicId === publicId && a.resourceType === options.resource_type);
        if (index < 0) return { result: 'not found' };
        assets.splice(index, 1); return { result: 'ok' };
      },
    }, { get(target, key) { return key in target ? target[key] : unexpected; } }),
    url(publicId, options) {
      calls.push({ operation: 'url', publicId, options: serial(options) });
      if (fault === 'url-error' || (fault === 'pdf-thumbnail-error' && options.page)) throw new Error('synthetic-sdk-failure');
      return `https://res.cloudinary.com/offline-contract/${options.resource_type || 'image'}/upload/recorded-transform/${publicId}`;
    },
  };
  return { sdk, reset() { calls = []; assets = []; sequence = 0; fault = null; forbidden = 0; }, fault(value) { fault = value; }, state() { return { calls: serial(calls), assets: serial(assets), forbidden }; } };
};
