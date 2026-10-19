'use strict';

const assert = require('node:assert/strict');

// Phase 1 auth/session cases. OTP lifecycle cases deliberately target a
// separately supervised, OTP_BYPASS=false loopback backend. The raw OTP and
// fabricated widget token values remain inside this process and are never
// copied into result metadata or reports.
module.exports = ({ add, authPhones }) => {
  const [primaryPhone, inactivePhone, widgetPhone] = authPhones;
  const authSources = [
    'src/features/auth/auth.routes.js',
    'src/features/auth/auth.controller.js',
    'src/services/otp.service.js',
    'src/features/auth/otp.model.js',
    'src/middleware/auth.js',
    'src/middleware/rateLimiter.js',
  ];
  const widgetSources = [...authSources, 'src/services/msg91Widget.service.js'];
  const widgetToken = (phone, claims = {}) => {
    const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
    return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({ phone, ...claims })}.fabricated-signature`;
  };
  const supervised = (batch, endpoint, body) => async (ctx) => ctx.supervisedHttp(batch, 'POST', endpoint, body);
  const noTokenIssued = (body) => !body?.data?.accessToken && !body?.data?.refreshToken;

  add('MSG91 widget fabricated signature cannot issue a session', 'anonymous', 'POST', '/api/auth/verify-msg91-token', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-widget-unverified-token', sources: widgetSources,
    context: 'A dummy non-secret widget key is present only in the disposable supervised process; the JWT-shaped token has no valid signature.',
    run: supervised('widget-dummy', '/api/auth/verify-msg91-token', { phone: widgetPhone, accessToken: widgetToken(widgetPhone) }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.User.countDocuments({ phone: widgetPhone })) === 0,
  });
  add('MSG91 widget expired fabricated token cannot issue a session', 'anonymous', 'POST', '/api/auth/verify-msg91-token', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-widget-unverified-token', sources: widgetSources,
    context: 'A dummy-key, expired JWT-shaped token is submitted to the supervised loopback process.',
    run: supervised('widget-dummy', '/api/auth/verify-msg91-token', { phone: widgetPhone, accessToken: widgetToken(widgetPhone, { exp: 1 }) }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.User.countDocuments({ phone: widgetPhone })) === 0,
  });
  add('MSG91 widget body phone must match verified identity', 'anonymous', 'POST', '/api/auth/verify-msg91-token', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-widget-phone-binding', sources: widgetSources,
    context: 'The supplied body phone differs from the fabricated token identity in a dummy-key supervised process.',
    run: supervised('widget-dummy', '/api/auth/verify-msg91-token', { phone: primaryPhone, accessToken: widgetToken(widgetPhone) }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.User.countDocuments({ phone: { $in: [primaryPhone, widgetPhone] } })) === 0,
  });
  add('MSG91 widget missing key rejects fabricated identity locally', 'anonymous', 'POST', '/api/auth/verify-msg91-token', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-widget-credential-guard', sources: widgetSources,
    context: 'No MSG91 key is present; the test must fail without provider fallback or local token issuance.',
    run: supervised('credential-free', '/api/auth/verify-msg91-token', { phone: widgetPhone, accessToken: widgetToken(widgetPhone) }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.User.countDocuments({ phone: widgetPhone })) === 0,
  });
  add('MSG91 widget malformed token rejects without provider session', 'anonymous', 'POST', '/api/auth/verify-msg91-token', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-widget-malformed-input', sources: widgetSources,
    context: 'No MSG91 key is present and the input is an opaque malformed token.',
    run: supervised('credential-free', '/api/auth/verify-msg91-token', { phone: widgetPhone, accessToken: 'not-a-jwt' }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.User.countDocuments({ phone: widgetPhone })) === 0,
  });

  add('request OTP bypass process stores hash without exposing code', 'anonymous', 'POST', '/api/auth/request-otp', [200], { phone: primaryPhone }, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-request-bypass', sources: authSources,
    context: 'The existing fixture-auth process has OTP_BYPASS=true; this case checks request storage and response minimization only, not OTP verification semantics.',
    check: async (body, ctx) => {
      const otp = await ctx.models.OTP.findOne({ phone: primaryPhone }).lean();
      return !!otp?.otpHash && otp.otpHash !== '123456' && !JSON.stringify(body).includes('123456');
    },
  });
  add('request OTP repeat invalidates prior record', 'anonymous', 'POST', '/api/auth/request-otp', [200], { phone: primaryPhone }, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-request-replay', sources: authSources,
    context: 'Two bypass-mode requests use one reserved synthetic phone; only the latest record may remain usable.',
    prepare: async (ctx) => { const first = await ctx.http('anonymous', 'POST', '/api/auth/request-otp', { phone: primaryPhone }); assert.equal(first.status, 200); },
    check: async (_body, ctx) => {
      const records = await ctx.models.OTP.find({ phone: primaryPhone }).sort({ createdAt: 1 }).lean();
      return records.length === 2 && records.filter(record => !record.isUsed).length === 1 && records.filter(record => record.isUsed).length === 1;
    },
  });
  add('request OTP credential-free process fails safely', 'anonymous', 'POST', '/api/auth/request-otp', [503], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-provider-guard', sources: authSources,
    context: 'OTP_BYPASS=false with no SMS credentials. The request may retain a hash for retry, but must not contact a provider or create a user.',
    denialMayChangeState: true,
    run: supervised('credential-free', '/api/auth/request-otp', { phone: primaryPhone }),
    check: async (body, ctx) => {
      const otp = await ctx.models.OTP.findOne({ phone: primaryPhone }).lean();
      return noTokenIssued(body) && !!otp?.otpHash && otp.otpHash.length > 20 && (await ctx.models.User.countDocuments({ phone: primaryPhone })) === 0;
    },
  });
  add('request OTP rejects invalid phone shapes without storage', 'anonymous', 'POST', '/api/auth/request-otp', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-request-validation', sources: authSources,
    context: 'Missing, malformed, array, and object phone values are submitted to the bypass process; validation must run before OTP creation.',
    run: async (ctx) => {
      const attempts = await Promise.all([
        ctx.http('anonymous', 'POST', '/api/auth/request-otp', {}),
        ctx.http('anonymous', 'POST', '/api/auth/request-otp', { phone: 'not-a-phone' }),
        ctx.http('anonymous', 'POST', '/api/auth/request-otp', { phone: [primaryPhone] }),
        ctx.http('anonymous', 'POST', '/api/auth/request-otp', { phone: { value: primaryPhone } }),
      ]);
      ctx.evidence = { allInvalidInputsRejected: attempts.every(attempt => attempt.status === 400) };
      return attempts.at(-1);
    },
    check: async (body, ctx) => noTokenIssued(body) && ctx.evidence.allInvalidInputsRejected && (await ctx.models.OTP.countDocuments({ phone: primaryPhone })) === 0,
  });
  add('request OTP enforces a fresh per-phone limiter without creating a sixth record', 'anonymous', 'POST', '/api/auth/request-otp', [429], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-request-rate-limit', sources: authSources,
    context: 'A fresh OTP_BYPASS=true loopback supervisor submits six requests for one reserved phone to exercise the actual five-request limiter without provider traffic.',
    denialMayChangeState: true,
    run: async (ctx) => {
      const attempts = [];
      for (let index = 0; index < 6; index += 1) attempts.push(await ctx.supervisedHttp('bypass-otp-limiter', 'POST', '/api/auth/request-otp', { phone: primaryPhone }));
      ctx.evidence = { firstFiveAccepted: attempts.slice(0, 5).every(attempt => attempt.status === 200), sixthLimited: attempts[5].status === 429 };
      return attempts[5];
    },
    check: async (body, ctx) => noTokenIssued(body) && ctx.evidence.firstFiveAccepted && ctx.evidence.sixthLimited &&
      (await ctx.models.OTP.countDocuments({ phone: primaryPhone })) === 5 && (await ctx.models.OTP.countDocuments({ phone: primaryPhone, isUsed: false })) === 1 &&
      (await ctx.models.User.countDocuments({ phone: primaryPhone })) === 0,
  });

  add('model-seeded OTP authenticates only its matching phone', 'anonymous', 'POST', '/api/auth/verify-otp', [200], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-model-lifecycle', sources: authSources,
    context: 'OTP_BYPASS=false; a hashed synthetic OTP is seeded through the real model and verified through HTTP.',
    prepare: async (ctx) => { await ctx.models.OTP.createOtp(primaryPhone, '246810'); },
    run: supervised('model-otp', '/api/auth/verify-otp', { phone: primaryPhone, otp: '246810' }),
    check: async (body, ctx) => {
      const token = body?.data?.accessToken;
      if (typeof token !== 'string') return false;
      const me = await ctx.supervisedHttp('model-otp', 'GET', '/api/users/me', undefined, `Bearer ${token}`);
      const user = await ctx.models.User.findOne({ phone: primaryPhone }).lean();
      ctx.evidence = { protectedControl: me.status === 200, matchingFixtureIdentity: me.data?.data?.user?._id === String(user?._id), storedOtpRemoved: (await ctx.models.OTP.countDocuments({ phone: primaryPhone })) === 0 };
      return !!user?.isVerified && ctx.evidence.protectedControl && ctx.evidence.matchingFixtureIdentity && ctx.evidence.storedOtpRemoved;
    },
  });
  add('model-seeded OTP rejects a different phone', 'anonymous', 'POST', '/api/auth/verify-otp', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-phone-binding', sources: authSources,
    context: 'OTP_BYPASS=false; a valid hash belongs to one reserved phone while another is submitted.',
    prepare: async (ctx) => { await ctx.models.OTP.createOtp(primaryPhone, '246810'); },
    run: supervised('model-otp', '/api/auth/verify-otp', { phone: widgetPhone, otp: '246810' }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.OTP.countDocuments({ phone: primaryPhone })) === 1 && (await ctx.models.User.countDocuments({ phone: { $in: [primaryPhone, widgetPhone] } })) === 0,
  });
  add('model OTP verification without a record cannot issue a session', 'anonymous', 'POST', '/api/auth/verify-otp', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-no-issued-record', sources: authSources,
    context: 'OTP_BYPASS=false and no record exists for the reserved phone before the HTTP verification request.',
    run: supervised('model-otp-extra', '/api/auth/verify-otp', { phone: primaryPhone, otp: '246810' }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.OTP.countDocuments({ phone: primaryPhone })) === 0 && (await ctx.models.User.countDocuments({ phone: primaryPhone })) === 0,
  });
  add('model-seeded superseded OTP cannot authenticate', 'anonymous', 'POST', '/api/auth/verify-otp', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-superseded-record', sources: authSources,
    context: 'OTP_BYPASS=false; a second model-created record invalidates the first before the first code is submitted through HTTP.',
    denialMayChangeState: true,
    prepare: async (ctx) => { await ctx.models.OTP.createOtp(primaryPhone, '246810'); await ctx.models.OTP.createOtp(primaryPhone, '135790'); },
    run: supervised('model-otp-extra', '/api/auth/verify-otp', { phone: primaryPhone, otp: '246810' }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.OTP.countDocuments({ phone: primaryPhone, isUsed: true })) === 1 &&
      (await ctx.models.OTP.countDocuments({ phone: primaryPhone, isUsed: false })) === 1 && (await ctx.models.User.countDocuments({ phone: primaryPhone })) === 0,
  });
  add('model-seeded OTP locks after three wrong attempts', 'anonymous', 'POST', '/api/auth/verify-otp', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-attempt-lockout', sources: authSources,
    context: 'OTP_BYPASS=false; three incorrect HTTP submissions must prevent later use of the seeded code.',
    denialMayChangeState: true,
    prepare: async (ctx) => { await ctx.models.OTP.createOtp(primaryPhone, '246810'); },
    run: async (ctx) => {
      await ctx.supervisedHttp('model-otp', 'POST', '/api/auth/verify-otp', { phone: primaryPhone, otp: '000000' });
      await ctx.supervisedHttp('model-otp', 'POST', '/api/auth/verify-otp', { phone: primaryPhone, otp: '000000' });
      return ctx.supervisedHttp('model-otp', 'POST', '/api/auth/verify-otp', { phone: primaryPhone, otp: '000000' });
    },
    check: async (body, ctx) => {
      const replay = await ctx.supervisedHttp('model-otp', 'POST', '/api/auth/verify-otp', { phone: primaryPhone, otp: '246810' });
      const otp = await ctx.models.OTP.findOne({ phone: primaryPhone }).lean();
      return noTokenIssued(body) && replay.status === 400 && noTokenIssued(replay.data) && otp?.attempts === 3 && (await ctx.models.User.countDocuments({ phone: primaryPhone })) === 0;
    },
  });
  add('model-seeded expired OTP cannot create a session', 'anonymous', 'POST', '/api/auth/verify-otp', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-expiry', sources: authSources,
    context: 'OTP_BYPASS=false; expiry is seeded in the past without waiting for TTL.',
    prepare: async (ctx) => { const otp = await ctx.models.OTP.createOtp(primaryPhone, '246810'); await ctx.models.OTP.findByIdAndUpdate(otp._id, { expiresAt: new Date(0) }); },
    run: supervised('model-otp', '/api/auth/verify-otp', { phone: primaryPhone, otp: '246810' }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.User.countDocuments({ phone: primaryPhone })) === 0,
  });
  add('model-seeded OTP replay does not create duplicate users', 'anonymous', 'POST', '/api/auth/verify-otp', [400], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-replay', sources: authSources,
    context: 'OTP_BYPASS=false; the same seeded record is verified once and then replayed through HTTP.',
    denialMayChangeState: true,
    prepare: async (ctx) => { await ctx.models.OTP.createOtp(primaryPhone, '246810'); },
    run: async (ctx) => { const initial = await ctx.supervisedHttp('model-otp', 'POST', '/api/auth/verify-otp', { phone: primaryPhone, otp: '246810' }); assert.equal(initial.status, 200); return ctx.supervisedHttp('model-otp', 'POST', '/api/auth/verify-otp', { phone: primaryPhone, otp: '246810' }); },
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.User.countDocuments({ phone: primaryPhone })) === 1 && (await ctx.models.OTP.countDocuments({ phone: primaryPhone })) === 0,
  });
  add('model-seeded OTP logs an existing controlled account in without onboarding', 'anonymous', 'POST', '/api/auth/verify-otp', [200], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-existing-account', sources: authSources,
    context: 'OTP_BYPASS=false; a reserved verified account already exists before a matching model-seeded code is verified through HTTP.',
    prepare: async (ctx) => { await ctx.models.User.create({ phone: primaryPhone, isVerified: true }); await ctx.models.OTP.createOtp(primaryPhone, '246810'); },
    run: supervised('model-otp-extra', '/api/auth/verify-otp', { phone: primaryPhone, otp: '246810' }),
    check: async (body, ctx) => {
      const token = body?.data?.accessToken;
      const me = typeof token === 'string' ? await ctx.supervisedHttp('model-otp-extra', 'GET', '/api/users/me', undefined, `Bearer ${token}`) : null;
      const user = await ctx.models.User.findOne({ phone: primaryPhone }).lean();
      ctx.evidence = { existingAccount: body?.data?.isNewUser === false, protectedControl: me?.status === 200, matchingFixtureIdentity: me?.data?.data?.user?._id === String(user?._id) };
      return ctx.evidence.existingAccount && ctx.evidence.protectedControl && ctx.evidence.matchingFixtureIdentity && (await ctx.models.User.countDocuments({ phone: primaryPhone })) === 1;
    },
  });
  add('inactive OTP user never has a usable protected session', 'anonymous', 'POST', '/api/auth/verify-otp', [200], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-otp-inactive-user', sources: authSources,
    context: 'OTP_BYPASS=false; an existing reserved identity is inactive before a valid model-seeded verification.',
    prepare: async (ctx) => { await ctx.models.User.create({ phone: inactivePhone, isVerified: true, isActive: false }); await ctx.models.OTP.createOtp(inactivePhone, '246810'); },
    run: supervised('model-otp', '/api/auth/verify-otp', { phone: inactivePhone, otp: '246810' }),
    check: async (body, ctx) => {
      const token = body?.data?.accessToken;
      const me = typeof token === 'string' ? await ctx.supervisedHttp('model-otp', 'GET', '/api/users/me', undefined, `Bearer ${token}`) : null;
      ctx.evidence = { protectedControlRejected: me?.status === 401 };
      return ctx.evidence.protectedControlRejected;
    },
  });

  const refreshToken = (userId, options = {}, secret = process.env.JWT_REFRESH_SECRET) => require('jsonwebtoken').sign({ userId: String(userId) }, secret, { expiresIn: '30m', ...options });
  add('refresh token returns an access token for its own subject', 'anonymous', 'POST', '/api/auth/refresh', [200], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-refresh-subject-binding', sources: authSources,
    context: 'A locally signed disposable refresh token is exchanged in the OTP_BYPASS=false supervised process.',
    run: (ctx) => ctx.supervisedHttp('model-otp', 'POST', '/api/auth/refresh', { refreshToken: refreshToken(ctx.users.A._id) }),
    check: async (body, ctx) => {
      const token = body?.data?.accessToken;
      const me = typeof token === 'string' ? await ctx.supervisedHttp('model-otp', 'GET', '/api/users/me', undefined, `Bearer ${token}`) : null;
      ctx.evidence = { protectedControl: me?.status === 200, subjectMatches: me?.data?.data?.user?._id === String(ctx.users.A._id) };
      return ctx.evidence.protectedControl && ctx.evidence.subjectMatches;
    },
  });
  for (const [label, tokenFor] of [
    ['missing', () => undefined],
    ['wrong-key', (ctx) => refreshToken(ctx.users.A._id, {}, 'ci-refresh-wrong-key')],
    ['expired', (ctx) => refreshToken(ctx.users.A._id, { expiresIn: -1 })],
    ['access-token-as-refresh', (ctx) => require('jsonwebtoken').sign({ userId: String(ctx.users.A._id) }, process.env.JWT_SECRET, { expiresIn: '30m' })],
  ]) {
    add(`refresh token ${label} cannot issue an access token`, 'anonymous', 'POST', '/api/auth/refresh', [401], undefined, {
      module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-refresh-negative', sources: authSources,
      context: 'A disposable supervised process receives a missing, invalid, expired, or wrong token class.',
      run: (ctx) => ctx.supervisedHttp('model-otp', 'POST', '/api/auth/refresh', tokenFor(ctx) ? { refreshToken: tokenFor(ctx) } : {}),
      check: (body) => noTokenIssued(body),
    });
  }
  add('refresh token for inactive user cannot issue an access token', 'anonymous', 'POST', '/api/auth/refresh', [401], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-refresh-inactive-user', sources: authSources,
    context: 'A locally signed refresh token names a controlled identity that is deactivated before the HTTP request.',
    prepare: async (ctx) => { await ctx.models.User.findByIdAndUpdate(ctx.users.A._id, { isActive: false }); },
    run: (ctx) => ctx.supervisedHttp('model-otp', 'POST', '/api/auth/refresh', { refreshToken: refreshToken(ctx.users.A._id) }),
    check: (body) => noTokenIssued(body),
  });
  add('refresh ignores forged body identity and keeps refresh subject binding', 'anonymous', 'POST', '/api/auth/refresh', [200], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-refresh-body-injection', sources: authSources,
    context: 'A valid refresh token for User A is accompanied by a forged User B body identifier; only the signed refresh subject may receive an access token.',
    run: (ctx) => ctx.supervisedHttp('model-otp-extra', 'POST', '/api/auth/refresh', { refreshToken: refreshToken(ctx.users.A._id), userId: String(ctx.users.B._id) }),
    check: async (body, ctx) => {
      const token = body?.data?.accessToken;
      const me = typeof token === 'string' ? await ctx.supervisedHttp('model-otp-extra', 'GET', '/api/users/me', undefined, `Bearer ${token}`) : null;
      ctx.evidence = { protectedControl: me?.status === 200, signedSubjectRetained: me?.data?.data?.user?._id === String(ctx.users.A._id) };
      return ctx.evidence.protectedControl && ctx.evidence.signedSubjectRetained;
    },
  });
  add('refresh replay remains limited to its verified subject', 'anonymous', 'POST', '/api/auth/refresh', [200], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-refresh-replay-contract', sources: authSources,
    context: 'The same locally signed refresh token is exchanged twice; the current stateless non-rotation behavior is recorded while both resulting access tokens must bind to the same user.',
    run: async (ctx) => {
      const request = { refreshToken: refreshToken(ctx.users.A._id) };
      const first = await ctx.supervisedHttp('model-otp-extra', 'POST', '/api/auth/refresh', request);
      const second = await ctx.supervisedHttp('model-otp-extra', 'POST', '/api/auth/refresh', request);
      ctx.evidence = { firstExchangeSucceeded: first.status === 200, secondExchangeSucceeded: second.status === 200 };
      return second;
    },
    check: async (body, ctx) => {
      const token = body?.data?.accessToken;
      const me = typeof token === 'string' ? await ctx.supervisedHttp('model-otp-extra', 'GET', '/api/users/me', undefined, `Bearer ${token}`) : null;
      ctx.evidence.subjectRetained = me?.status === 200 && me?.data?.data?.user?._id === String(ctx.users.A._id);
      return ctx.evidence.firstExchangeSucceeded && ctx.evidence.secondExchangeSucceeded && ctx.evidence.subjectRetained;
    },
  });

  const fcmA = 'ci-fcm-a-device';
  const fcmB = 'ci-fcm-b-device';
  add('logout removes only caller matching device token', 'A', 'POST', '/api/auth/logout', [200], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-logout-device-ownership', sources: authSources,
    context: 'User A owns two controlled device identifiers; logout targets exactly one while User B has a separate identifier.',
    prepare: async (ctx) => { await ctx.models.User.findByIdAndUpdate(ctx.users.A._id, { fcmTokens: [fcmA, 'ci-fcm-a-other'] }); await ctx.models.User.findByIdAndUpdate(ctx.users.B._id, { fcmTokens: [fcmB] }); },
    run: (ctx) => ctx.supervisedHttp('model-otp', 'POST', '/api/auth/logout', { fcmToken: fcmA }, `Bearer ${ctx.tokens.A}`),
    check: async (_body, ctx) => {
      const [a, b] = await Promise.all([ctx.models.User.findById(ctx.users.A._id).lean(), ctx.models.User.findById(ctx.users.B._id).lean()]);
      return !a.fcmTokens.includes(fcmA) && a.fcmTokens.includes('ci-fcm-a-other') && b.fcmTokens.length === 1 && b.fcmTokens[0] === fcmB;
    },
  });
  add('logout cannot remove another user device token', 'A', 'POST', '/api/auth/logout', [200], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-logout-device-ownership', sources: authSources,
    context: 'User A submits User B\'s controlled device identifier while authenticated as User A.',
    prepare: async (ctx) => { await ctx.models.User.findByIdAndUpdate(ctx.users.A._id, { fcmTokens: [fcmA] }); await ctx.models.User.findByIdAndUpdate(ctx.users.B._id, { fcmTokens: [fcmB] }); },
    run: (ctx) => ctx.supervisedHttp('model-otp', 'POST', '/api/auth/logout', { fcmToken: fcmB }, `Bearer ${ctx.tokens.A}`),
    check: async (_body, ctx) => {
      const [a, b] = await Promise.all([ctx.models.User.findById(ctx.users.A._id).lean(), ctx.models.User.findById(ctx.users.B._id).lean()]);
      return a.fcmTokens.length === 1 && a.fcmTokens[0] === fcmA && b.fcmTokens.length === 1 && b.fcmTokens[0] === fcmB;
    },
  });
  add('logout replay and forged body identity affect only the caller device', 'A', 'POST', '/api/auth/logout', [200], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-logout-replay-and-body-injection', sources: authSources,
    context: 'User A repeats logout with its own token and a forged User B body identifier; User B\'s device token must remain untouched.',
    prepare: async (ctx) => { await ctx.models.User.findByIdAndUpdate(ctx.users.A._id, { fcmTokens: [fcmA] }); await ctx.models.User.findByIdAndUpdate(ctx.users.B._id, { fcmTokens: [fcmB] }); },
    run: async (ctx) => {
      const payload = { fcmToken: fcmA, userId: String(ctx.users.B._id) };
      const first = await ctx.http('A', 'POST', '/api/auth/logout', payload);
      assert.equal(first.status, 200);
      return ctx.http('A', 'POST', '/api/auth/logout', payload);
    },
    check: async (_body, ctx) => {
      const [a, b] = await Promise.all([ctx.models.User.findById(ctx.users.A._id).lean(), ctx.models.User.findById(ctx.users.B._id).lean()]);
      return !a.fcmTokens.includes(fcmA) && b.fcmTokens.length === 1 && b.fcmTokens[0] === fcmB;
    },
  });
  add('logout without an access token is rejected', 'anonymous', 'POST', '/api/auth/logout', [401], undefined, {
    module: 'Phase 1 Authentication and Session Lifecycle', category: 'auth-logout-authentication', sources: authSources,
    context: 'No bearer credential is supplied while a controlled user has a device identifier that must remain unchanged.',
    prepare: async (ctx) => { await ctx.models.User.findByIdAndUpdate(ctx.users.B._id, { fcmTokens: [fcmB] }); },
    run: (ctx) => ctx.supervisedHttp('model-otp', 'POST', '/api/auth/logout', { fcmToken: fcmB }),
    check: async (body, ctx) => noTokenIssued(body) && (await ctx.models.User.findById(ctx.users.B._id).lean()).fcmTokens[0] === fcmB,
  });
};
