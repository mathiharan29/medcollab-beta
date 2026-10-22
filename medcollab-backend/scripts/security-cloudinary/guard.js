'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const REPO = 'mathiharan29/medcollab-beta';
function requireSafe(ok, code) { if (!ok) throw Object.assign(new Error(code), { code, infrastructure: true }); }
function configuration(env = process.env) {
  requireSafe(env.CLOUDINARY_TEST_CLOUD_NAME?.trim(), 'EXPECTED_TEST_CLOUD_MISSING');
  requireSafe(env.CLOUDINARY_CLOUD_NAME === env.CLOUDINARY_TEST_CLOUD_NAME, 'TEST_CLOUD_MISMATCH');
  requireSafe(/^[a-z0-9_-]{3,80}$/.test(env.CLOUDINARY_CLOUD_NAME), 'CLOUD_NAME_INVALID');
  requireSafe(!/(^|[-_])(prod|production|live)([-_]|$)/i.test(env.CLOUDINARY_CLOUD_NAME), 'PRODUCTION_LIKE_CLOUD');
  requireSafe(env.CLOUDINARY_API_KEY?.trim() && env.CLOUDINARY_API_SECRET?.trim(), 'CREDENTIALS_MISSING');
  requireSafe(env.NODE_ENV === 'test' && env.VOCLE_CLOUDINARY_LIVE === 'isolated-synthetic-only', 'TEST_MODE_REQUIRED');
  const local = env.VOCLE_CLOUDINARY_LOCAL === 'isolated-synthetic-only';
  let runId, attempt, source;
  if (local) {
    // Local identity is explicit; never impersonate a hosted workflow or allow
    // the local path inside Actions. All provider/namespace guards still apply.
    requireSafe(!Object.keys(env).some(key => /^GITHUB_/i.test(key) && env[key]), 'LOCAL_HOSTED_IDENTITY_DENIED');
    requireSafe(env.VOCLE_LOCAL_APPROVED_CLOUD === env.CLOUDINARY_TEST_CLOUD_NAME, 'LOCAL_CLOUD_APPROVAL_REQUIRED');
    runId = env.VOCLE_LOCAL_RUN_ID; attempt = '1'; source = env.VOCLE_LOCAL_SOURCE;
  } else {
    requireSafe(!env.VOCLE_CLOUDINARY_LOCAL, 'LOCAL_MODE_INVALID');
    requireSafe(env.GITHUB_REPOSITORY === REPO && env.GITHUB_REF === 'refs/heads/master' && env.GITHUB_EVENT_NAME === 'workflow_dispatch', 'REPOSITORY_REF_EVENT_DENIED');
    requireSafe(env.GITHUB_WORKFLOW === 'Vocle Real Cloudinary Security', 'WORKFLOW_DENIED');
    runId = env.GITHUB_RUN_ID; attempt = env.GITHUB_RUN_ATTEMPT; source = env.GITHUB_SHA;
  }
  requireSafe(/^\d+$/.test(runId || '') && /^[1-9]\d*$/.test(attempt || '') && /^[a-f0-9]{40}$/.test(source || ''), 'RUN_IDENTITY_INVALID');
  for (const [name, value] of Object.entries(env)) {
    if (!value) continue;
    if (/^CLOUDINARY_/i.test(name)) requireSafe(['CLOUDINARY_TEST_CLOUD_NAME', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET'].includes(name), 'FORBIDDEN_ENVIRONMENT');
    requireSafe(!/^(CLOUDINARY_URL|CLOUDINARY_(UPLOAD_PREFIX|API_PROXY|PRIVATE_CDN|CNAME|SECURE_DISTRIBUTION)|MONGODB_URI|MONGO_URI|DATABASE_URL|RAILWAY_.*|FIREBASE_.*|FCM_.*|MSG91_.*|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NODE_OPTIONS)$/i.test(name), 'FORBIDDEN_ENVIRONMENT');
    if (/^(APP_ENV|ENVIRONMENT|DEPLOYMENT_ENV)$/.test(name)) requireSafe(!/prod|live/i.test(value), 'PRODUCTION_ENVIRONMENT');
  }
  for (const directory of [process.cwd(), path.resolve(__dirname, '../..'), path.resolve(__dirname, '../../..')]) {
    requireSafe(!fs.readdirSync(directory).some(name => /^\.env($|\.)/.test(name) && !/\.(example|sample|template)$/.test(name)), 'CREDENTIAL_FILE_PRESENT');
  }
  requireSafe(env.RUNNER_TEMP && path.isAbsolute(env.RUNNER_TEMP), 'SCRATCH_REQUIRED');
  return { runId, attempt, source, executionMode: local ? 'local' : 'hosted', positiveAllowlistMatched: true, cloud: env.CLOUDINARY_CLOUD_NAME };
}
function namespace(root, id) {
  requireSafe(/^medcollab\/security-test\/\d+-[1-9]\d*-[a-f0-9-]{36}$/.test(root), 'NAMESPACE_INVALID');
  requireSafe(typeof id === 'string' && id.startsWith(root + '/') && id.length < 240 && /^[a-zA-Z0-9_/.()-]+$/.test(id), 'RESOURCE_OUTSIDE_RUN');
  requireSafe(!id.split('/').some(s => !s || s === '.' || s === '..'), 'RESOURCE_PATH_UNSAFE');
  return id;
}
function directory(env = process.env) { return path.join(env.RUNNER_TEMP, 'vocle-cloudinary-results'); }
function preflight(env = process.env) {
  const c = configuration(env); const out = directory(env); fs.mkdirSync(out, { recursive: true });
  const file = path.join(out, 'safety.json');
  if (!fs.existsSync(file)) {
    const text = JSON.stringify({ runId: c.runId, attempt: c.attempt, source: c.source, executionMode: c.executionMode, root: `medcollab/security-test/${c.runId}-${c.attempt}-${randomUUID()}`, positiveAllowlistMatched: true, nonProductionMode: true }, null, 2) + '\n';
    for (const secret of [c.cloud, env.CLOUDINARY_API_KEY, env.CLOUDINARY_API_SECRET]) requireSafe(!text.includes(secret), 'NAMESPACE_SECRET_COLLISION');
    fs.writeFileSync(file, text, { flag: 'wx', mode: 0o600 });
  }
  const safety = JSON.parse(fs.readFileSync(file));
  requireSafe(safety.runId === c.runId && safety.attempt === c.attempt && safety.source === c.source, 'JOURNAL_RUN_MISMATCH');
  requireSafe((safety.executionMode || 'hosted') === c.executionMode, 'JOURNAL_MODE_MISMATCH');
  namespace(safety.root, safety.root + '/check');
  return { ...c, ...safety, out };
}
function installNetwork(c) {
  const https = require('node:https'); const original = https.request;
  const telemetry = { apiRequests: 0, deliveryRequests: 0, blocked: 0, approvedCloudOnly: true };
  let capability = null;
  const deny = () => { telemetry.blocked++; requireSafe(false, 'NETWORK_BOUNDARY_DENIED'); };
  https.request = function (first, ...args) {
    const base = typeof first === 'string' || first instanceof URL ? new URL(first) : first;
    const opts = { protocol: base.protocol, hostname: base.hostname, host: base.host, pathname: base.pathname, search: base.search, path: base.path, query: base.query, port: base.port, method: base.method, rejectUnauthorized: base.rejectUnauthorized, ...(args[0] && typeof args[0] === 'object' ? args[0] : {}) };
    const host = opts.hostname || opts.host; const protocol = opts.protocol || 'https:'; const requestPath = opts.pathname ? opts.pathname + (opts.search || opts.query && '?' + opts.query || '') : opts.path;
    if (!capability || protocol !== 'https:' || host !== capability.host || opts.port && String(opts.port) !== '443' || opts.rejectUnauthorized === false || opts.agent && opts.agent !== https.globalAgent || (opts.method || 'GET').toUpperCase() !== capability.method || requestPath !== capability.path) return deny();
    capability.used++; if (capability.used !== 1) return deny();
    telemetry[host === 'api.cloudinary.com' ? 'apiRequests' : 'deliveryRequests']++;
    const request = original.call(this, first, ...args);
    if (typeof request.on === 'function') request.on('timeout', () => request.destroy(new Error('BOUNDED_PROVIDER_TIMEOUT')));
    return request;
  };
  https.get = deny; require('node:http').request = deny; require('node:http').get = deny; global.fetch = deny;
  return {
    telemetry,
    async permit(host, method, requestPath, action) {
      requireSafe(!capability, 'CONCURRENT_PROVIDER_OPERATION');
      if (host === 'api.cloudinary.com') requireSafe(requestPath.startsWith(`/v1_1/${c.cloud}/`), 'API_CLOUD_DENIED');
      else requireSafe(host === 'res.cloudinary.com' && requestPath.startsWith(`/${c.cloud}/`), 'CDN_CLOUD_DENIED');
      capability = { host, method, path: requestPath, used: 0 };
      try { return await action(); } finally { capability = null; }
    },
  };
}
module.exports = { REPO, requireSafe, configuration, namespace, directory, preflight, installNetwork };
if (require.main === module) {
  try { preflight(); console.log('Safety preflight passed: exact positive test-cloud match; isolated namespace established.'); }
  catch (e) { console.error(e.infrastructure ? e.code : 'SAFETY_PREFLIGHT_FAILED'); process.exitCode = 1; }
}
