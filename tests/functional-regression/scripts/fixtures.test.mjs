import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { createIdentity, users } from '../src/fixtures.mjs';
import { executeCases } from '../src/runner.mjs';

test('all literal backend identity references have unique synthetic phone fixtures', async () => {
  const suites = new URL('../suites/', import.meta.url);
  for (const file of await readdir(suites)) {
    if (!file.endsWith('.mjs')) continue;
    const source = await readFile(new URL(file, suites), 'utf8');
    for (const match of source.matchAll(/\bidentity\(['"]([^'"]+)['"]\)/g)) {
      assert.ok(Object.hasOwn(users, match[1]), `${file}: missing ${match[1]}`);
    }
  }
  assert.equal(new Set(Object.values(users).map(user => user.phone)).size, Object.keys(users).length);
  assert.notEqual(users.J4A.phone, users.A.phone);
  assert.notEqual(users.J4B.phone, users.B.phone);
});

test('undefined fixture is ERROR while an application assertion remains FAIL', async () => {
  let networkCalls = 0;
  const rows = await executeCases([
    { id: 'missing-fixture', run: () => createIdentity(() => { networkCalls++; }, '', 'UNDEFINED') },
    { id: 'application-failure', run: () => assert.equal('observed', 'required') },
  ], {});
  assert.equal(networkCalls, 0);
  assert.equal(rows[0].status, 'ERROR');
  assert.equal(rows[0].errorCategory, 'FixtureError');
  assert.equal(rows[1].status, 'FAIL');
});
