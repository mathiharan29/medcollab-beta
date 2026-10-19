'use strict';
const assert = require('node:assert/strict');
const supervise = require('../local-supervisor');
module.exports = ({ add, authPhones }) => {
  const reg = (name, actor, endpoint, statuses, options) => add(name, actor, 'POST', endpoint, statuses, undefined, {
    module: 'Optional Authentication Hardening', category: 'auth-hardening', sources: ['src/features/auth/auth.controller.js', 'src/features/auth/otp.model.js', 'src/middleware/auth.js'], ...options,
  });
  reg('concurrent OTP consumption issues at most one session', 'anonymous', '/api/auth/verify-otp', [200], {
    securityInvariant: 'A single stored OTP may issue at most one authenticated session across simultaneous valid verification requests.',
    failureClassification: 'OTP single-consumption regression observation',
    run: async c => {
      const p = await supervise(c); const user = await c.models.User.create({ phone: authPhones[0], isVerified: true });
      await c.models.OTP.createOtp(authPhones[0], '246810');
      const responses = await Promise.all([1, 2].map(() => p.http('anonymous', 'POST', '/api/auth/verify-otp', { phone: authPhones[0], otp: '246810' })));
      assert.ok(responses.every(r => r.status !== 429), 'Auth limiter prevented concurrency execution');
      const issued = responses.filter(r => r.status === 200 && typeof r.data?.data?.accessToken === 'string');
      assert.ok(issued.length > 0, 'Concurrent OTP positive control absent');
      const controls = await Promise.all(issued.map(r => p.http('anonymous', 'GET', '/api/users/me', undefined, `Bearer ${r.data.data.accessToken}`)));
      assert.ok(controls.every(r => r.status === 200 && r.data?.data?.user?._id === String(user._id)), 'Issued session identity control failed');
      const replay = await p.http('anonymous', 'POST', '/api/auth/verify-otp', { phone: authPhones[0], otp: '246810' });
      c.evidence = { concurrentStatuses: responses.map(r => r.status), usableSessionResponses: issued.length, identityControls: controls.length, sequentialReplayStatus: replay.status, storedOtpsAfter: await c.models.OTP.countDocuments({ phone: authPhones[0] }), concurrency: 'two overlapping real HTTP requests; no handler interception' };
      return { status: 200, data: { success: true } };
    }, check: (_, c) => c.evidence.usableSessionResponses === 1 && c.evidence.concurrentStatuses.every(s => [200, 400].includes(s)) && c.evidence.sequentialReplayStatus === 400 && c.evidence.storedOtpsAfter === 0,
  });
  reg('refresh for genuinely deleted synthetic account is rejected', 'anonymous', '/api/auth/refresh', [401], {
    prepare: async c => {
      const user = await c.models.User.create({ phone: authPhones[0], isVerified: true });
      c.deletedRefresh = require('jsonwebtoken').sign({ userId: String(user._id) }, process.env.JWT_REFRESH_SECRET, { expiresIn: 60 });
      const control = await c.supervisedHttp('model-otp-extra', 'POST', '/api/auth/refresh', { refreshToken: c.deletedRefresh }); assert.equal(control.status, 200);
      await c.models.User.deleteOne({ _id: user._id }); c.evidence.existedAndRefreshedBeforeDeletion = true;
    }, run: c => c.supervisedHttp('model-otp-extra', 'POST', '/api/auth/refresh', { refreshToken: c.deletedRefresh }),
    check: body => !body.data?.accessToken,
  });
  for (const variant of ['omitted', 'unknown']) reg(`logout ${variant} FCM token preserves registrations`, 'A', '/api/auth/logout', [200], {
    prepare: async c => { await c.models.User.updateOne({ _id: c.users.A._id }, { fcmTokens: ['ci-owned-one', 'ci-owned-two'] }); },
    body: variant === 'omitted' ? {} : { fcmToken: 'ci-unregistered-token' },
    securityInvariant: 'Logout without a matching FCM token may succeed but cannot remove other device registrations.',
    check: async (_, c) => JSON.stringify((await c.models.User.findById(c.users.A._id)).fcmTokens) === JSON.stringify(['ci-owned-one', 'ci-owned-two']),
  });
  reg('expired access token cannot deregister logout device', 'anonymous', '/api/auth/logout', [401], {
    prepare: async c => { await c.models.User.updateOne({ _id: c.users.A._id }, { fcmTokens: ['ci-owned-one'] }); },
    run: c => c.http('anonymous', 'POST', '/api/auth/logout', { fcmToken: 'ci-owned-one' }, `Bearer ${require('jsonwebtoken').sign({ userId: String(c.users.A._id) }, process.env.JWT_SECRET, { expiresIn: -1 })}`),
    check: async (_, c) => (await c.models.User.findById(c.users.A._id)).fcmTokens[0] === 'ci-owned-one',
  });
};
