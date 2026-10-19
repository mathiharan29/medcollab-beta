import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { capturedOtp } from '../src/fixtures.mjs';
import { backendRequire } from '../src/db.mjs';
import { backendRoot } from '../src/config.mjs';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const send = (request, phone) => request('/api/auth/request-otp', { method: 'POST', body: { phone } });
const verify = (request, phone, otp, expectedStatus = 200) => request('/api/auth/verify-otp', { method: 'POST', body: { phone, otp }, expectedStatus });
const wrongCode = (correct) => correct === '000000' ? '999999' : '000000';

const cases = [{
  id: 'FR-AUTH-01', module: 'AUTH',
  run: async ({ request, db, inbox }) => {
    const invalidPhones = [undefined, '12025550106', '+123456', '+1234567890123456'];
    for (const phone of invalidPhones) {
      const body = phone === undefined ? {} : { phone };
      const result = await request('/api/auth/request-otp', { method: 'POST', body, expectedStatus: 400 });
      assert.equal(result.payload.success, false);
    }
    const valid = ['+1234567', '+123456789012345'];
    for (const phone of valid) {
      const result = await request('/api/auth/request-otp', { method: 'POST', body: { phone } });
      assert.equal(result.payload.success, true);
    }
    const invalidCodes = [undefined, '12345', '1234567', 'abcdef'];
    for (const otp of invalidCodes) {
      const body = otp === undefined ? { phone: valid[0] } : { phone: valid[0], otp };
      const result = await request('/api/auth/verify-otp', { method: 'POST', body, expectedStatus: 400 });
      assert.equal(result.payload.success, false);
    }
    await db(async (connection) => {
      const count = await connection.collection('users').countDocuments({ phone: { $in: valid } });
      assert.equal(count, 0, 'Validation boundary requests must not create sessions or users');
    });
    const acceptedCode = await capturedOtp(inbox, valid[0]);
    const verified = await request('/api/auth/verify-otp', { method: 'POST', body: { phone: valid[0], otp: acceptedCode } });
    assert.equal(verified.data.isNewUser, true);
    assert.ok(verified.data.accessToken && verified.data.refreshToken);
    await db(async (connection) => {
      const users = await connection.collection('users').find({ phone: valid[0] }).toArray();
      assert.equal(users.length, 1);
      assert.equal(String(users[0]._id), verified.data.user._id);
    });
  },
}, {
  id: 'FR-AUTH-02', module: 'AUTH',
  run: async ({ request, inbox, db }) => {
    const phone = '+12025550120';
    await send(request, phone);
    const oldCode = await capturedOtp(inbox, phone);
    await send(request, phone);
    const latestCode = await capturedOtp(inbox, phone);
    assert.notEqual(oldCode, latestCode, 'Fixture requires distinct provider codes to test replacement');
    const denied = await verify(request, phone, oldCode, 400);
    assert.equal(denied.payload.success, false);
    await db(async (connection) => {
      const records = await connection.collection('otps').find({ phone }).toArray();
      assert.equal(records.length, 2);
      assert.equal(records.filter((row) => row.isUsed).length, 1, 'Resend must invalidate the old record');
      assert.equal(records.filter((row) => !row.isUsed).length, 1);
      assert.equal(await connection.collection('users').countDocuments({ phone }), 0);
    });
    const accepted = await verify(request, phone, latestCode);
    assert.equal(accepted.data.isNewUser, true);
    await db(async (connection) => {
      const users = await connection.collection('users').find({ phone }).toArray();
      assert.equal(users.length, 1);
      assert.equal(String(users[0]._id), accepted.data.user._id);
      assert.equal(await connection.collection('otps').countDocuments({ phone, isUsed: false }), 0);
    });
  },
}, {
  id: 'FR-AUTH-03', module: 'AUTH',
  run: async ({ request, inbox, db }) => {
    const phone = '+12025550121';
    await send(request, phone);
    const expiredCode = await capturedOtp(inbox, phone);
    await db(async (connection) => {
      const changed = await connection.collection('otps').updateOne({ phone, isUsed: false }, { $set: { expiresAt: new Date(Date.now() - 60_000) } });
      assert.equal(changed.modifiedCount, 1);
    });
    const denied = await verify(request, phone, expiredCode, 400);
    assert.match(denied.payload.message, /expired|not found/i);
    await db(async (connection) => assert.equal(await connection.collection('users').countDocuments({ phone }), 0));
    await send(request, phone);
    const freshCode = await capturedOtp(inbox, phone);
    await db(async (connection) => {
      const active = await connection.collection('otps').find({ phone, isUsed: false }).toArray();
      assert.equal(active.length, 1);
      assert.ok(active[0].expiresAt > new Date());
    });
    const accepted = await verify(request, phone, freshCode);
    await db(async (connection) => {
      const users = await connection.collection('users').find({ phone }).toArray();
      assert.equal(users.length, 1);
      assert.equal(String(users[0]._id), accepted.data.user._id);
    });
  },
}, {
  id: 'FR-AUTH-04', module: 'AUTH',
  run: async ({ request, inbox, db }) => {
    const beforeLimit = '+12025550122';
    await send(request, beforeLimit);
    const code = await capturedOtp(inbox, beforeLimit);
    for (let attempt = 1; attempt <= 2; attempt++) {
      const denied = await verify(request, beforeLimit, wrongCode(code), 400);
      assert.match(denied.payload.message, /incorrect/i);
      await db(async (connection) => {
        const otp = await connection.collection('otps').findOne({ phone: beforeLimit, isUsed: false });
        assert.equal(otp.attempts, attempt);
      });
    }
    const accepted = await verify(request, beforeLimit, code);
    await db(async (connection) => {
      const user = await connection.collection('users').findOne({ phone: beforeLimit });
      assert.equal(String(user?._id), accepted.data.user._id);
    });
    const exhausted = '+12025550123';
    await send(request, exhausted);
    const exhaustedCode = await capturedOtp(inbox, exhausted);
    for (let attempt = 1; attempt <= 3; attempt++) {
      const denied = await verify(request, exhausted, wrongCode(exhaustedCode), 400);
      assert.match(denied.payload.message, attempt === 3 ? /too many/i : /incorrect/i);
    }
    const deniedCorrect = await verify(request, exhausted, exhaustedCode, 400);
    assert.match(deniedCorrect.payload.message, /expired|not found/i);
    await db(async (connection) => {
      assert.equal(await connection.collection('users').countDocuments({ phone: exhausted }), 0);
      const otp = await connection.collection('otps').findOne({ phone: exhausted, isUsed: false });
      assert.equal(otp.attempts, 3);
    });
    await send(request, exhausted);
    const replacement = await capturedOtp(inbox, exhausted);
    const restored = await verify(request, exhausted, replacement);
    assert.equal(restored.data.isNewUser, true);
    await db(async (connection) => assert.equal(await connection.collection('users').countDocuments({ phone: exhausted }), 1));
  },
}, {
  id: 'FR-AUTH-05', module: 'AUTH',
  run: async ({ request, inbox, db }) => {
    for (const [phone, mode] of [['+12025550124', 'timeout'], ['+12025550125', 'reject']]) {
      await writeFile(join(inbox, 'msg91-mode.json'), JSON.stringify({ mode }));
      const denied = await request('/api/auth/request-otp', { method: 'POST', body: { phone }, expectedStatus: 503 });
      assert.equal(denied.payload.success, false);
      await db(async (connection) => {
        assert.equal(await connection.collection('users').countDocuments({ phone }), 0);
        const records = await connection.collection('otps').find({ phone }).toArray();
        assert.equal(records.length, 1, 'Failed delivery should leave a recorded, unapplied OTP attempt');
      });
      await writeFile(join(inbox, 'msg91-mode.json'), JSON.stringify({ mode: 'success' }));
      const retry = await send(request, phone);
      assert.equal(retry.payload.success, true);
      await db(async (connection) => {
        const records = await connection.collection('otps').find({ phone }).toArray();
        assert.equal(records.length, 2);
        assert.equal(records.filter((row) => row.isUsed).length, 1, 'Retry should supersede the failed-send OTP');
        assert.equal(records.filter((row) => !row.isUsed).length, 1);
      });
      const accepted = await verify(request, phone, await capturedOtp(inbox, phone));
      assert.equal(accepted.data.isNewUser, true);
      await db(async (connection) => {
        const users = await connection.collection('users').find({ phone }).toArray();
        assert.equal(users.length, 1);
        assert.equal(String(users[0]._id), accepted.data.user._id);
      });
    }
  },
}, {
  id: 'FR-AUTH-06', module: 'AUTH',
  run: async ({ request, inbox, db }) => {
    const endpoint = '/api/auth/verify-msg91-token';
    const validPhone = '+12025550105';
    const valid = await request(endpoint, { method: 'POST', body: { phone: validPhone, accessToken: 'synthetic-valid-05' } }); // gitleaks:allow -- loopback Msg91 provider sentinel, never an external credential
    assert.ok(valid.data.accessToken && valid.data.refreshToken);
    assert.equal(valid.data.isNewUser, true);
    const me = await request('/api/users/me', { token: valid.data.accessToken });
    assert.equal(me.data.user._id, valid.data.user._id);
    for (const [phone, accessToken, message] of [
      ['+12025550106', 'synthetic-invalid', /invalid token/i],
      ['+12025550106', 'synthetic-mismatch-05', /does not match/i],
      ['+12025550107', 'synthetic-provider-failure', /provider unavailable/i],
    ]) {
      const denied = await request(endpoint, { method: 'POST', body: { phone, accessToken }, expectedStatus: 400 });
      assert.equal(denied.payload.success, false);
      assert.match(denied.payload.message, message);
    }
    await db(async (connection) => {
      assert.equal(await connection.collection('users').countDocuments({ phone: validPhone }), 1);
      assert.equal(await connection.collection('users').countDocuments({ phone: { $in: ['+12025550106', '+12025550107'] } }), 0);
    });
    const calls = (await readFile(join(inbox, 'widget-inbox.ndjson'), 'utf8')).trim().split(/\r?\n/).map((line) => JSON.parse(line));
    for (const token of ['synthetic-valid-05', 'synthetic-invalid', 'synthetic-mismatch-05', 'synthetic-provider-failure']) {
      assert.ok(calls.some((call) => call.token === token), `Provider fake did not receive ${token}`);
    }
  },
}, {
  id: 'FR-AUTH-07', module: 'AUTH',
  run: async ({ identity, request, inbox, db }) => {
    const a = await identity('A');
    const jwt = backendRequire(backendRoot)('jsonwebtoken');
    const expired = jwt.sign({ userId: a.userId }, 'synthetic-refresh-secret-00000000000000000000000000000002', { expiresIn: -1 });
    const denied = await request('/api/auth/refresh', { method: 'POST', body: { refreshToken: expired }, expectedStatus: 401 });
    assert.equal(denied.payload.success, false);
    assert.match(denied.payload.message, /expired/i);
    await request('/api/auth/request-otp', { method: 'POST', body: { phone: a.phone } });
    const login = await request('/api/auth/verify-otp', { method: 'POST', body: { phone: a.phone, otp: await capturedOtp(inbox, a.phone) } });
    assert.equal(login.data.isNewUser, false);
    assert.equal(login.data.user._id, a.userId);
    const renewed = await request('/api/auth/refresh', { method: 'POST', body: { refreshToken: login.data.refreshToken } });
    assert.ok(renewed.data.accessToken);
    const me = await request('/api/users/me', { token: renewed.data.accessToken });
    assert.equal(me.data.user._id, a.userId);
    await db(async (connection) => {
      const users = await connection.collection('users').find({ phone: a.phone }).toArray();
      assert.equal(users.length, 1);
      assert.equal(String(users[0]._id), a.userId);
    });
  },
}];

// The backend's shared auth limiter spans verify and refresh routes. Each case
// gets a fresh backend so neighboring boundary tests do not consume its quota.
for (const item of cases) await runModule(`auth-${item.id.slice(-2).toLowerCase()}`, [item]);
