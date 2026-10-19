'use strict';
const assert = require('node:assert/strict');

// Phase 2: action requests always traverse the running Express application.
// Model writes below create controlled preconditions, never replace the action.
module.exports = ({ add, ids }) => {
  const base = '/api/users';
  const oid = value => String(value?._id || value || '');
  const sources = ['src/features/users/user.routes.js', 'src/features/users/user.controller.js',
    'src/features/users/user.model.js', 'src/utils/knownUsers.js', 'src/middleware/validate.js'];
  const test = (name, actor, method, endpoint, statuses, body, options = {}) => add(name, actor, method, endpoint, statuses, body, {
    module: 'Phase 2 Users and Profiles', category: 'profile-authorization',
    context: 'Synthetic A-I users; self, space/DM peers, unrelated opted-in/out, inactive and incomplete profiles; exact per-case User reset.', sources, ...options,
  });
  const safeProfile = (body, ctx, target) => {
    const user = body.data?.user;
    ctx.evidence.returnedFields = Object.keys(user || {}).sort();
    ctx.evidence.identityMatched = oid(user) === oid(ctx.users[target]);
    return ctx.evidence.identityMatched && !['phone', 'fcmTokens', 'otp', 'password'].some(key => key in user);
  };
  for (const target of ['A', 'B', 'C', 'D', 'E', 'H', 'I']) test(`public profile ${target} identity and credential minimization`, 'A', 'GET', `${base}/:${target}`, [200], undefined, {
    check: (body, ctx) => safeProfile(body, ctx, target),
  });
  test('public incomplete profile retains supported public-read contract', 'A', 'GET', `${base}/:E`, [200], undefined, {
    prepare: ctx => ctx.models.User.findByIdAndUpdate(ctx.users.E._id, { isOnboarded: false }),
    check: (body, ctx) => safeProfile(body, ctx, 'E') && body.data.user.isOnboarded === false,
  });
  for (const [label, id, status] of [['malformed', 'bad-id', 400], ['absent', ids.absentUser, 404]]) test(`public profile ${label} ID`, 'A', 'GET', `${base}/${id}`, [status]);
  test('public profile anonymous denial', 'anonymous', 'GET', `${base}/:B`, [401]);
  test('public profile preference and activity field policy review', 'A', 'GET', `${base}/:E`, [200], undefined, {
    securityInvariant: 'Policy review: foreign public profiles should minimize notification preferences and activity timestamps; authenticated foreign profile reads themselves remain supported.',
    failureClassification: 'hardening / public profile field policy requires review',
    check: (body, ctx) => {
      safeProfile(body, ctx, 'E');
      ctx.evidence.preferenceFieldsExposed = Object.keys(body.data?.user?.notifications || {}).sort();
      return !('notifications' in body.data.user) && !('lastSeenAt' in body.data.user);
    },
  });
  const lookup = target => ctx => `${base}/lookup?phone=${encodeURIComponent(ctx.users[target].phone)}`;
  for (const [actor, target, canMessage, canRequest, pending, direction] of [
    ['A', 'A', true, false, null, null], ['A', 'B', true, false, null, null],
    ['A', 'D', false, false, null, null], ['A', 'E', false, false, null, null],
    ['F', 'H', false, true, null, null], ['E', 'H', true, false, null, null],
    ['E', 'F', false, false, ids.requestPending, 'sent'], ['F', 'E', false, false, ids.requestPending, 'received'],
    ['F', 'G', false, false, null, null],
  ]) test(`lookup ${actor} to ${target} relationship and pair metadata`, actor, 'GET', lookup(target), [200], undefined, {
    check: (body, ctx) => {
      const data = body.data;
      ctx.evidence.canMessage = data?.canMessage; ctx.evidence.canRequest = data?.canRequest;
      ctx.evidence.pendingId = data?.pendingRequest?.id || null;
      return safeProfile(body, ctx, target) && data.canMessage === canMessage && data.canRequest === canRequest &&
        (data.pendingRequest?.id || null) === pending && (data.pendingRequest?.direction || null) === direction;
    },
  });
  for (const [label, endpoint, status] of [
    ['inactive', lookup('I'), 404], ['absent synthetic phone', `${base}/lookup?phone=%2B15559990003`, 404],
    ['missing', `${base}/lookup`, 400], ['malformed', `${base}/lookup?phone=invalid`, 400],
    ['object', `${base}/lookup?phone[x]=1`, 400],
  ]) test(`lookup ${label}`, 'A', 'GET', endpoint, [status]);
  test('lookup anonymous denial', 'anonymous', 'GET', lookup('B'), [401]);
  test('lookup opts in then matches real request eligibility', 'F', 'GET', lookup('E'), [200], undefined, {
    prepare: ctx => ctx.models.User.findByIdAndUpdate(ctx.users.E._id, { 'notifications.allowMessageRequestsFromAnyone': true }),
    check: async (body, ctx) => {
      if (body.data?.canRequest !== true) return false;
      const response = await ctx.http('F', 'POST', '/api/message-requests', { toUserId: oid(ctx.users.E) });
      ctx.evidence.requestActionStatus = response.status;
      return response.status === 200 && response.data?.data?.request?.id === ids.requestPending;
    },
  });
  const searchCheck = expected => (body, ctx) => {
    const values = body.data?.users || [];
    ctx.evidence.returnedIds = values.map(oid).sort();
    return JSON.stringify(values.map(oid).sort()) === JSON.stringify(expected.map(actor => oid(ctx.users[actor])).sort()) &&
      values.every(user => !['phone', 'fcmTokens', 'notifications'].some(key => key in user));
  };
  test('search institution space and DM union excludes unrelated inactive and self', 'A', 'GET', `${base}/search?q=Vocle`, [200], undefined, { check: searchCheck(['B', 'C', 'D']) });
  test('search active DM peer outside institution', 'E', 'GET', `${base}/search?q=Vocle`, [200], undefined, { check: searchCheck(['D']) });
  test('search archived DM peer excluded with active peer canary', 'E', 'GET', `${base}/search?q=Vocle`, [200], undefined, { check: searchCheck(['D']) });
  test('search removed member excluded after independent relationships removed', 'A', 'GET', `${base}/search?q=Vocle`, [200], undefined, {
    prepare: async ctx => {
      await ctx.models.Space.updateOne({ _id: ids.space }, { $pull: { members: { userId: ctx.users.B._id } } });
      await ctx.models.Channel.updateOne({ _id: ids.dmAB }, { isArchived: true });
      await ctx.models.User.updateOne({ _id: ctx.users.B._id }, { institution: 'Isolated removed fixture' });
    }, check: searchCheck(['C', 'D']),
  });
  test('search inactive and incomplete known peers excluded with canary', 'A', 'GET', `${base}/search?q=Vocle`, [200], undefined, {
    prepare: async ctx => {
      await ctx.models.User.updateOne({ _id: ctx.users.B._id }, { isActive: false });
      await ctx.models.User.updateOne({ _id: ctx.users.C._id }, { isOnboarded: false });
    }, check: searchCheck(['D']),
  });
  test('search space intersection', 'A', 'GET', `${base}/search?q=Vocle&spaceId=${ids.space}`, [200], undefined, { check: searchCheck(['B']) });
  test('search foreign space membership inference policy', 'A', 'GET', `${base}/search?q=Vocle&spaceId=${ids.otherSpace}`, [200], undefined, {
    securityInvariant: 'Policy review: a caller denied foreign space detail should not infer that space membership from a known-user search filter.',
    failureClassification: 'hardening / known-user foreign-space membership inference policy',
    prepare: async ctx => assert.equal((await ctx.http('A', 'GET', `/api/spaces/${ids.otherSpace}`)).status, 403, 'Foreign space denial control failed'),
    check: (body, ctx) => { searchCheck([])(body, ctx); return (body.data?.users || []).length === 0; },
  });
  for (const [label, query, status] of [['missing', '', 400], ['one character', '?q=V', 400], ['whitespace', '?q=%20%20', 400], ['literal regex', '?q=.*', 200], ['malformed space', '?q=Vocle&spaceId=bad', 400]]) test(`search ${label} boundary`, 'A', 'GET', `${base}/search${query}`, [status], undefined, {
    category: 'profile-schema-boundary', check: status === 200 ? searchCheck([]) : undefined,
  });
  test('search anonymous denial', 'anonymous', 'GET', `${base}/search?q=Vocle`, [401]);
  const seedNeedl = async ctx => {
    await ctx.models.Channel.updateOne({ _id: ids.channel }, { isPrivate: true, members: [ctx.users.A._id] });
    await ctx.models.Message.updateOne({ _id: ids.messageA }, { replyCount: 1, 'content.text': 'Private synthetic Needl canary' });
    await ctx.models.Message.updateOne({ _id: ids.messageB }, { threadId: ids.messageA });
    const control = await ctx.http('A', 'GET', `${base}/me/needl`);
    assert.ok(control.status === 200 && control.data?.data?.threads?.some(thread => thread.rootMessageId === ids.messageA), 'Needl authorized canary missing');
    const denial = await ctx.http('B', 'GET', `/api/channels/${ids.channel}/messages`);
    assert.equal(denial.status, 403, 'Needl private message-read denial control failed');
    ctx.evidence.authorizedCanary = true; ctx.evidence.privateMessageReadDenied = true;
  };
  for (const [label, actor, exclude, change] of [
    ['member control', 'A', false, null], ['excluded same-space member', 'B', true, null],
    ['outsider', 'C', true, null], ['archived root channel', 'A', true, 'archive'],
    ['deleted root', 'A', true, 'delete'], ['revoked space membership', 'B', true, 'revoke'],
    ['removed private-channel member', 'B', true, 'private-revoke'],
  ]) test(`Needl ${label} preview confidentiality`, actor, 'GET', `${base}/me/needl`, [200], undefined, {
    category: 'needl-private-authorization', failureClassification: 'likely security finding / Needl private preview confidentiality',
    securityInvariant: 'Needl must expose the synthetic root/preview only while the caller has access to its active channel and undeleted message. Successful member and private message-read denial controls are required.',
    prepare: async ctx => {
      await seedNeedl(ctx);
      if (change === 'archive') await ctx.models.Channel.updateOne({ _id: ids.channel }, { isArchived: true });
      if (change === 'delete') await ctx.models.Message.updateOne({ _id: ids.messageA }, { isDeleted: true });
      if (change === 'revoke') await ctx.models.Space.updateOne({ _id: ids.space }, { $pull: { members: { userId: ctx.users.B._id } } });
      if (change === 'private-revoke') {
        await ctx.models.Channel.updateOne({ _id: ids.channel }, { members: [ctx.users.A._id, ctx.users.B._id] });
        assert.equal((await ctx.http('B', 'GET', `/api/channels/${ids.channel}/messages`)).status, 200, 'Private member control failed');
        await ctx.models.Channel.updateOne({ _id: ids.channel }, { $pull: { members: ctx.users.B._id } });
      }
    },
    check: (body, ctx) => {
      const match = (body.data?.threads || []).find(thread => thread.rootMessageId === ids.messageA);
      ctx.evidence.privateRootReturned = !!match; ctx.evidence.previewMatched = match?.preview === 'Private synthetic Needl canary';
      return exclude ? !match : !!match && match.channelId === ids.channel && ctx.evidence.previewMatched;
    },
  });
  test('Needl foreign reply root remains excluded despite cross-binding', 'A', 'GET', `${base}/me/needl`, [200], undefined, {
    prepare: async ctx => {
      await ctx.models.Message.updateOne({ _id: ids.messageB }, { threadId: ids.otherMessage });
      await ctx.models.Message.updateOne({ _id: ids.messageA }, { replyCount: 1 });
    }, check: body => body.data?.threads?.some(thread => thread.rootMessageId === ids.messageA) && !body.data.threads.some(thread => thread.rootMessageId === ids.otherMessage),
  });
  test('Needl anonymous denial', 'anonymous', 'GET', `${base}/me/needl`, [401]);
  test('profile allowed writes remain caller-owned and medical role never grants space admin', 'B', 'PUT', `${base}/me`, [200], { name: 'Synthetic Updated B', role: 'consultant', bio: 'Synthetic profile', userId: ':A' }, {
    check: async (body, ctx) => {
      const user = await ctx.models.User.findById(ctx.users.B._id).lean();
      const space = await ctx.models.Space.findById(ids.space);
      return safeProfile(body, ctx, 'B') && user.name === 'Synthetic Updated B' && user.role === 'consultant' &&
        space.getMemberRole(ctx.users.B._id) === 'member' && (await ctx.models.User.findById(ctx.users.A._id)).name === ctx.users.A.name;
    },
  });
  test('profile immutable ownership credentials and invented admin fields ignored', 'B', 'PUT', `${base}/me`, [200], {
    _id: ':A', phone: '+15559990001', isActive: false, isVerified: false, isOnboarded: false, fcmTokens: ['ci-injected-device'], admin: true, spaceRole: 'owner',
  }, { check: async (body, ctx) => {
    const user = await ctx.models.User.findById(ctx.users.B._id).lean();
    return safeProfile(body, ctx, 'B') && user.phone === ctx.users.B.phone && user.isActive && user.isVerified && user.isOnboarded && user.fcmTokens.length === 0 && !user.admin;
  } });
  test('profile onboarding computed from allowed name and role', 'E', 'PUT', `${base}/me`, [200], { name: 'Synthetic Onboarding E', role: 'intern', isOnboarded: false }, {
    prepare: ctx => ctx.models.User.updateOne({ _id: ctx.users.E._id }, { isOnboarded: false, name: '' }),
    check: async (body, ctx) => safeProfile(body, ctx, 'E') && (await ctx.models.User.findById(ctx.users.E._id)).isOnboarded === true,
  });
  for (const optIn of [true, false]) test(`profile notification opt-in ${optIn} merges sibling preferences`, 'E', 'PUT', `${base}/me`, [200], { notifications: { allowMessageRequestsFromAnyone: optIn } }, {
    prepare: ctx => ctx.models.User.updateOne({ _id: ctx.users.E._id }, { 'notifications.mentions': false, 'notifications.quietHoursStart': '22:00' }),
    check: async (_body, ctx) => {
      const prefs = (await ctx.models.User.findById(ctx.users.E._id)).notifications;
      return prefs.allowMessageRequestsFromAnyone === optIn && prefs.mentions === false && prefs.quietHoursStart === '22:00' && prefs.emergencyAlerts === true;
    },
  });
  test('profile nested notification identity injection ignored', 'B', 'PUT', `${base}/me`, [200], { notifications: { isActive: false, role: 'owner', $set: { phone: '+15559990001' } } }, {
    check: async (_body, ctx) => {
      const user = await ctx.models.User.findById(ctx.users.B._id).lean();
      return user.isActive && user.role === ctx.users.B.role && user.phone === ctx.users.B.phone && !('role' in user.notifications) && !('$set' in user.notifications);
    },
  });
  for (const [label, body] of [['name short', { name: 'x' }], ['name over max', { name: 'x'.repeat(101) }], ['role enum', { role: 'owner' }], ['pg below', { pgYear: 0 }], ['pg above', { pgYear: 7 }], ['bio over max', { bio: 'x'.repeat(301) }]]) test(`profile ${label} validation`, 'B', 'PUT', `${base}/me`, [400], body, { category: 'profile-schema-boundary' });
  for (const [label, body, status] of [
    ['own with forged target', { status: 'on_call', note: 'Synthetic only', userId: ':A' }, 200],
    ['note at max', { status: 'available', note: 'x'.repeat(100) }, 200],
    ['note over max', { status: 'available', note: 'x'.repeat(101) }, 400],
    ['missing status', {}, 400], ['invalid enum', { status: 'admin' }, 400],
  ]) test(`availability ${label}`, 'B', 'PUT', `${base}/me/availability`, [status], body, {
    category: 'availability-schema-ownership', check: status === 200 ? async (_body, ctx) => {
      const user = await ctx.models.User.findById(ctx.users.B._id);
      return user.availability.status === body.status && user.availability.note === body.note &&
        (await ctx.models.User.findById(ctx.users.A._id)).availability.status === ctx.users.A.availability.status;
    } : undefined,
  });
  for (const [label, body, status] of [['synthetic device own only', { token: 'ci-profile-device', userId: ':A' }, 200], ['missing', {}, 400], ['empty', { token: '' }, 400], ['object token', { token: { invalid: true } }, 400]]) test(`FCM ${label}`, 'B', 'PUT', `${base}/me/fcm-token`, [status], body, {
    category: 'device-token-schema-ownership', check: status === 200 ? async (_body, ctx) => {
      const user = await ctx.models.User.findById(ctx.users.B._id);
      return user.fcmTokens.join(',') === 'ci-profile-device' && (await ctx.models.User.findById(ctx.users.A._id)).fcmTokens.length === 0;
    } : undefined,
  });
  test('FCM dedup five-device cap and logout lifecycle', 'B', 'PUT', `${base}/me/fcm-token`, [200], undefined, {
    run: async ctx => {
      let response;
      for (const token of ['ci-device-1', 'ci-device-2', 'ci-device-3', 'ci-device-4', 'ci-device-5', 'ci-device-6', 'ci-device-6']) {
        response = await ctx.http('B', 'PUT', `${base}/me/fcm-token`, { token });
        assert.equal(response.status, 200, 'Synthetic device registration control failed');
      }
      return response;
    }, check: async (_body, ctx) => {
      const user = await ctx.models.User.findById(ctx.users.B._id);
      const capHeld = user.fcmTokens.join(',') === 'ci-device-6,ci-device-5,ci-device-4,ci-device-3,ci-device-2';
      const logout = await ctx.http('B', 'POST', '/api/auth/logout', { fcmToken: 'ci-device-6' });
      ctx.evidence.deviceCapHeld = capHeld; ctx.evidence.logoutStatus = logout.status;
      return capHeld && logout.status === 200 && (await ctx.models.User.findById(ctx.users.B._id)).fcmTokens.length === 4;
    },
  });
  for (const endpoint of ['/me', '/me/availability', '/me/fcm-token']) test(`profile write anonymous ${endpoint}`, 'anonymous', 'PUT', `${base}${endpoint}`, [401], {});
};
