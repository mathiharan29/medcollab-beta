'use strict';
const fs = require('node:fs'); const path = require('node:path'); const assert = require('node:assert/strict'); const { createHash } = require('node:crypto');
const { manifest } = require('./cases'); const { directory, requireSafe } = require('./guard');
const file = path.join(__dirname, 'manifest.json');
if (process.argv.includes('--freeze')) fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + '\n');
assert.deepEqual(manifest, JSON.parse(fs.readFileSync(file)), 'Real-provider IDs/expectations changed');
assert.equal(new Set(manifest.cases.map(c => c.name)).size, manifest.count);
manifest.cases.forEach((c, i) => { assert.equal(c.caseId, `VOCLE-${752 + i}`); assert.ok(c.expected && c.category); });
const baseline = fs.readFileSync(path.join(__dirname, '../security-media/manifest.json'));
assert.equal(createHash('sha256').update(baseline).digest('hex'), '8214a4c52aa44f30d87f013215f07c5b5397e489b77c786fa3a1b73bee255065');
if (process.argv.includes('--artifacts')) {
  const dir = directory(); requireSafe(fs.existsSync(dir), 'NO_SANITIZED_EVIDENCE');
  const permitted = ['safety.json', 'resources.json', 'cleanup.json', 'post-job-cleanup.json', 'results.json', 'manifest.json', 'summary.md', 'security-test-report.md'];
  for (const name of fs.readdirSync(dir)) {
    requireSafe(permitted.includes(name), 'UNAPPROVED_ARTIFACT');
    const text = fs.readFileSync(path.join(dir, name), 'utf8');
    for (const secret of [process.env.CLOUDINARY_CLOUD_NAME, process.env.CLOUDINARY_API_KEY, process.env.CLOUDINARY_API_SECRET]) requireSafe(!secret || !text.includes(secret), 'REPORT_SECRET_LEAK');
    requireSafe(!/"(api_key|api_secret|authorization|signature)"\s*:/i.test(text), 'REPORT_CREDENTIAL_FIELD');
  }
  console.log('Artifact hygiene passed; no credential values or signed payloads preserved.');
} else console.log(`Real-provider manifest: ${manifest.count} cases, VOCLE-752–${751 + manifest.count}; catalog ${manifest.combinedCatalogCount}. Original offline manifest pinned.`);
