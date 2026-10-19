/*
 * Loaded only in the isolated backend container through NODE_OPTIONS.
 * It preserves real application code and intercepts the two exact MSG91
 * endpoints used by the sanity suite; every other axios request remains real.
 */
const { appendFileSync, mkdirSync } = require('node:fs');
const { createRequire } = require('node:module');
const { join } = require('node:path');

const backendDirectory = process.env.SANITY_BACKEND_DIR;
const inboxDirectory = process.env.SANITY_PROVIDER_INBOX;
if (!backendDirectory || !inboxDirectory) throw new Error('SANITY_BACKEND_DIR and SANITY_PROVIDER_INBOX are required for the provider preload.');

const backendRequire = createRequire(join(backendDirectory, 'package.json'));
const axios = backendRequire('axios');
const realPost = axios.post.bind(axios);
const smsEndpoint = 'https://control.msg91.com/api/v5/otp';
const widgetEndpoint = 'https://control.msg91.com/api/v5/widget/verifyAccessToken';

mkdirSync(inboxDirectory, { recursive: true });
axios.post = async (url, body, options) => {
  if (url === smsEndpoint) {
    const entry = { type: 'otp', mobile: String(body.mobile), otp: String(body.otp), capturedAt: new Date().toISOString() };
    appendFileSync(join(inboxDirectory, 'msg91-inbox.ndjson'), `${JSON.stringify(entry)}\n`, { mode: 0o600 });
    return { status: 200, data: { type: 'success' }, config: options };
  }
  if (url === widgetEndpoint) {
    // The opaque token is intentionally not decoded by this substitute.
    return { status: 200, data: { type: 'success', mobile: '12025550105' }, config: options };
  }
  return realPost(url, body, options);
};
