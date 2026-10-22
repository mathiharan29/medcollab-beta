'use strict';
// Test entrypoint only: unchanged Express routes, auth, controllers and models.
const assert = require('node:assert/strict');
const path = require('node:path');
const Module = require('node:module');
const guard = require('./guard'); guard.environment();
assert.ok(['local', 'contract'].includes(process.env.VOCLE_MEDIA_MODE));
const telemetry = guard.network();
const double = require('./sdk-double')();
const load = Module._load; let interceptions = 0;
Module._load = function (request, ...args) {
  if (request === 'cloudinary' || /cloudinary[\\/]lib/.test(request)) { interceptions++; return { v2: double.sdk }; }
  return Reflect.apply(load, this, [request, ...args]);
};
const config = require('../../src/config/cloudinary');
assert.equal(config.cloudinary, double.sdk); assert.equal(config.isCloudinaryConfigured(), false);
// Only override the configuration predicate, since credentials are prohibited.
// Real config code and SDK import were loaded above; all business logic is real.
if (process.env.VOCLE_MEDIA_MODE === 'contract') config.isCloudinaryConfigured = () => true;
const mongoose = require('mongoose');
const server = require('node:http').createServer(require('../../src/app'));
require('../../src/socket').initSocket(server);
const invariant = () => {
  assert.equal(config.cloudinary, double.sdk);
  assert.ok(interceptions > 0);
  assert.ok(!Object.keys(require.cache).some(p => /node_modules[\\/]cloudinary[\\/]/.test(p)), 'Real SDK loaded');
  assert.equal(telemetry.blocked, 0, 'Backend attempted blocked networking');
  assert.equal(double.state().forbidden, 0, 'Unexpected SDK boundary method');
};
process.on('message', async message => {
  try {
    if (message.action === 'state') { invariant(); process.send({ id: message.id, state: double.state(), safety: { sdkReplaced: true, realSdkLoaded: false, configurationPredicateOverride: process.env.VOCLE_MEDIA_MODE === 'contract', network: telemetry } }); }
    else if (message.action === 'fault') { double.fault(message.value); process.send({ id: message.id, ok: true }); }
    else throw new Error('Unknown IPC command');
  } catch { process.send({ id: message.id, failure: true }); }
});
mongoose.connect(guard.URI, { serverSelectionTimeoutMS: 10000 }).then(() => server.listen(5000, '127.0.0.1', () => { invariant(); process.send({ ready: true, sdkReplaced: true }); })).catch(() => process.exit(1));
process.on('SIGTERM', () => server.close(() => mongoose.disconnect().then(() => process.exit(0))));
process.on('uncaughtException', () => process.exit(2));
process.on('unhandledRejection', () => process.exit(3));
