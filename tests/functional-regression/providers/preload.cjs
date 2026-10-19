const { appendFileSync, mkdirSync, readFileSync, readdirSync } = require('node:fs');
const { Writable } = require('node:stream');
const { createRequire } = require('node:module');
const { join } = require('node:path');
const Module = require('node:module');

const backendRoot = process.env.VOCLE_BACKEND_DIR;
const inbox = process.env.VOCLE_PROVIDER_INBOX;
if (!backendRoot || !inbox) throw new Error('Provider fake requires isolated backend and inbox');
mkdirSync(inbox, { recursive: true });
let installClock = () => {};
if (process.env.VOCLE_FAKE_CLOCK === '1') {
  const NativeDate = global.Date;
  const now = () => {
    const clocks = readdirSync(inbox).filter((name) => /^clock-\d+\.json$/.test(name)).sort();
    if (clocks.length === 0) return NativeDate.now();
    const iso = JSON.parse(readFileSync(join(inbox, clocks.at(-1)), 'utf8')).iso;
    const milliseconds = NativeDate.parse(iso);
    if (!Number.isFinite(milliseconds)) throw new Error('Invalid synthetic clock ISO timestamp');
    return milliseconds;
  };
  installClock = () => {
    global.Date = class ControlledDate extends NativeDate {
      constructor(...args) { if (args.length === 0) super(now()); else super(...args); }
      static now() { return now(); }
    };
  };
}
let fakeFirebase = null;
if (process.env.VOCLE_FAKE_FIREBASE === '1') {
  const fakeMessaging = {
    send: async (message) => {
      let modes = {};
      try { modes = JSON.parse(readFileSync(join(inbox, 'fcm-modes.json'), 'utf8')); }
      catch (error) { if (error.code !== 'ENOENT') throw error; }
      const mode = modes[message.token] || 'success';
      appendFileSync(join(inbox, 'fcm-capture.ndjson'), `${JSON.stringify({ mode, message, observedAt: new Date().toISOString(), localHour: new Date().getHours() })}\n`, { mode: 0o600 });
      console.log(`VOCLE_FAKE_FCM_CAPTURE ${message.data?.notificationId || 'none'} ${message.token} ${mode} localHour=${new Date().getHours()}`);
      if (mode === 'stale') { const error = new Error('Synthetic stale FCM token'); error.code = 'messaging/registration-token-not-registered'; throw error; }
      if (mode === 'temporary') { const error = new Error('Synthetic temporary FCM error'); error.code = 'messaging/unavailable'; throw error; }
      if (mode !== 'success') throw new Error(`Unknown synthetic FCM mode ${mode}`);
      return `synthetic-fcm-${message.token}`;
    },
  };
  fakeFirebase = {
    connectFirebase: () => {}, isFirebaseReady: () => true,
    getFirebaseMessaging: () => fakeMessaging,
    getFirebaseAdmin: () => ({ messaging: () => fakeMessaging }),
  };
}
let fakeCloudinary = null;
if (process.env.VOCLE_FAKE_CLOUDINARY === '1') {
  const mode = () => {
    try { return JSON.parse(readFileSync(join(inbox, 'cloudinary-mode.json'), 'utf8')); }
    catch (error) { if (error.code === 'ENOENT') return { enabled: false }; throw error; }
  };
  fakeCloudinary = {
    connectCloudinary: () => {},
    isCloudinaryConfigured: () => mode().enabled === true,
    cloudinary: {
      uploader: {
        upload_stream: (options, callback) => {
          const chunks = [];
          return new Writable({
            write(chunk, _encoding, done) { chunks.push(Buffer.from(chunk)); done(); },
            final(done) {
              const buffer = Buffer.concat(chunks);
              const current = mode();
              appendFileSync(join(inbox, 'cloudinary-capture.ndjson'), `${JSON.stringify({ options, size: buffer.length, firstBytes: buffer.subarray(0, 16).toString('hex'), outcome: current.outcome || 'success' })}\n`, { mode: 0o600 });
              if (current.outcome === 'fail') callback(new Error('Synthetic provider upload failure'));
              else callback(null, { secure_url: `https://res.cloudinary.com/synthetic/${options.resource_type}/upload/${options.filename_override}`, public_id: `${options.folder}/${options.filename_override}`, width: options.resource_type === 'image' ? 320 : null, height: options.resource_type === 'image' ? 240 : null, format: options.resource_type === 'raw' ? 'pdf' : options.resource_type === 'video' ? 'mp4' : 'png' });
              done();
            },
          });
        },
        destroy: async () => ({ result: 'ok' }),
      },
      url: (publicId, options) => `https://res.cloudinary.com/synthetic/${options.resource_type || 'image'}/thumbnail/${encodeURIComponent(publicId)}?format=${options.format}&width=${options.width}`,
    },
  };
}
if (fakeFirebase || fakeCloudinary || process.env.VOCLE_FAKE_CLOCK === '1') {
  const originalLoad = Module._load;
  const firebaseConfigPath = join(backendRoot, 'src', 'config', 'firebase.js');
  const cloudinaryConfigPath = join(backendRoot, 'src', 'config', 'cloudinary.js');
  const notificationServicePath = join(backendRoot, 'src', 'services', 'notification.service.js');
  const appPath = join(backendRoot, 'src', 'app.js');
  Module._load = function (request, parent, isMain) {
    let resolved;
    try { resolved = Module._resolveFilename(request, parent, isMain); } catch { /* preserve the ordinary module error */ }
    if (fakeFirebase && resolved === firebaseConfigPath) return fakeFirebase;
    if (fakeCloudinary && resolved === cloudinaryConfigPath) return fakeCloudinary;
    const loaded = originalLoad.apply(this, arguments);
    if (resolved === notificationServicePath && process.env.VOCLE_FAKE_CLOCK === '1') {
      return {
        ...loaded,
        notifyNewMessage: async (options) => {
          const result = await loaded.notifyNewMessage(options);
          console.log(`VOCLE_FAKE_NOTIFY_DONE ${options.message?._id}`);
          return result;
        },
      };
    }
    if (resolved === appPath && process.env.VOCLE_FAKE_CLOCK === '1') installClock();
    return loaded;
  };
}
const axios = createRequire(join(backendRoot, 'package.json'))('axios');
axios.post = async (url, body) => {
  if (url === 'https://control.msg91.com/api/v5/otp') {
    let mode = 'success';
    try { mode = JSON.parse(readFileSync(join(inbox, 'msg91-mode.json'), 'utf8')).mode; }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
    if (mode === 'timeout') throw new Error('Synthetic MSG91 provider timeout');
    if (mode === 'reject') return { status: 400, data: { type: 'error', message: 'Synthetic MSG91 rejection' } };
    if (mode !== 'success') throw new Error(`Unknown synthetic MSG91 mode ${mode}`);
    appendFileSync(join(inbox, 'msg91-inbox.ndjson'), `${JSON.stringify({ type: 'otp', mobile: String(body.mobile), otp: String(body.otp) })}\n`, { mode: 0o600 });
    return { status: 200, data: { type: 'success' } };
  }
  if (url === 'https://control.msg91.com/api/v5/widget/verifyAccessToken') {
    const token = typeof body === 'string' ? new URLSearchParams(body).get('access-token') : body['access-token'];
    appendFileSync(join(inbox, 'widget-inbox.ndjson'), `${JSON.stringify({ type: 'widget-verify', token })}\n`, { mode: 0o600 });
    if (token === 'synthetic-provider-failure') return { status: 503, data: { type: 'error', message: 'Synthetic provider unavailable' } };
    if (token === 'synthetic-invalid') return { status: 400, data: { type: 'error', message: 'Synthetic invalid token' } };
    return { status: 200, data: { type: 'success', mobile: '12025550105' } };
  }
  throw new Error(`Provider fake blocked unexpected axios POST to ${new URL(url).origin}`);
};
