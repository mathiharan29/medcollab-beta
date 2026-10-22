'use strict';
const assert = require('node:assert/strict');

module.exports = ({ add, ids }) => {
  const base = '/api/spaces';
  const space = `${base}/${ids.space}`;
  const oid = value => String(value?._id || value || '');
  const test = (name, actor, method, endpoint, statuses, body, options = {}) => add(name, actor, method, endpoint, statuses, body, {
    module: 'Phase 3 Space Lifecycle', category: 'space-lifecycle-authorization',
    context: 'A owner, B member, D independent admin when prepared, C outsider/pending joiner; only synthetic local resources.',
    sources: ['src/features/spaces/space.routes.js', 'src/features/spaces/space.controller.js', 'src/features/spaces/space.model.js', 'src/utils/channelAccess.js'], ...options,
  });
  const admin = ctx => ctx.models.Space.updateOne({ _id: ids.space }, { $push: { members: { userId: ctx.users.D._id, role: 'admin' } } });
  const previewCheck = member => body => {
    const invite = body.data?.invite;
    const fields = ['alreadyMember', 'description', 'inviteCode', 'joinUrl', 'memberCount', 'name', 'type'];
    return !!invite && Object.keys(invite).sort().join(',') === fields.sort().join(',') && invite.inviteCode === 'DSCABA' && invite.memberCount === 2 && invite.alreadyMember === member;
  };
  test('space create caller ownership default channels and injection containment', 'B', 'POST', base, [201], {
    name: 'Synthetic Lifecycle Space', type: 'department', createdBy: ':A', members: [{ userId: ':C', role: 'owner' }],
    settings: { requireApproval: true }, inviteCode: 'EVILCI', isActive: false,
  }, { check: async (body, ctx) => {
    const record = body.data?.space?._id && await ctx.models.Space.findById(body.data.space._id);
    if (!record) return false;
    const channels = await ctx.models.Channel.find({ spaceId: record._id }).lean();
    ctx.evidence.defaultChannelCount = channels.length;
    return oid(record.createdBy) === oid(ctx.users.B) && record.members.length === 1 && record.getMemberRole(ctx.users.B._id) === 'owner' &&
      record.inviteCode !== 'EVILCI' && record.isActive && record.settings.requireApproval === false && channels.length === 3 &&
      channels.map(channel => channel.name).sort().join(',') === 'academics,emergency,general' &&
      channels.every(channel => oid(channel.createdBy) === oid(ctx.users.B)) && (await ctx.models.Space.findById(ids.space)).members.length === 2;
  } });
  for (const [label, body] of [['missing name', { type: 'department' }], ['short name', { name: 'x', type: 'department' }], ['over max name', { name: 'x'.repeat(101), type: 'department' }], ['invalid type', { name: 'Synthetic', type: 'owner' }], ['description over max', { name: 'Synthetic', type: 'department', description: 'x'.repeat(301) }]]) test(`space create ${label}`, 'B', 'POST', base, [400], body, { category: 'space-schema-boundary' });
  test('space create anonymous', 'anonymous', 'POST', base, [401], { name: 'Synthetic', type: 'department' });
  for (const actor of ['A', 'C']) test(`invite preview ${actor} summary minimization`, actor, 'GET', `${base}/invite/dscaba`, [200], undefined, { check: previewCheck(actor === 'A') });
  for (const [label, code, status] of [['absent', 'ZZZZZZ', 404], ['malformed', 'bad', 404], ['anonymous', 'DSCABA', 401]]) test(`invite preview ${label}`, label === 'anonymous' ? 'anonymous' : 'C', 'GET', `${base}/invite/${code}`, [status]);
  test('inactive invite preview denied', 'C', 'GET', `${base}/invite/DSCABA`, [404], undefined, { prepare: ctx => ctx.models.Space.updateOne({ _id: ids.space }, { isActive: false }) });
  for (const actor of ['A', 'D', 'B', 'C', 'anonymous']) test(`invite rotation ${actor} role boundary`, actor, 'POST', `${space}/invite`, [actor === 'A' || actor === 'D' ? 200 : actor === 'anonymous' ? 401 : 403], {}, {
    prepare: admin,
    check: actor === 'A' || actor === 'D' ? async (body, ctx) => {
      const code = body.data?.inviteCode;
      if (!/^[A-Z0-9]{6}$/.test(code || '') || code === 'DSCABA') return false;
      const oldPreview = await ctx.http('C', 'GET', `${base}/invite/DSCABA`);
      const oldJoin = await ctx.http('C', 'POST', `${base}/join`, { inviteCode: 'DSCABA' });
      const newPreview = await ctx.http('C', 'GET', `${base}/invite/${code}`);
      const join = await ctx.http('C', 'POST', `${base}/join`, { inviteCode: code });
      ctx.evidence.oldPreviewStatus = oldPreview.status; ctx.evidence.oldJoinStatus = oldJoin.status; ctx.evidence.newJoinStatus = join.status;
      return oldPreview.status === 404 && oldJoin.status === 404 && newPreview.status === 200 && join.status === 200 &&
        (await ctx.models.Space.findById(ids.space)).getMemberRole(ctx.users.C._id) === 'member';
    } : undefined,
  });
  for (const [label, body, status] of [
    ['lowercase role injection', { inviteCode: 'dscaba', role: 'owner', userId: ':A', members: [{ userId: ':D', role: 'admin' }] }, 200],
    ['missing', {}, 400], ['short', { inviteCode: 'ABC' }, 400], ['punctuation', { inviteCode: 'ABC!!!' }, 400],
    ['object', { inviteCode: {} }, 400], ['absent', { inviteCode: 'ZZZZZZ' }, 404],
  ]) test(`join ${label}`, 'C', 'POST', `${base}/join`, [status], body, {
    category: 'space-join-schema-ownership', check: status === 200 ? async (_body, ctx) => {
      const record = await ctx.models.Space.findById(ids.space);
      const replay = await ctx.http('C', 'POST', `${base}/join`, { inviteCode: 'DSCABA' });
      return record.getMemberRole(ctx.users.C._id) === 'member' && record.members.length === 3 && replay.status === 409 &&
        (await ctx.models.Space.findById(ids.space)).members.filter(member => oid(member.userId) === oid(ctx.users.C)).length === 1;
    } : undefined,
  });
  test('join existing member replay no duplicate', 'B', 'POST', `${base}/join`, [409], { inviteCode: 'DSCABA' });
  test('join inactive space', 'C', 'POST', `${base}/join`, [404], { inviteCode: 'DSCABA' }, { prepare: ctx => ctx.models.Space.updateOne({ _id: ids.space }, { isActive: false }) });
  test('join anonymous', 'anonymous', 'POST', `${base}/join`, [401], { inviteCode: 'DSCABA' });
  test('approval pending replay has no membership or REST access', 'C', 'POST', `${base}/join`, [200], { inviteCode: 'DSCABA', role: 'admin' }, {
    prepare: ctx => ctx.models.Space.updateOne({ _id: ids.space }, { 'settings.requireApproval': true }),
    check: async (_body, ctx) => {
      const replay = await ctx.http('C', 'POST', `${base}/join`, { inviteCode: 'DSCABA' });
      const record = await ctx.models.Space.findById(ids.space);
      const responses = [];
      for (const endpoint of [space, `${space}/channels`, `/api/channels/${ids.channel}/messages`]) responses.push((await ctx.http('C', 'GET', endpoint)).status);
      ctx.evidence.pendingAccessStatuses = responses;
      return replay.status === 200 && !record.isMember(ctx.users.C._id) && record.pendingRequests.filter(request => oid(request.userId) === oid(ctx.users.C)).length === 1 && responses.every(status => status === 403);
    },
  });
  for (const actor of ['A', 'B', 'C', 'anonymous']) test(`leave ${actor} identity and owner protection`, actor, 'POST', `${space}/leave`, [actor === 'B' ? 200 : actor === 'anonymous' ? 401 : 400], { userId: ':A' }, {
    check: actor === 'B' ? async (_body, ctx) => {
      const record = await ctx.models.Space.findById(ids.space);
      return record.members.length === 1 && record.isMember(ctx.users.A._id) && !record.isMember(ctx.users.B._id) && (await ctx.http('B', 'POST', `${space}/leave`, {})).status === 400;
    } : undefined,
  });
  for (const [label, actor, target, status] of [['admin remove member', 'D', 'B', 200], ['admin protect owner', 'D', 'A', 403], ['owner protect self', 'A', 'A', 403], ['member cannot remove admin', 'B', 'D', 403], ['outsider cannot remove member', 'C', 'B', 403]]) test(`removal ${label}`, actor, 'DELETE', `${space}/members/:${target}`, [status], undefined, {
    prepare: admin, check: status === 200 ? async (_body, ctx) => !(await ctx.models.Space.findById(ids.space)).isMember(ctx.users[target]._id) && (await ctx.http(actor, 'DELETE', `${space}/members/${oid(ctx.users[target])}`)).status === 404 : undefined,
  });
  for (const lifecycle of ['leave', 'remove']) {
    const prepare = async ctx => {
      assert.equal((await ctx.http('B', 'GET', `/api/channels/${ids.channel}/messages`)).status, 200, 'Membership authorized message control failed');
      await ctx.models.Message.updateOne({ _id: ids.messageA }, { replyCount: 1 });
      await ctx.models.Channel.updateOne({ _id: ids.channel }, { isPrivate: true, members: [ctx.users.A._id, ctx.users.B._id] });
      await ctx.models.Channel.updateOne({ _id: ids.dmAB }, { isArchived: true });
      await ctx.models.User.updateOne({ _id: ctx.users.A._id }, { institution: 'Independent A fixture' });
      const response = await ctx.http(lifecycle === 'leave' ? 'B' : 'A', lifecycle === 'leave' ? 'POST' : 'DELETE', lifecycle === 'leave' ? `${space}/leave` : `${space}/members/${oid(ctx.users.B)}`, {});
      assert.equal(response.status, 200, 'REST membership revocation prerequisite failed');
      assert.equal((await ctx.http('B', 'GET', `/api/channels/${ids.channel}/messages`)).status, 403, 'Post-revocation private message denial control failed');
      const owner = await ctx.http('A', 'GET', '/api/users/me/needl');
      assert.ok(owner.status === 200 && owner.data?.data?.threads?.some(thread => thread.rootMessageId === ids.messageA), 'Post-revocation Needl owner canary missing');
      ctx.evidence.postRevocationMessageReadDenied = true;
      ctx.evidence.ownerNeedlCanaryObserved = true;
    };
    for (const endpoint of [space, `${space}/channels`, `/api/channels/${ids.channel}/messages`]) test(`${lifecycle} immediate REST revocation ${endpoint}`, 'B', 'GET', endpoint, [403], undefined, { prepare });
    test(`${lifecycle} list excludes former space and private references`, 'B', 'GET', base, [200], undefined, { prepare, check: body => !body.data?.spaces?.some(value => oid(value) === ids.space) });
    test(`${lifecycle} Needl excludes former private root`, 'B', 'GET', '/api/users/me/needl', [200], undefined, {
      prepare, failureClassification: 'likely security finding / Needl space revocation bypass via retained channel member IDs',
      securityInvariant: 'A former space member must not receive a private root preview through retained channel.members after REST space membership is revoked.',
      check: (body, ctx) => { ctx.evidence.revokedPrivateRootReturned = !!body.data?.threads?.some(thread => thread.rootMessageId === ids.messageA); return !ctx.evidence.revokedPrivateRootReturned; },
    });
    test(`${lifecycle} search excludes former peer with unrelated canary`, 'B', 'GET', '/api/users/search?q=Vocle', [200], undefined, {
      prepare, check: (body, ctx) => !body.data?.users?.some(user => oid(user) === oid(ctx.users.A)) && body.data?.users?.some(user => oid(user) === oid(ctx.users.D)),
    });
  }
  for (const [label, id, status] of [['malformed', 'bad', 400], ['absent', ids.absentUser, 404]]) for (const action of ['invite', 'leave']) test(`${action} ${label} space ID`, 'B', 'POST', `${base}/${id}/${action}`, [status], {});
};
