'use strict';
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const guard = require('../security-media/guard');
const clean = { NODE_ENV: 'test', MONGODB_URI: guard.URI, API_BASE_URL: guard.BASE, JWT_SECRET: guard.JWT };
guard.environment(clean, []);
for (const override of [{ NODE_ENV: 'production' }, { MONGODB_URI: 'mongodb+srv://synthetic.invalid/vocle_ci' }, { MONGODB_URI: 'mongodb://127.0.0.1:27017/production' }, { CLOUDINARY_API_KEY: 'dummy' }, { FIREBASE_PROJECT_ID: 'dummy' }, { MSG91_AUTH_KEY: 'dummy' }, { HTTPS_PROXY: 'https://synthetic.invalid' }]) assert.throws(() => guard.environment({ ...clean, ...override }, []));
for (const action of ["require('node:net').connect(27017, 'synthetic.invalid')", "require('node:https').get('https://synthetic.invalid')", "require('node:dns').lookup('synthetic.invalid')", "fetch('https://synthetic.invalid')"]) {
  const r = spawnSync(process.execPath, ['-e', `const g=require(${JSON.stringify(require.resolve('../security-media/guard'))});const t=g.network();let denied=false;try{${action}}catch(e){denied=e.code==='MEDIA_NETWORK_BLOCKED'}if(!denied||t.blocked!==1)process.exit(1);`], { encoding: 'utf8' });
  assert.equal(r.status, 0, 'External operation must fail before I/O');
}
console.log('Data guard: exact disposable URI, credential/proxy rejection and external transport denials passed');

// Index conflicts are application evidence, not a reason to rewrite indexes or
// hide database connectivity failures. Verify both paths without a live DB.
(async () => {
  const { initializeIndexes } = require('./fixtures');
  let queried = 0;
  const model = code => ({ countDocuments: async () => 0, init: async () => { throw Object.assign(new Error('synthetic'), { code }); }, collection: { indexes: async () => { queried++; return [{ name: '_id_' }]; } } });
  const conflicts = await initializeIndexes({ Space: model(86) });
  assert.equal(conflicts.length, 1); assert.equal(conflicts[0].category, 'APPLICATION_INDEX_CONFLICT');
  assert.equal(queried, 1);
  await assert.rejects(initializeIndexes({ Space: model(6) }), error => error.code === 6);
  const unavailable = model(86); unavailable.collection.indexes = async () => { throw new Error('unavailable'); };
  await assert.rejects(initializeIndexes({ Space: unavailable }), /unavailable/);
  console.log('Data index initialization: application conflicts preserved; connectivity failures remain fatal');
})().catch(error => { console.error(error); process.exitCode = 1; });
