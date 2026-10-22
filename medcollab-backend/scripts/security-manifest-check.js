'use strict';
// Static checks only: no database, backend, environment loading or provider calls.
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const path = require('node:path');
const manifest = JSON.parse(execFileSync(process.execPath, [path.join(__dirname, 'security-api-discovery.js'), '--list'], { encoding: 'utf8' }));
const legacyHash = createHash('sha256').update(JSON.stringify(manifest.cases.slice(0, 386))).digest('hex');
assert.equal(legacyHash, 'b49518c4912a86fa5740f2bf821d366cce17796e416a0c416424da99b3f9e07c', 'Original 386 positions/expectations changed; preserve history or document a deliberate migration');
assert.equal(createHash('sha256').update(JSON.stringify(manifest.cases.slice(0, 626))).digest('hex'), '930cbf247fe79457b21bcbe35ce6eec2da91813e99765efcc92b4fa39a5e4d1b', 'Verified 626-case baseline must remain unchanged');
assert.equal(manifest.count, manifest.cases.length);
const names = new Set();
for (const test of manifest.cases.slice(386)) {
  const key = `${test.name}|${test.actor}`;
  assert.ok(!names.has(key), `Duplicate appended case: ${key}`); names.add(key);
  assert.ok(test.statuses.length && test.statuses.every(status => status >= 200 && status <= 599));
  if (test.statuses.some(status => status < 400)) assert.ok(test.hasSemanticCheck, `Missing positive persistence/identity check: ${key}`);
  if (test.endpoint !== '[dynamic endpoint]') assert.ok(test.endpoint.startsWith('/api/') || ['/', '/api', '/health', '/socket.io/'].includes(test.endpoint) || test.endpoint.startsWith('/join/'));
}
console.log(`Manifest valid: ${manifest.count} cases; verified 626 unchanged; ${manifest.count - 626} new append-only cases.`);
