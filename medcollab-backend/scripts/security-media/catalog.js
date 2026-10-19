'use strict';
const { execFileSync } = require('node:child_process');
const path = require('node:path'); const assert = require('node:assert/strict'); const { createHash } = require('node:crypto');
const { ids } = require('./fixtures');
function catalog() {
  const baseline = JSON.parse(execFileSync(process.execPath, [path.resolve(__dirname, '../security-api-discovery.js'), '--list'], { encoding: 'utf8' }));
  assert.equal(baseline.count, 691, 'The verified baseline must not be changed by this dedicated phase');
  const cases = [];
  const legacyAdd = (name, actor, method, endpoint, statuses, body, options = {}) => {
    const index = baseline.cases.findIndex(c => c.name === name && c.actor === actor && c.method === method);
    assert.ok(index >= 0); assert.deepEqual(statuses, baseline.cases[index].statuses);
    cases.push({ name, actor, method, endpoint, statuses, body, ...options, mode: 'local', caseId: `VOCLE-${index + 1}`, legacy: true });
  };
  require('../security/suites/media')({ add: legacyAdd, ids });
  let count = 691;
  const add = (name, actor, method, endpoint, statuses, body, options) => cases.push({ name, actor, method, endpoint, statuses, body, ...options, caseId: `VOCLE-${++count}`, legacy: false });
  require('./local-cases')({ add, ids }); require('./contract-cases')({ add, ids });
  return { baseline, cases, count };
}
const manifest = data => ({ baselineCount: 691, combinedCatalogCount: data.count, selectedCount: data.cases.length, cases: data.cases.map(c => ({ caseId: c.caseId, name: c.name, actor: c.actor, method: c.method, endpoint: typeof c.endpoint === 'string' ? c.endpoint : '[dynamic endpoint]', statuses: c.statuses, mode: c.mode, module: c.module, legacy: c.legacy, hasSemanticCheck: typeof c.check === 'function', hasPreparation: typeof c.prepare === 'function' })) });
module.exports = { catalog, manifest };
