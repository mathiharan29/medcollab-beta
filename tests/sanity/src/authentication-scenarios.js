import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { latestOtp } from './fake-inbox.js';
import { request, expectSuccess } from './http.js';
import { closeDatabase, connectDatabase, newestOtp, userByPhone } from './database.js';

const users = Object.freeze({ A: '+12025550101', B: '+12025550102', E: '+12025550105' });
const results = [];
const assert = (condition, message) => { if (!condition) throw new Error(message); };

async function requestOtp(phone) {
  return expectSuccess(await request('/api/auth/request-otp', { method: 'POST', body: { phone } }), `request OTP for ${phone}`);
}

async function verifyOtp(phone, otp, expectedStatus = 200) {
  const payload = await request('/api/auth/verify-otp', { method: 'POST', body: { phone, otp }, expectedStatus });
  return expectedStatus === 200 ? expectSuccess(payload, `verify OTP for ${phone}`) : payload;
}

async function scenario(id, action) {
  const startedAt = Date.now();
  try {
    await action();
    results.push({ id, status: 'passed', durationMs: Date.now() - startedAt });
  } catch (error) {
    results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message });
    throw error;
  }
}

async function run() {
  await connectDatabase();
  let firstAuth;
  let firstOtp;
  try {
    await scenario('authentication-and-profiles-01', async () => {
      await requestOtp(users.A);
      const stored = await newestOtp(users.A);
      assert(stored?.otpHash && !/^\d{6}$/.test(stored.otpHash), 'OTP was not stored as a hash.');
      firstOtp = await latestOtp(users.A);
      firstAuth = await verifyOtp(users.A, firstOtp);
      assert(firstAuth.accessToken && firstAuth.refreshToken && firstAuth.isNewUser === true, 'First verification did not create usable tokens.');
      const persisted = await userByPhone(users.A);
      assert(persisted?.isVerified === true, 'Verified user was not persisted.');
    });

    await scenario('authentication-and-profiles-02', async () => {
      await requestOtp(users.A);
      const auth = await verifyOtp(users.A, await latestOtp(users.A));
      assert(auth.isNewUser === false && auth.user._id === firstAuth.user._id, 'Returning login did not preserve identity.');
    });

    await scenario('authentication-and-profiles-03', async () => {
      await requestOtp(users.B);
      const otp = await latestOtp(users.B);
      await verifyOtp(users.B, '000000', 400);
      const auth = await verifyOtp(users.B, otp);
      assert(auth.accessToken, 'Correct OTP did not work after an incorrect attempt.');
    });

    await scenario('authentication-and-profiles-04', async () => {
      await verifyOtp(users.A, firstOtp, 400);
    });

    await scenario('authentication-and-profiles-05', async () => {
      const update = expectSuccess(await request('/api/users/me', {
        method: 'PUT', token: firstAuth.accessToken,
        body: { name: 'Dr Sanity A', institution: 'Vocle Sanity Institute', speciality: 'Sanity Medicine' },
      }), 'onboard profile');
      assert(update.user.isOnboarded === true, 'Profile update did not unlock onboarding.');
      const me = expectSuccess(await request('/api/users/me', { token: firstAuth.accessToken }), 'read updated profile');
      assert(me.user.name === 'Dr Sanity A' && me.user.institution === 'Vocle Sanity Institute', 'Profile changes did not persist.');
    });

    await scenario('authentication-and-profiles-06', async () => {
      await request('/api/auth/refresh', { method: 'POST', body: {}, expectedStatus: 401 });
      const refreshed = expectSuccess(await request('/api/auth/refresh', { method: 'POST', body: { refreshToken: firstAuth.refreshToken } }), 'refresh token');
      assert(refreshed.accessToken, 'Refresh did not issue an access token.');
      expectSuccess(await request('/api/users/me', { token: refreshed.accessToken }), 'use refreshed access token');
    });

    await scenario('authentication-and-profiles-07', async () => {
      const device = 'sanity-device-token-a';
      await request('/api/users/me/fcm-token', { method: 'PUT', token: firstAuth.accessToken, body: { token: device } });
      await request('/api/users/me/fcm-token', { method: 'PUT', token: firstAuth.accessToken, body: { token: device } });
      assert((await userByPhone(users.A)).fcmTokens.filter((value) => value === device).length === 1, 'FCM registration was not deduplicated.');
      await request('/api/auth/logout', { method: 'POST', token: firstAuth.accessToken, body: { fcmToken: device } });
      assert(!(await userByPhone(users.A)).fcmTokens.includes(device), 'Logout did not remove the registered device.');
      const widget = expectSuccess(await request('/api/auth/verify-msg91-token', {
        method: 'POST', body: { phone: users.E, accessToken: 'opaque-sanity-widget-token' },
      }), 'widget verification');
      assert(widget.accessToken, 'Widget verification did not issue an access token.');
    });
  } finally {
    await closeDatabase();
  }
  const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output');
  await mkdir(output, { recursive: true });
  await writeFile(resolve(output, 'authentication-results.json'), `${JSON.stringify({ expected: 7, results }, null, 2)}\n`);
  console.log('Authentication scenarios passed: 7/7.');
}

run().catch(async (error) => {
  console.error(error.stack || error.message);
  await closeDatabase();
  process.exitCode = 1;
});
