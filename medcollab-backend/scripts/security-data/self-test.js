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
