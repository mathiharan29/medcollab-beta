'use strict';
// Tests production Express configuration without supplying provider credentials
// required by src/server.js. Routes, auth, models and socket server are unchanged.
const assert = require('node:assert/strict');
assert.equal(process.env.VOCLE_SECURITY_CONFIGURATION_PROBE, 'disposable-local-only');
assert.equal(process.env.MONGODB_URI, 'mongodb://127.0.0.1:27017/vocle_ci');
assert.equal(process.env.PORT, '5102');
assert.equal(process.env.OTP_BYPASS, 'false');
assert.equal(process.env.JWT_SECRET, 'ci-test-only-jwt-secret-not-for-production-0000000000000001');
for (const key of ['CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET', 'MSG91_AUTH_KEY', 'MSG91_TEMPLATE_ID', 'FIREBASE_PROJECT_ID', 'FIREBASE_CLIENT_EMAIL', 'FIREBASE_PRIVATE_KEY']) assert.ok(!process.env[key]);
const mongoose = require('mongoose');
const server = require('node:http').createServer(require('../../src/app'));
require('../../src/socket').initSocket(server);
mongoose.connect(process.env.MONGODB_URI, { serverSelectionTimeoutMS: 10000 }).then(() => server.listen(5102, '127.0.0.1')).catch(() => process.exit(1));
process.on('SIGTERM', () => server.close(() => mongoose.disconnect().then(() => process.exit(0))));
