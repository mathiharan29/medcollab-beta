'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const BASE = 'http://127.0.0.1:5000';
const URI = 'mongodb://127.0.0.1:27017/vocle_ci';
const JWT = 'ci-test-only-jwt-secret-not-for-production-0000000000000001';
function environment(env = process.env, directories = [process.cwd(), path.resolve(__dirname, '../..')]) {
  assert.equal(env.NODE_ENV, 'test'); assert.equal(env.MONGODB_URI, URI); assert.equal(env.API_BASE_URL, BASE);
  assert.equal(env.JWT_SECRET, JWT);
  for (const [key, value] of Object.entries(env)) {
    if (/CLOUDINARY|MSG91|FIREBASE|GOOGLE_APPLICATION_CREDENTIALS|HTTPS?_PROXY|ALL_PROXY/i.test(key)) {
      assert.ok(!value, 'External provider or proxy configuration must be absent');
    }
  }
  for (const directory of directories) assert.ok(!fs.readdirSync(directory).some(n => /^\.env(?:\.|$)/.test(n) && n !== '.env.example'), 'Credential file prohibited');
}
function network() {
  const telemetry = { blocked: 0, allowedLoopback: 0 };
  const deny = () => { telemetry.blocked++; throw Object.assign(new Error('MEDIA_NETWORK_BLOCKED'), { code: 'MEDIA_NETWORK_BLOCKED' }); };
  const address = (host, port) => {
    if (host !== '127.0.0.1' || ![5000, 27017].includes(Number(port))) return deny();
    telemetry.allowedLoopback++;
  };
  const net = require('node:net'); const originalConnect = net.Socket.prototype.connect;
  net.Socket.prototype.connect = function (...args) {
    // Node internally normalizes arguments into [options, callback].
    const arg = Array.isArray(args[0]) ? args[0][0] : args[0];
    const options = typeof arg === 'object' ? arg : { port: arg, host: typeof args[1] === 'string' ? args[1] : undefined };
    if (options.path) return deny();
    address(options.host, options.port);
    return Reflect.apply(originalConnect, this, args);
  };
  const dns = require('node:dns');
  const lookup = dns.lookup;
  dns.lookup = function (host, ...args) { if (host !== '127.0.0.1') return deny(); return lookup.call(this, host, ...args); };
  for (const key of Object.keys(dns)) if (/^resolve|^reverse/.test(key) && typeof dns[key] === 'function') dns[key] = deny;
  for (const key of Object.keys(dns.promises)) if (/^resolve|^reverse|^lookup/.test(key) && typeof dns.promises[key] === 'function') dns.promises[key] = deny;
  const tls = require('node:tls'); tls.connect = deny;
  const https = require('node:https'); https.request = deny; https.get = deny;
  const http = require('node:http'); const request = http.request;
  http.request = function (...args) {
    const first = args[0];
    if (typeof first === 'string' || first instanceof URL) {
      const url = new URL(first); if (url.protocol !== 'http:' || url.hostname !== '127.0.0.1') return deny(); address(url.hostname, url.port || 80);
    } else address(first.hostname || first.host, first.port || 80);
    return Reflect.apply(request, this, args);
  };
  http.get = function (...args) { const req = http.request(...args); req.end(); return req; };
  const fetch = globalThis.fetch;
  globalThis.fetch = function (input, options) {
    const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url);
    if (url.origin !== BASE || options?.redirect !== 'error') return deny();
    return fetch(input, options);
  };
  return telemetry;
}
function isolatedLinux() {
  assert.equal(process.env.VOCLE_MEDIA_NETWORK_NONE, 'true', 'Hosted runner requires network-none container');
  assert.equal(process.platform, 'linux');
  assert.deepEqual(fs.readdirSync('/sys/class/net').sort(), ['lo'], 'Non-loopback interface present');
  assert.equal(fs.readFileSync('/proc/net/route', 'utf8').trim().split('\n').length, 1, 'External route present');
  return { interfaces: ['lo'], externalRoutes: 0 };
}
function contained(root, target) {
  root = path.resolve(root); target = path.resolve(target);
  assert.ok(target.startsWith(root + path.sep), 'Cleanup path outside scratch root');
  let current = target;
  while (current !== root) { if (fs.existsSync(current)) assert.ok(!fs.lstatSync(current).isSymbolicLink(), 'Cleanup symlink prohibited'); current = path.dirname(current); }
  assert.ok(!fs.lstatSync(root).isSymbolicLink()); return target;
}
module.exports = { BASE, URI, JWT, environment, network, isolatedLinux, contained };
