'use strict';
const assert = require('node:assert/strict');

// Bounded Phase 4 HTTP work. No provider delivery or browser link navigation.
module.exports = ({ add, ids }) => {
  const oid = value => String(value?._id || value || '');
  const messages = `/api/channels/${ids.channel}/messages`;
  const reaction = `${messages}/${ids.messageA}/react`;
  const pin = `/api/channels/${ids.channel}/pin/${ids.messageA}`;
  const test = (name, actor, method, endpoint, statuses, body, options = {}) => add(name, actor, method, endpoint, statuses, body, {
    module: 'Phase 4 Bounded HTTP', category: 'http-authorization-boundary',
    context: 'Synthetic public/private/DM resources and local SupportTickets; per-case settled snapshots and selective reset; no production providers.',
    sources: ['src/features/messages/message.routes.js', 'src/features/messages/message.controller.js', 'src/features/messages/message.model.js',
      'src/features/channels/channel.controller.js', 'src/utils/channelAccess.js', 'src/services/notification.service.js', 'src/features/support/support.controller.js'], ...options,
  });
  const privateChannel = ctx => ctx.models.Channel.updateOne({ _id: ids.channel }, { isPrivate: true, members: [ctx.users.A._id] });
  for (const actor of ['A', 'B', 'C', 'anonymous']) test(`reaction ${actor} channel membership and identity`, actor, 'POST', reaction, [actor === 'anonymous' ? 401 : actor === 'C' ? 403 : 200], { emoji: '👍', userId: ':C' }, {
    check: ['A', 'B'].includes(actor) ? async (_body, ctx) => {
      const message = await ctx.models.Message.findById(ids.messageA);
      return message.reactions.length === 1 && message.reactions[0].emoji === '👍' && message.reactions[0].userIds.map(oid).join(',') === oid(ctx.users[actor]);
    } : undefined,
  });
  test('reaction toggle and replacement keep one emoji per user', 'B', 'POST', reaction, [200], undefined, {
    run: async ctx => {
      for (const emoji of ['👍', '👍']) assert.equal((await ctx.http('B', 'POST', reaction, { emoji })).status, 200, 'Reaction toggle control failed');
      assert.equal((await ctx.models.Message.findById(ids.messageA)).reactions.length, 0, 'Same emoji toggle did not remove reaction');
      assert.equal((await ctx.http('B', 'POST', reaction, { emoji: '👍' })).status, 200, 'Reaction replacement prerequisite failed');
      return ctx.http('B', 'POST', reaction, { emoji: '✅' });
    }, check: async (_body, ctx) => {
      const message = await ctx.models.Message.findById(ids.messageA);
      return message.reactions.length === 1 && message.reactions[0].emoji === '✅' && message.reactions[0].userIds.map(oid).join(',') === oid(ctx.users.B);
    },
  });
  test('reaction foreign message bound to URL channel', 'A', 'POST', `${messages}/${ids.otherMessage}/react`, [403], { emoji: '👍' });
  test('reaction deleted message denied', 'A', 'POST', reaction, [400], { emoji: '👍' }, { prepare: ctx => ctx.models.Message.updateOne({ _id: ids.messageA }, { isDeleted: true }) });
  test('reaction archived channel denied', 'A', 'POST', reaction, [403], { emoji: '👍' }, { prepare: ctx => ctx.models.Channel.updateOne({ _id: ids.channel }, { isArchived: true }) });
  test('reaction private excluded peer denied', 'B', 'POST', reaction, [403], { emoji: '👍' }, { prepare: privateChannel });
  test('reaction removed member denied', 'B', 'POST', reaction, [403], { emoji: '👍' }, { prepare: ctx => ctx.models.Space.updateOne({ _id: ids.space }, { $pull: { members: { userId: ctx.users.B._id } } }) });
  for (const [label, body] of [['missing emoji', {}], ['empty emoji', { emoji: '' }], ['object emoji', { emoji: { invalid: true } }]]) test(`reaction ${label} validation`, 'B', 'POST', reaction, [400], body, { category: 'reaction-schema-boundary' });
  const seedPin = async ctx => {
    await privateChannel(ctx);
    const control = await ctx.http('A', 'POST', pin, {});
    assert.equal(control.status, 200, 'Private pin authorized control failed');
    assert.equal((await ctx.models.Channel.findById(ids.channel)).pinnedMessages.length, 1, 'Private pin control did not persist');
    ctx.evidence.authorizedPinPersisted = true;
  };
  test('private pin authorized owner persistence', 'A', 'POST', pin, [200], {}, {
    prepare: privateChannel, check: async (_body, ctx) => {
      const channel = await ctx.models.Channel.findById(ids.channel);
      return channel.pinnedMessages.length === 1 && oid(channel.pinnedMessages[0].messageId) === ids.messageA && oid(channel.pinnedMessages[0].pinnedBy) === oid(ctx.users.A);
    },
  });
  test('private pin excluded same-space peer denied', 'B', 'POST', pin, [403], {}, { prepare: privateChannel, failureClassification: 'likely security finding / private pin authorization' });
  test('private unpin excluded same-space peer denied', 'B', 'DELETE', pin, [403], undefined, { prepare: seedPin, failureClassification: 'likely security finding / private unpin authorization' });
  test('private unpin authorized owner and no-op replay', 'A', 'DELETE', pin, [200], undefined, {
    prepare: seedPin, check: async (_body, ctx) => {
      const replay = await ctx.http('A', 'DELETE', pin);
      return replay.status === 200 && (await ctx.models.Channel.findById(ids.channel)).pinnedMessages.length === 0;
    },
  });
  test('private pin replay conflict preserves exact pin', 'A', 'POST', pin, [409], {}, { prepare: seedPin });
  test('pin cross-message binding', 'A', 'POST', `/api/channels/${ids.channel}/pin/${ids.otherMessage}`, [404], {}, { prepare: privateChannel });
  test('archived channel pin policy', 'A', 'POST', pin, [403], {}, {
    prepare: ctx => ctx.models.Channel.updateOne({ _id: ids.channel }, { isArchived: true }), failureClassification: 'hardening / archived-channel mutation policy',
  });
  test('quoted reply same-channel identity snapshot', 'A', 'POST', messages, [201], { content: { text: 'Synthetic quote' }, replyToId: ids.messageB }, {
    check: async (body, ctx) => {
      const message = body.data?.message?._id && await ctx.models.Message.findById(body.data.message._id);
      return !!message && oid(message.channelId) === ids.channel && oid(message.replyTo?.messageId) === ids.messageB && oid(message.replyTo?.senderId) === oid(ctx.users.B) && message.threadId === null;
    },
  });
  test('quoted reply rejects foreign parent independently of thread binding', 'A', 'POST', messages, [400], { content: { text: 'Synthetic foreign quote' }, replyToId: ids.otherMessage });
  for (const [label, target, privateMode, allowed] of [['member canary', 'B', false, true], ['foreign outsider', 'C', false, false], ['private excluded member', 'B', true, false], ['inactive identity', 'I', false, false]]) test(`mention notification ${label} recipient boundary`, 'A', 'POST', messages, [201], { content: { text: 'Synthetic mention privacy canary' }, mentions: [`:${target}`] }, {
    category: 'mention-notification-authorization', failureClassification: 'likely security finding / unauthorized mention notification disclosure',
    prepare: async ctx => {
      if (privateMode) await privateChannel(ctx);
      if (!allowed) {
        const canary = privateMode ? 'D' : 'B';
        if (privateMode) {
          await ctx.models.Space.updateOne({ _id: ids.space }, { $push: { members: { userId: ctx.users.D._id, role: 'member' } } });
          await ctx.models.Channel.updateOne({ _id: ids.channel }, { $push: { members: ctx.users.D._id } });
        }
        const control = await ctx.http('A', 'POST', messages, { content: { text: 'Synthetic authorized mention control' }, mentions: [oid(ctx.users[canary])] });
        assert.equal(control.status, 201, 'Mention sender authorized control failed');
        let observed = false;
        for (let attempt = 0; attempt < 20; attempt += 1) {
          observed = !!(await ctx.models.Notification.exists({ referenceId: control.data.data.message._id, userId: ctx.users[canary]._id, type: 'mention' }));
          if (observed) break;
          await new Promise(resolve => setTimeout(resolve, 50));
        }
        assert.ok(observed, 'Authorized mention recipient canary missing');
        ctx.evidence.authorizedMentionRecipientObserved = true;
      }
    }, check: async (body, ctx) => {
      const notifications = await ctx.models.Notification.find({ referenceId: body.data?.message?._id, type: 'mention' }).lean();
      ctx.evidence.mentionRecipients = notifications.map(item => oid(item.userId));
      ctx.evidence.mentionPreviewMatched = notifications.some(item => item.body === 'Synthetic mention privacy canary');
      return allowed ? notifications.length === 1 && oid(notifications[0].userId) === oid(ctx.users[target]) : notifications.length === 0;
    },
  });
  for (const type of ['bug', 'feature', 'feedback']) {
    const endpoint = `/api/support/${type}`;
    test(`support ${type} caller attribution and ownership injection`, 'B', 'POST', endpoint, [201], { title: 'Synthetic support', description: 'Synthetic report only', userId: ':A', userPhone: '+15559990001', type: 'admin', status: 'closed' }, {
      check: async (body, ctx) => {
        const ticket = body.data?.ticketId && await ctx.models.SupportTicket.findById(body.data.ticketId).lean();
        ctx.evidence.ticketId = body.data?.ticketId || null;
        return !!ticket && oid(ticket.userId) === oid(ctx.users.B) && ticket.userPhone === ctx.users.B.phone && ticket.type === type && ticket.status === 'open' && ticket.title === 'Synthetic support' &&
          !['userPhone', 'userId', 'description'].some(key => key in body.data);
      },
    });
    test(`support ${type} declared truncation boundaries`, 'B', 'POST', endpoint, [201], { title: 't'.repeat(201), description: 'd'.repeat(5001), steps: 's'.repeat(3001), context: 'c'.repeat(3001) }, {
      check: async (body, ctx) => {
        const ticket = body.data?.ticketId && await ctx.models.SupportTicket.findById(body.data.ticketId);
        return !!ticket && ticket.title.length === 200 && ticket.description.length === 5000 &&
          (type !== 'bug' || ticket.steps.length === 3000) && (type !== 'feature' || ticket.context.length === 3000);
      },
    });
    for (const [label, body] of [['missing title', { description: 'Synthetic' }], ['missing description', { title: 'Synthetic' }], ['whitespace', { title: ' ', description: ' ' }], ['non-string title', { title: {}, description: 'Synthetic' }]]) test(`support ${type} ${label}`, 'B', 'POST', endpoint, [400], body, { category: 'support-schema-boundary' });
    test(`support ${type} anonymous`, 'anonymous', 'POST', endpoint, [401], { title: 'Synthetic', description: 'Synthetic' });
  }
};
