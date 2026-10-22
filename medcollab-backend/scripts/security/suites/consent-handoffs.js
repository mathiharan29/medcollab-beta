'use strict';
const assert = require('node:assert/strict');

module.exports = ({ add, ids }) => {
  const oid = value => String(value?._id || value || '');
  const group = '/api/channels/dm/group';
  const handoff = `/api/handoffs/${ids.handoff}`;
  const test = (name, actor, endpoint, statuses, body, options = {}) => add(name, actor, 'POST', endpoint, statuses, body, {
    module: 'Phase 3 Consent and Handoffs', category: 'consent-handoff-authorization',
    context: 'Synthetic DM eligibility and consent states; handoff A to B, D independent admin/member, C outsider; exact fixture reset.',
    sources: ['src/features/channels/channel.controller.js:createGroupDM', 'src/utils/knownUsers.js',
      'src/features/handoffs/handoff.routes.js', 'src/features/handoffs/handoff.controller.js', 'src/features/handoffs/handoff.model.js', 'src/services/notification.service.js'], ...options,
  });
  const member = (ctx, actor, role = 'member') => ctx.models.Space.updateOne({ _id: ids.space }, { $push: { members: { userId: ctx.users[actor]._id, role } } });
  const groupCheck = actors => async (body, ctx) => {
    const id = body.data?.channel?._id;
    const channel = id && await ctx.models.Channel.findById(id).lean();
    ctx.evidence.groupId = id || null;
    return !!channel && channel.type === 'direct' && channel.spaceId === null && oid(channel.createdBy) === oid(ctx.users.A) &&
      channel.members.map(oid).sort().join(',') === actors.map(actor => oid(ctx.users[actor])).sort().join(',');
  };
  test('group DM eligible peers unique caller ownership and replay', 'A', group, [200], { userIds: [':B', ':H', ':B', ':A'], createdBy: ':C' }, {
    check: async (body, ctx) => {
      if (!(await groupCheck(['A', 'B', 'H'])(body, ctx))) return false;
      const replay = await ctx.http('A', 'POST', group, { userIds: [oid(ctx.users.H), oid(ctx.users.B)] });
      const outsider = await ctx.http('C', 'GET', `/api/channels/${body.data.channel._id}/messages`);
      return replay.status === 200 && replay.data?.data?.channel?._id === body.data.channel._id && outsider.status === 403 &&
        (await ctx.models.Channel.countDocuments({ type: 'direct', members: { $all: ['A', 'B', 'H'].map(actor => ctx.users[actor]._id), $size: 3 } })) === 1;
    },
  });
  for (const [label, values, status] of [
    ['missing', undefined, 400], ['non-array', {}, 400], ['one other', [':B'], 400], ['self leaves one', [':A', ':B'], 400],
    ['duplicate leaves one', [':B', ':B'], 400], ['malformed', [':B', 'bad'], 400], ['absent', [':B', ids.absentUser], 404],
    ['mixed opted-out peer no partial channel', [':B', ':E'], 403],
    ['nine others maximum', [':B', ':C', ':D', ':E', ':F', ':G', ':H', ':I', ids.absentUser], 400],
  ]) test(`group DM ${label}`, 'A', group, [status], values === undefined ? {} : { userIds: values }, { category: 'group-dm-schema-consent-boundary' });
  test('group DM anonymous', 'anonymous', group, [401], { userIds: [':B', ':H'] });
  test('group DM eight eligible active peers at maximum', 'A', group, [200], { userIds: [':B', ':C', ':D', ':E', ':F', ':G', ':H', ':I'] }, {
    prepare: async ctx => {
      await ctx.models.User.updateOne({ _id: ctx.users.I._id }, { isActive: true });
      await ctx.models.User.updateMany({ _id: { $in: Object.values(ctx.users).map(user => user._id) } }, { 'notifications.allowMessageRequestsFromAnyone': true });
    }, check: groupCheck(['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I']),
  });
  for (const state of ['inactive', 'incomplete']) test(`group DM ${state} opted-in target should be unavailable`, 'A', group, [404], { userIds: [':B', ':I'] }, {
    category: 'group-dm-target-lifecycle', failureClassification: 'likely security finding / unavailable identity accepted in group DM',
    prepare: ctx => ctx.models.User.updateOne({ _id: ctx.users.I._id }, {
      isActive: state !== 'inactive', isOnboarded: state !== 'incomplete', 'notifications.allowMessageRequestsFromAnyone': true,
    }),
    check: async (body, ctx, response) => {
      if (response.status >= 400) return true;
      const channel = body.data?.channel?._id && await ctx.models.Channel.findById(body.data.channel._id).lean();
      ctx.evidence.returnedGroupId = body.data?.channel?._id || null;
      ctx.evidence.unavailableTargetPersisted = !!channel?.members.some(id => oid(id) === oid(ctx.users.I));
      return !ctx.evidence.unavailableTargetPersisted;
    },
  });
  test('group DM request-eligible unaccepted peer messaging consent policy', 'F', group, [200], { userIds: [':E', ':H'] }, {
    securityInvariant: 'Consent policy review: request eligibility without acceptance should not automatically grant full group message access; current source permits group creation and this is recorded for product review.',
    failureClassification: 'consent policy review / request eligibility opens group message access without acceptance',
    prepare: async ctx => {
      await ctx.models.User.updateOne({ _id: ctx.users.E._id }, { 'notifications.allowMessageRequestsFromAnyone': true });
      assert.equal((await ctx.http('F', 'POST', '/api/channels/dm', { userId: oid(ctx.users.E) })).status, 403, 'Unaccepted pair DM denial control failed');
    }, check: async (body, ctx) => {
      const id = body.data?.channel?._id;
      if (!id) return false;
      const sent = await ctx.http('F', 'POST', `/api/channels/${id}/messages`, { content: { text: 'Synthetic consent canary' } });
      const read = await ctx.http('E', 'GET', `/api/channels/${id}/messages`);
      ctx.evidence.unacceptedGroupSendStatus = sent.status; ctx.evidence.unacceptedGroupReadStatus = read.status;
      ctx.evidence.pendingRequestUnchanged = (await ctx.models.MessageRequest.findById(ids.requestPending)).status === 'pending';
      return !(sent.status === 201 && read.status === 200);
    },
  });
  test('group membership promotes unaccepted pair to one-to-one DM policy', 'F', '/api/channels/dm', [403], { userId: ':E' }, {
    securityInvariant: 'Consent policy review: adding a pending peer to a group should not itself replace one-to-one acceptance. The original pending request must remain unaccepted.',
    failureClassification: 'consent policy review / group-derived one-to-one DM eligibility',
    prepare: async ctx => {
      await ctx.models.User.updateOne({ _id: ctx.users.E._id }, { 'notifications.allowMessageRequestsFromAnyone': true });
      assert.equal((await ctx.http('F', 'POST', '/api/channels/dm', { userId: oid(ctx.users.E) })).status, 403, 'Pair consent denial control failed');
      const control = await ctx.http('F', 'POST', group, { userIds: [oid(ctx.users.E), oid(ctx.users.H)] });
      assert.equal(control.status, 200, 'Group consent prerequisite failed');
      ctx.evidence.pendingRequestBefore = (await ctx.models.MessageRequest.findById(ids.requestPending)).status;
    },
  });
  const setupHandoff = (state = 'submitted') => async ctx => {
    await member(ctx, 'D', 'admin');
    if (state === 'draft') await ctx.models.Handoff.updateOne({ _id: ids.handoff }, { status: 'draft', submittedAt: null });
    if (state === 'acknowledged') await ctx.models.Handoff.updateOne({ _id: ids.handoff }, { status: 'acknowledged', acknowledgedAt: new Date('2025-01-16'), acknowledgementNote: 'Synthetic prior acknowledgement' });
  };
  const noteCheck = (actor, text, kind = 'note') => async (body, ctx) => {
    const record = await ctx.models.Handoff.findById(ids.handoff).lean();
    const note = record.writeBackNotes.at(-1);
    return oid(body.data?.handoff) === ids.handoff && record.writeBackNotes.length === 1 && oid(note.authorId) === oid(ctx.users[actor]) && note.text === text && note.kind === kind;
  };
  for (const state of ['draft', 'submitted', 'acknowledged']) for (const actor of ['A', 'B', 'D', 'C', 'anonymous']) {
    const party = ['A', 'B'].includes(actor);
    const status = actor === 'anonymous' ? 401 : !party ? 403 : state === 'draft' ? 400 : 200;
    test(`handoff note ${state} ${actor} participant boundary`, actor, `${handoff}/notes`, [status], { text: 'Synthetic write-back', kind: 'cant_cover', authorId: ':C' }, {
      prepare: setupHandoff(state), check: status === 200 ? noteCheck(actor, 'Synthetic write-back', 'cant_cover') : undefined,
    });
  }
  for (const [label, body, status] of [['missing text', {}, 400], ['blank text', { text: '  ' }, 400], ['over max', { text: 'x'.repeat(1001) }, 400], ['at max', { text: 'x'.repeat(1000) }, 200], ['kind enum', { text: 'Synthetic', kind: 'admin' }, 400]]) test(`handoff note ${label}`, 'B', `${handoff}/notes`, [status], body, {
    category: 'handoff-note-schema-boundary', check: status === 200 ? noteCheck('B', body.text) : undefined,
  });
  const reassignCheck = actor => async (body, ctx) => {
    const record = await ctx.models.Handoff.findById(ids.handoff).lean();
    const history = record.assignmentHistory.at(-1);
    const notes = record.writeBackNotes;
    const notifications = await ctx.models.Notification.find({ referenceId: ids.handoff }).lean();
    ctx.evidence.notificationRecipients = notifications.map(item => oid(item.userId));
    return oid(body.data?.handoff) === ids.handoff && oid(record.toUserId) === oid(ctx.users.D) && record.status === 'submitted' && record.acknowledgedAt === null && record.acknowledgementNote === '' &&
      record.assignmentHistory.length === 1 && oid(history.fromUserId) === oid(ctx.users.B) && oid(history.toUserId) === oid(ctx.users.D) && oid(history.byUserId) === oid(ctx.users[actor]) && history.note === 'Synthetic transfer' &&
      notes.length === 1 && oid(notes[0].authorId) === oid(ctx.users[actor]) && notes[0].kind === 'reassign' &&
      notifications.length === 1 && oid(notifications[0].userId) === oid(ctx.users.D);
  };
  for (const state of ['draft', 'submitted', 'acknowledged']) for (const actor of ['A', 'B', 'D', 'C', 'anonymous']) {
    const party = ['A', 'B'].includes(actor);
    // Draft guard precedes party authorization in the actual controller.
    const status = actor === 'anonymous' ? 401 : state === 'draft' ? 400 : party ? 200 : 403;
    test(`handoff reassign ${state} ${actor} role boundary`, actor, `${handoff}/reassign`, [status], { toUserId: ':D', note: 'Synthetic transfer', byUserId: ':C' }, {
      prepare: setupHandoff(state), check: status === 200 ? reassignCheck(actor) : undefined,
    });
  }
  for (const [label, body, status] of [['missing target', {}, 400], ['malformed target', { toUserId: 'bad' }, 400], ['absent target', { toUserId: ids.absentUser }, 400], ['foreign target', { toUserId: ':C' }, 400], ['current assignee replay', { toUserId: ':B' }, 400], ['note above max', { toUserId: ':D', note: 'x'.repeat(501) }, 400]]) test(`handoff reassign ${label}`, 'A', `${handoff}/reassign`, [status], body, { prepare: setupHandoff(), category: 'handoff-reassign-schema-boundary' });
  test('handoff reassign inactive member should be unavailable', 'A', `${handoff}/reassign`, [400], { toUserId: ':I' }, {
    prepare: async ctx => { await member(ctx, 'I'); }, failureClassification: 'likely security finding / inactive handoff assignee accepted',
    check: async (_body, ctx, response) => {
      if (response.status >= 400) return true;
      const record = await ctx.models.Handoff.findById(ids.handoff).lean();
      ctx.evidence.inactiveAssigneePersisted = oid(record.toUserId) === oid(ctx.users.I);
      ctx.evidence.assignmentHistoryCount = record.assignmentHistory.length;
      ctx.evidence.inactiveRecipientNotified = !!(await ctx.models.Notification.exists({ referenceId: ids.handoff, userId: ctx.users.I._id }));
      return !ctx.evidence.inactiveAssigneePersisted;
    },
  });
  test('handoff reassignment replay preserves one history and revokes former assignee writes', 'B', `${handoff}/reassign`, [403], { toUserId: ':A' }, {
    prepare: async ctx => {
      await setupHandoff()(ctx);
      assert.equal((await ctx.http('A', 'POST', `${handoff}/reassign`, { toUserId: oid(ctx.users.D), note: 'Synthetic transfer' })).status, 200, 'Reassign lifecycle prerequisite failed');
      assert.equal((await ctx.http('A', 'POST', `${handoff}/reassign`, { toUserId: oid(ctx.users.D) })).status, 400, 'Reassignment same-target replay control failed');
    }, check: async (_body, ctx) => {
      const deniedNote = await ctx.http('B', 'POST', `${handoff}/notes`, { text: 'Former assignee attempt' });
      return deniedNote.status === 403 && (await ctx.models.Handoff.findById(ids.handoff)).assignmentHistory.length === 1;
    },
  });
  for (const action of ['notes', 'reassign']) test(`removed handoff participant ${action} lifecycle policy`, 'B', `${handoff}/${action}`, [200], action === 'notes' ? { text: 'Synthetic removed-party audit note' } : { toUserId: ':D', note: 'Synthetic transfer' }, {
    securityInvariant: 'Lifecycle policy review: removed participants retain source-authorized handoff writes despite REST space revocation. This supported behavior requires an explicit audit/continuity policy decision.',
    prepare: async ctx => {
      await setupHandoff()(ctx);
      assert.equal((await ctx.http('A', 'DELETE', `/api/spaces/${ids.space}/members/${oid(ctx.users.B)}`)).status, 200, 'Removed participant prerequisite failed');
      assert.equal((await ctx.http('B', 'GET', `/api/channels/${ids.channel}/messages`)).status, 403, 'Removed participant REST denial control failed');
    }, failureClassification: 'lifecycle policy review / removed handoff party retains source-authorized write access',
    check: (_body, ctx) => { ctx.evidence.removedPartyWriteAccepted = true; return false; },
  });
  for (const action of ['notes', 'reassign']) for (const [label, id, status] of [['malformed', 'bad', 400], ['absent', ids.absentUser, 404]]) test(`handoff ${action} ${label} resource`, 'A', `/api/handoffs/${id}/${action}`, [status], action === 'notes' ? { text: 'Synthetic' } : { toUserId: ':B' }, { category: 'handoff-resource-object-id' });
};
