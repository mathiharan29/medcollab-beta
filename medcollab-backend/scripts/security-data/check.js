'use strict';
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { manifest } = require('./cases');
const file = path.join(__dirname, 'manifest.json');
if (process.argv.includes('--freeze')) fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + '\n');
assert.deepEqual(manifest, JSON.parse(fs.readFileSync(file)), 'Data testcase IDs/expectations changed');
manifest.cases.forEach((c, i) => { assert.equal(c.caseId, `VOCLE-${786 + i}`); assert.ok(c.expected && c.scope && c.sources.length); });
assert.equal(new Set(manifest.cases.map(c => c.name)).size, manifest.count);
const previous = fs.readFileSync(path.join(__dirname, '../security-cloudinary/manifest.json'));
// Pinned in baseline.json; only append to the historical 785-case catalog.
assert.equal(createHash('sha256').update(previous).digest('hex'), JSON.parse(fs.readFileSync(path.join(__dirname, 'baseline.json'))).cloudinaryManifestSha256);
if (process.argv.includes('--artifacts')) {
  const dir = path.join(process.env.RUNNER_TEMP, 'vocle-data-results');
  assert.deepEqual(fs.readdirSync(dir).sort(), ['manifest.json', 'results.json', 'summary.md']);
  for (const name of fs.readdirSync(dir)) {
    const contents = fs.readFileSync(path.join(dir, name), 'utf8');
    assert.ok(!/"(?:otpHash|fcmTokens|authorization|accessToken|refreshToken|phone)"\s*:/i.test(contents), 'Sensitive data field in artifact');
    assert.ok(!/\$2[ab]\$\d\d\$[./A-Za-z0-9]{53}/.test(contents), 'Hash value in artifact');
    assert.ok(!contents.includes(require('../security-media/guard').JWT));
  }
  const r = JSON.parse(fs.readFileSync(path.join(dir, 'results.json')));
  if (!r.infrastructureFailure) { assert.equal(r.executed, manifest.count); assert.ok(r.results.every(x => x.cleanup?.residualDocuments === 0)); assert.equal(r.sourceBefore, r.sourceAfter); }
  console.log('Data artifact hygiene and completeness passed');
} else console.log(`Data manifest: ${manifest.count} cases; catalog ${manifest.combinedCatalogCount}`);
