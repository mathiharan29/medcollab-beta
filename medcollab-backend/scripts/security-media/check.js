'use strict';
const assert = require('node:assert/strict'); const { createHash } = require('node:crypto'); const fs = require('node:fs'); const path = require('node:path');
const { catalog, manifest } = require('./catalog'); const data = catalog(); const current = manifest(data);
assert.equal(createHash('sha256').update(JSON.stringify(data.baseline.cases)).digest('hex'), '5895e987f820cb0378903c44468101d94c13df82a37480328e64363b557df2ac', 'Verified 691-case manifest changed');
const ids = new Set(), names = new Set(); let next = 692;
for (const test of current.cases) {
  assert.ok(!ids.has(test.caseId)); ids.add(test.caseId);
  assert.ok(!names.has(`${test.name}|${test.actor}`)); names.add(`${test.name}|${test.actor}`);
  if (!test.legacy || test.statuses.some(s => s < 400)) assert.ok(test.hasSemanticCheck, 'New/positive media cases require a state/identity/call oracle');
  assert.ok(test.statuses.every(s => s >= 200 && s < 600));
  if (!test.legacy) assert.equal(test.caseId, `VOCLE-${next++}`);
}
const freezePath = path.join(__dirname, 'manifest.json');
if (process.argv.includes('--freeze')) fs.writeFileSync(freezePath, JSON.stringify(current, null, 2) + '\n');
assert.deepEqual(current, JSON.parse(fs.readFileSync(freezePath)), 'Dedicated manifest/IDs/expectations changed');
console.log(`Media manifest: ${current.selectedCount} selected; ${current.combinedCatalogCount - 691} appended; combined catalog ${current.combinedCatalogCount}; original 691 frozen.`);
