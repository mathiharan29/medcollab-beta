'use strict';

module.exports = function registerMessageRequestCases({ add, ids }) {
  const base = '/api/message-requests';
  const sources = [
    'src/features/message-requests/messageRequest.routes.js',
    'src/features/message-requests/messageRequest.controller.js',
    'src/utils/knownUsers.js',
  ];
  const addRequest = (name, actor, method, endpoint, statuses, body, options = {}) => add(
    name, actor, method, endpoint, statuses, body,
    {
      module: 'Message Requests',
      context: 'E–H are controlled identities with different institutions and no shared space. Pending E→F, declined E→G, blocked F→G, and accepted E→H model each relationship state.',
      sources,
      ...options,
    },
  );
  const requestIds = (body) => (body.data?.requests || []).map((request) => request.id);
  const exactIds = (body, expected) => {
    const actual = requestIds(body).sort();
    return actual.length === expected.length && actual.join(',') === expected.map(String).sort().join(',');
  };
  const exactPairCount = (ctx, from, to, status) => ctx.models.MessageRequest.countDocuments({
    fromUserId: ctx.users[from]._id,
    toUserId: ctx.users[to]._id,
    ...(status ? { status } : {}),
  });
  const prepareFresh = async (ctx) => {
    const r = await ctx.http('F', 'POST', base, { toUserId: String(ctx.users.H._id), introMessage: 'Fresh controlled request' });
    if (r.status !== 201 || !r.data?.data?.request?.id) {
      throw new Error(`Message-request preparation failed with HTTP ${r.status}`);
    }
    ctx.preparedRequestId = r.data.data.request.id;
    const request = await ctx.models.MessageRequest.findById(ctx.preparedRequestId).lean();
    if (!request || String(request.fromUserId) !== String(ctx.users.F._id) ||
      String(request.toUserId) !== String(ctx.users.H._id) || request.status !== 'pending') {
      throw new Error('Message-request preparation did not persist the required pending relationship');
    }
  };
  const optInTarget = async (ctx, actor) => {
    const target = await ctx.models.User.findById(ctx.users[actor]._id).select('notifications').lean();
    const original = target?.notifications?.allowMessageRequestsFromAnyone;
    await ctx.models.User.findByIdAndUpdate(ctx.users[actor]._id, { 'notifications.allowMessageRequestsFromAnyone': true });
    ctx.cleanup.push(() => ctx.models.User.findByIdAndUpdate(ctx.users[actor]._id, { 'notifications.allowMessageRequestsFromAnyone': original }));
    const { canRequestMessage } = require('../../../src/utils/knownUsers');
    if (!await canRequestMessage(ctx.users[ctx.requestActor]._id, ctx.users[actor]._id)) {
      throw new Error(`Request eligibility preparation failed for ${ctx.requestActor}->${actor}`);
    }
  };

  addRequest('list received pending requests', 'F', 'GET', base, [200], undefined, {
    category: 'message-request-list-isolation',
    check: (body) => exactIds(body, [ids.requestPending]),
  });
  addRequest('sender does not receive its own pending request', 'E', 'GET', base, [200], undefined, {
    category: 'message-request-list-isolation',
    check: (body) => exactIds(body, []),
  });
  addRequest('unrelated identity cannot list other requests', 'D', 'GET', base, [200], undefined, {
    category: 'message-request-list-isolation',
    check: (body) => requestIds(body).length === 0,
  });
  addRequest('anonymous caller cannot list requests', 'anonymous', 'GET', base, [401], undefined, { category: 'message-request-anonymous' });
  addRequest('list sent declined requests', 'E', 'GET', `${base}?direction=sent&status=declined`, [200], undefined, {
    category: 'message-request-state-filter',
    check: (body) => requestIds(body).length === 1 && requestIds(body)[0] === ids.requestDeclined && body.data.requests[0].direction === 'sent',
  });
  addRequest('list accepted request only for its sender', 'E', 'GET', `${base}?direction=sent&status=accepted`, [200], undefined, {
    category: 'message-request-state-filter',
    check: (body) => requestIds(body).length === 1 && requestIds(body)[0] === ids.requestAccepted,
  });
  addRequest('pending count is recipient-scoped', 'F', 'GET', `${base}/pending-count`, [200], undefined, {
    category: 'message-request-count-isolation',
    check: (body) => body.data?.count === 1,
  });
  addRequest('pending count excludes sent requests', 'E', 'GET', `${base}/pending-count`, [200], undefined, {
    category: 'message-request-count-isolation',
    check: (body) => body.data?.count === 0,
  });
  addRequest('anonymous caller cannot read pending count', 'anonymous', 'GET', `${base}/pending-count`, [401], undefined, { category: 'message-request-anonymous' });

  addRequest('reject message request to self', 'E', 'POST', base, [400], { toUserId: ':E' }, { category: 'message-request-self-target' });
  addRequest('same-institution opted-out user denies message request', 'A', 'POST', base, [403], { toUserId: ':D' }, {
    category: 'message-request-known-user-denial',
    check: async (_body, ctx) => await exactPairCount(ctx, 'A', 'D') === 0,
  });
  addRequest('pending request is idempotent for the sender', 'E', 'POST', base, [200], { toUserId: ':F' }, {
    category: 'message-request-pending-replay',
    prepare: async ctx => { ctx.requestActor = 'E'; await optInTarget(ctx, 'F'); },
    check: async (body, ctx) => body.data?.request?.id === ids.requestPending &&
      body.data?.request?.direction === 'sent' && await exactPairCount(ctx, 'E', 'F', 'pending') === 1,
  });
  addRequest('reciprocal pending request exposes accept-incoming only to sender', 'F', 'POST', base, [200], { toUserId: ':E' }, {
    category: 'message-request-reciprocal-pending',
    prepare: async ctx => { ctx.requestActor = 'F'; await optInTarget(ctx, 'E'); },
    check: async (body, ctx) => body.data?.request?.id === ids.requestPending && body.data?.action === 'accept_incoming' &&
      body.data?.request?.direction === 'received' && await exactPairCount(ctx, 'E', 'F', 'pending') === 1 &&
      await exactPairCount(ctx, 'F', 'E') === 0,
  });
  addRequest('declined relationship can create a fresh request', 'E', 'POST', base, [201], { toUserId: ':G', introMessage: 'Follow-up controlled request' }, {
    category: 'message-request-declined-transition',
    prepare: async ctx => { ctx.requestActor = 'E'; await optInTarget(ctx, 'G'); },
    check: async (body, ctx) => body.data?.request?.status === 'pending' && body.data?.request?.direction === 'sent' &&
      body.data?.request?.id !== ids.requestDeclined && await exactPairCount(ctx, 'E', 'G', 'pending') === 1 &&
      await ctx.models.MessageRequest.findById(ids.requestDeclined).then(request => request?.status === 'declined') &&
      await exactPairCount(ctx, 'E', 'G', 'declined') === 1,
  });
  addRequest('accepted relationship uses DM rather than a new request', 'E', 'POST', base, [400], { toUserId: ':H' }, { category: 'message-request-accepted-transition' });
  addRequest('blocked relationship rejects a new request from sender', 'F', 'POST', base, [403], { toUserId: ':G' }, {
    category: 'message-request-blocked-transition',
    prepare: async ctx => { ctx.requestActor = 'F'; await optInTarget(ctx, 'G'); },
    check: async (_body, ctx) => await exactPairCount(ctx, 'F', 'G', 'blocked') === 1 &&
      await ctx.models.Channel.countDocuments({ type: 'direct', members: { $all: [ctx.users.F._id, ctx.users.G._id], $size: 2 } }) === 0,
  });
  addRequest('blocked relationship rejects a reciprocal request', 'G', 'POST', base, [403], { toUserId: ':F' }, {
    category: 'message-request-blocked-transition',
    prepare: async ctx => { ctx.requestActor = 'G'; await optInTarget(ctx, 'F'); },
    check: async (_body, ctx) => await exactPairCount(ctx, 'F', 'G', 'blocked') === 1 &&
      await ctx.models.Channel.countDocuments({ type: 'direct', members: { $all: [ctx.users.F._id, ctx.users.G._id], $size: 2 } }) === 0,
  });
  addRequest('inactive request target is not exposed', 'E', 'POST', base, [404], { toUserId: ':I' }, { category: 'message-request-inactive-target' });
  addRequest('absent request target is not exposed', 'E', 'POST', base, [404], { toUserId: ids.absentUser }, { category: 'message-request-absent-target' });
  addRequest('malformed request target is rejected by model/controller', 'E', 'POST', base, [400], { toUserId: 'not-an-id' }, { category: 'message-request-target-schema' });
  addRequest('missing request target is rejected', 'E', 'POST', base, [400], {}, { category: 'message-request-target-schema' });
  addRequest('anonymous caller cannot create a request', 'anonymous', 'POST', base, [401], { toUserId: ':F' }, { category: 'message-request-anonymous' });

  for (const [label, introMessage, status] of [
    ['omitted intro', undefined, 201],
    ['maximum intro', 'x'.repeat(280), 201],
    ['overlong intro', 'x'.repeat(281), 400],
    ['object intro', {}, 400],
  ]) {
    const body = { toUserId: ':H' };
    if (introMessage !== undefined) body.introMessage = introMessage;
    addRequest(`message-request ${label} validation`, 'F', 'POST', base, [status], body, {
      category: 'message-request-intro-schema',
      failureClassification: 'validation weakness/hardening opportunity',
      check: status === 201 ? async (response, ctx) => {
        const id = response.data?.request?.id;
        const request = id && await ctx.models.MessageRequest.findById(id).lean();
        return response.data?.request?.status === 'pending' && !!request &&
          String(request.fromUserId) === String(ctx.users.F._id) && String(request.toUserId) === String(ctx.users.H._id) &&
          request.introMessage === (introMessage || '');
      } : undefined,
    });
  }

  addRequest('recipient accepts a pending request', 'F', 'POST', `${base}/${ids.requestPending}/accept`, [200], undefined, {
    category: 'message-request-recipient-transition',
    check: async (body, ctx) => body.data?.request?.id === ids.requestPending && body.data?.request?.status === 'accepted' &&
      (await ctx.models.MessageRequest.findById(ids.requestPending)).status === 'accepted',
  });
  addRequest('sender cannot accept its own pending request', 'E', 'POST', `${base}/${ids.requestPending}/accept`, [403], undefined, { category: 'message-request-recipient-transition' });
  addRequest('outsider cannot accept another request', 'D', 'POST', `${base}/${ids.requestPending}/accept`, [403], undefined, { category: 'message-request-recipient-transition' });
  addRequest('recipient cannot accept an already accepted request', 'H', 'POST', `${base}/${ids.requestAccepted}/accept`, [400], undefined, { category: 'message-request-replay' });
  addRequest('blocked request cannot be accepted', 'G', 'POST', `${base}/${ids.requestBlocked}/accept`, [400], undefined, { category: 'message-request-blocked-transition' });

  addRequest('recipient declines a fresh request', 'H', 'POST', (ctx) => `${base}/${ctx.preparedRequestId}/decline`, [200], undefined, {
    category: 'message-request-recipient-transition',
    prepare: prepareFresh,
    check: async (body, ctx) => body.data?.request?.id === ctx.preparedRequestId && body.data?.request?.status === 'declined' &&
      (await ctx.models.MessageRequest.findById(ctx.preparedRequestId)).status === 'declined',
  });
  addRequest('sender cannot decline its own fresh request', 'F', 'POST', (ctx) => `${base}/${ctx.preparedRequestId}/decline`, [403], undefined, {
    category: 'message-request-recipient-transition',
    prepare: prepareFresh,
  });
  addRequest('decline replay is rejected', 'H', 'POST', (ctx) => `${base}/${ctx.preparedRequestId}/decline`, [400], undefined, {
    category: 'message-request-replay',
    prepare: async (ctx) => {
      await prepareFresh(ctx);
      const r = await ctx.http('H', 'POST', `${base}/${ctx.preparedRequestId}/decline`);
      const request = await ctx.models.MessageRequest.findById(ctx.preparedRequestId).lean();
      if (r.status !== 200 || request?.status !== 'declined') throw new Error('Decline replay preparation failed');
    },
  });
  addRequest('accepted request enables the new DM pair', 'F', 'POST', '/api/channels/dm', [200], { userId: ':H' }, {
    category: 'message-request-accepted-DM-binding',
    prepare: async (ctx) => {
      await prepareFresh(ctx);
      const r = await ctx.http('H', 'POST', `${base}/${ctx.preparedRequestId}/accept`);
      const request = await ctx.models.MessageRequest.findById(ctx.preparedRequestId).lean();
      if (r.status !== 200 || request?.status !== 'accepted') throw new Error('Accept-to-DM preparation failed');
    },
    check: async (body, ctx) => {
      const members = (body.data?.channel?.members || []).map((member) => String(member._id || member)).sort();
      const channel = body.data?.channel?._id && await ctx.models.Channel.findById(body.data.channel._id).lean();
      const persistedMembers = (channel?.members || []).map(String).sort();
      const expected = [String(ctx.users.F._id), String(ctx.users.H._id)].sort();
      return members.length === 2 && members.join(',') === expected.join(',') &&
        persistedMembers.length === 2 && persistedMembers.join(',') === expected.join(',');
    },
  });
  addRequest('declined request does not enable a DM', 'F', 'POST', '/api/channels/dm', [403], { userId: ':H' }, {
    category: 'message-request-declined-DM-binding',
    prepare: async (ctx) => {
      await prepareFresh(ctx);
      const r = await ctx.http('H', 'POST', `${base}/${ctx.preparedRequestId}/decline`);
      const request = await ctx.models.MessageRequest.findById(ctx.preparedRequestId).lean();
      if (r.status !== 200 || request?.status !== 'declined') throw new Error('Decline-to-DM preparation failed');
    },
  });
};
