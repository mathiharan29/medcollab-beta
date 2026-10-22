'use strict';

// Direct-message cases are registered into the existing serial discovery runner.
// They intentionally use real request setup/checks: model access only seeds and
// independently verifies the disposable local database.
module.exports = function registerDirectMessageCases({ add, ids }) {
  const dm = ids.dmAB;
  const mp = `/api/channels/${dm}/messages`;
  const otherMessage = ids.dmOtherMessage;
  const directSources = [
    'src/features/channels/channel.routes.js',
    'src/features/channels/channel.controller.js',
    'src/utils/channelAccess.js',
  ];
  const addDm = (name, actor, method, endpoint, statuses, body, options = {}) => add(
    name, actor, method, endpoint, statuses, body,
    {
      module: 'Direct Messages',
      context: 'A and B are direct-message participants; D is a same-institution medical peer but not a participant; E–H are unrelated fixture identities.',
      sources: directSources,
      ...options,
    },
  );
  const hasChannel = (body, id) => body.data?.channels?.some((channel) => channel._id === id);
  const exactlyMembers = (channel, first, second) => {
    const members = (channel?.members || []).map((member) => String(member._id || member)).sort();
    return members.length === 2 && members.join(',') === [String(first), String(second)].sort().join(',');
  };
  const persistedPair = async (ctx, channelId, first, second) => {
    const channel = channelId && await ctx.models.Channel.findById(channelId).lean();
    return !!channel && channel.type === 'direct' && !channel.spaceId &&
      exactlyMembers(channel, first, second);
  };
  const persistedMessage = async (body, ctx, expected) => {
    const id = body.data?.message?._id;
    const message = id && await ctx.models.Message.findById(id).lean();
    return !!message && String(message.channelId) === expected.channelId &&
      String(message.senderId) === String(expected.senderId) &&
      (expected.threadId === undefined || String(message.threadId) === String(expected.threadId)) &&
      message.content?.text === expected.text;
  };

  for (const actor of ['A', 'B', 'D', 'anonymous']) {
    const participant = actor === 'A' || actor === 'B';
    addDm('list direct-message conversations', actor, 'GET', '/api/channels/dm', [participant ? 200 : actor === 'anonymous' ? 401 : 200], undefined, {
      category: 'direct-list-isolation',
      check: participant
        ? (body) => hasChannel(body, dm)
        : actor === 'D'
          ? (body) => !hasChannel(body, dm)
          : undefined,
    });
    addDm('read direct-message channel detail', actor, 'GET', `/api/channels/${dm}`, [participant ? 200 : actor === 'anonymous' ? 401 : 403], undefined, {
      category: 'direct-participant-access',
      check: participant ? (body, ctx) => body.data?.channel?._id === dm && exactlyMembers(body.data.channel, ctx.users.A._id, ctx.users.B._id) : undefined,
    });
    addDm('read direct-message member metadata', actor, 'GET', `/api/channels/${dm}/members`, [participant ? 200 : actor === 'anonymous' ? 401 : 403], undefined, {
      category: 'direct-member-metadata-isolation',
      sources: [...directSources, 'src/features/channels/channel.controller.js:getChannelMembers'],
      check: actor === 'anonymous' ? undefined : (body, ctx) => {
        const members = body.data?.members || [];
        ctx.evidence.returnedMemberIds = members.map(member => String(member._id)).sort();
        ctx.evidence.returnedMemberFields = [...new Set(members.flatMap(member => Object.keys(member || {})))].sort();
        return participant ? exactlyMembers({ members }, ctx.users.A._id, ctx.users.B._id) : true;
      },
    });
    addDm('read direct-message messages', actor, 'GET', mp, [participant ? 200 : actor === 'anonymous' ? 401 : 403], undefined, {
      category: 'direct-participant-access',
      sources: [...directSources, 'src/features/messages/message.controller.js:getMessages'],
      check: participant ? (body) => {
        const messages = body.data?.messages || [];
        const messageIds = messages.map(message => message._id).sort();
        return messageIds.join(',') === [ids.dmMessageA, ids.dmMessageB].sort().join(',') &&
          messages.every(message => String(message.channelId) === dm);
      } : undefined,
    });
    addDm('send direct-message text', actor, 'POST', mp, [participant ? 201 : actor === 'anonymous' ? 401 : 403], { type: 'text', content: { text: 'Direct security fixture message' } }, {
      category: 'direct-write-participant-access',
      sources: [...directSources, 'src/features/messages/message.controller.js:sendMessage'],
      check: participant ? (body, ctx) => persistedMessage(body, ctx, {
        channelId: dm, senderId: ctx.users[actor]._id, text: 'Direct security fixture message',
      }) : undefined,
    });
  }

  addDm('existing DM creation returns the fixed pair', 'A', 'POST', '/api/channels/dm', [200], { userId: ':B' }, {
    category: 'direct-idempotence',
    check: async (body, ctx) => body.data?.channel?._id === dm && exactlyMembers(body.data.channel, ctx.users.A._id, ctx.users.B._id) &&
      await persistedPair(ctx, dm, ctx.users.A._id, ctx.users.B._id) &&
      await ctx.models.Channel.countDocuments({ type: 'direct', members: { $all: [ctx.users.A._id, ctx.users.B._id], $size: 2 } }) === 1,
  });
  addDm('same-institution alone cannot create a DM', 'A', 'POST', '/api/channels/dm', [403], { userId: ':D' }, {
    category: 'direct-known-user-denial',
    check: async (_body, ctx) => await ctx.models.Channel.countDocuments({
      type: 'direct', members: { $all: [ctx.users.A._id, ctx.users.D._id], $size: 2 },
    }) === 0,
  });
  addDm('accepted message-request permits DM creation', 'E', 'POST', '/api/channels/dm', [200], { userId: ':H' }, {
    category: 'direct-accepted-request-binding',
    check: async (body, ctx) => exactlyMembers(body.data?.channel, ctx.users.E._id, ctx.users.H._id) &&
      await persistedPair(ctx, body.data.channel._id, ctx.users.E._id, ctx.users.H._id),
  });
  addDm('unrelated identity cannot create a DM', 'E', 'POST', '/api/channels/dm', [403], { userId: ':F' }, { category: 'direct-unrelated-identity' });
  addDm('self DM creates caller-only self notes', 'E', 'POST', '/api/channels/dm', [200], { userId: ':E' }, {
    category: 'direct-self-notes-isolation',
    check: async (body, ctx) => {
      const channel = body.data?.channel;
      const persisted = channel?._id && await ctx.models.Channel.findById(channel._id).lean();
      // isSelfNotes is derived by enrichDM for the response, not a schema field.
      const callerOnly = channel?.isSelfNotes === true && persisted && persisted.type === 'direct' && !persisted.spaceId &&
        String(persisted.createdBy) === String(ctx.users.E._id) && (persisted.members || []).length === 1 &&
        String(persisted.members[0]) === String(ctx.users.E._id);
      if (!callerOnly) return false;
      const replay = await ctx.http('E', 'POST', '/api/channels/dm', { userId: String(ctx.users.E._id) });
      const outsider = await ctx.http('D', 'GET', `/api/channels/${channel._id}`);
      return replay.status === 200 && replay.data?.data?.channel?._id === channel._id && outsider.status === 403 &&
        await ctx.models.Channel.countDocuments({ type: 'direct', isArchived: false, members: { $all: [ctx.users.E._id], $size: 1 } }) === 1;
    },
  });
  addDm('inactive DM target is not eligible through relationships', 'A', 'POST', '/api/channels/dm', [403], { userId: ':I' }, { category: 'direct-inactive-target' });
  addDm('absent DM target is not found', 'E', 'POST', '/api/channels/dm', [404], { userId: ids.absentUser }, { category: 'direct-absent-target' });
  addDm('malformed DM target is rejected', 'E', 'POST', '/api/channels/dm', [400], { userId: 'not-an-id' }, { category: 'direct-target-schema' });
  addDm('anonymous DM creation is rejected', 'anonymous', 'POST', '/api/channels/dm', [401], { userId: ':D' }, { category: 'direct-anonymous' });

  for (const [actor, status] of [['A', 200], ['B', 403], ['D', 403], ['anonymous', 401]]) {
    addDm('edit direct-message sender ownership', actor, 'PUT', `${mp}/${ids.dmMessageA}`, [status], { content: { text: 'Direct edit' } }, {
      category: 'direct-message-ownership',
      sources: [...directSources, 'src/features/messages/message.controller.js:editMessage'],
      check: actor === 'A' ? async (_body, ctx) => (await ctx.models.Message.findById(ids.dmMessageA)).content.text === 'Direct edit' : undefined,
    });
  }
  for (const [actor, status] of [['B', 200], ['A', 403], ['D', 403], ['anonymous', 401]]) {
    addDm('delete direct-message sender ownership', actor, 'DELETE', `${mp}/${ids.dmMessageB}`, [status], undefined, {
      category: 'direct-message-ownership',
      sources: [...directSources, 'src/features/messages/message.controller.js:deleteMessage'],
      check: actor === 'B' ? async (_body, ctx) => (await ctx.models.Message.findById(ids.dmMessageB)).isDeleted === true : undefined,
    });
  }

  for (const [actor, status] of [['A', 200], ['B', 200], ['D', 403], ['anonymous', 401]]) {
    addDm('read direct-message thread', actor, 'GET', `${mp}/${ids.dmMessageA}/thread`, [status], undefined, {
      category: 'direct-thread-participant-access',
      sources: [...directSources, 'src/features/messages/message.controller.js:getThread'],
      check: status === 200 ? (body) => body.data?.rootMessage?._id === ids.dmMessageA &&
        String(body.data.rootMessage.channelId) === dm &&
        (body.data?.replies || []).every(reply => String(reply.channelId) === dm && String(reply.threadId) === ids.dmMessageA) : undefined,
    });
  }
  addDm('reply to direct-message thread as participant', 'B', 'POST', `${mp}/${ids.dmMessageA}/reply`, [201], { type: 'text', content: { text: 'Direct reply' } }, {
    category: 'direct-thread-participant-access',
    check: (body, ctx) => persistedMessage(body, ctx, {
      channelId: dm, senderId: ctx.users.B._id, threadId: ids.dmMessageA, text: 'Direct reply',
    }),
  });
  addDm('outsider cannot reply to direct-message thread', 'D', 'POST', `${mp}/${ids.dmMessageA}/reply`, [403], { type: 'text', content: { text: 'Foreign direct reply' } }, { category: 'direct-thread-participant-access' });

  for (const actor of ['A', 'B']) {
    for (const [action, method, suffix, body] of [
      ['thread', 'GET', '/thread', undefined],
      ['edit', 'PUT', '', { content: { text: 'Foreign direct edit' } }],
      ['delete', 'DELETE', '', undefined],
      ['reply', 'POST', '/reply', { type: 'text', content: { text: 'Foreign direct reply' } }],
    ]) {
      addDm(`foreign direct-message ID ${action}`, actor, method, `${mp}/${otherMessage}${suffix}`, [403, 404], body, {
        category: 'direct-foreign-message-binding',
        sources: [...directSources, 'src/utils/channelAccess.js:assertMessageInChannel'],
        check: action === 'reply' ? async (responseBody, ctx, response) => {
          if (response.status >= 400) return true;
          const reply = responseBody.data?.message?._id && await ctx.models.Message.findById(responseBody.data.message._id).lean();
          return !reply || String(reply.channelId) !== dm || String(reply.threadId) !== otherMessage;
        } : undefined,
      });
    }
  }

  addDm('DM recipient records a read receipt only in its channel', 'B', 'POST', `${mp}/read`, [200], { messageIds: [ids.dmMessageA] }, {
    category: 'direct-read-receipt-binding',
    sources: [...directSources, 'src/features/messages/message.controller.js:markAsRead'],
    check: async (_body, ctx) => (await ctx.models.Message.findById(ids.dmMessageA)).readBy.some((entry) => String(entry.userId) === String(ctx.users.B._id)),
  });
  addDm('DM receipt ignores a foreign message ID', 'B', 'POST', `${mp}/read`, [200], { messageIds: [ids.dmOtherMessage] }, {
    category: 'direct-read-receipt-foreign-id',
    sources: [...directSources, 'src/features/messages/message.controller.js:markAsRead'],
    check: async (_body, ctx) => !(await ctx.models.Message.findById(ids.dmOtherMessage)).readBy.some((entry) => String(entry.userId) === String(ctx.users.B._id)),
  });
  addDm('DM outsider cannot record a receipt', 'D', 'POST', `${mp}/read`, [403], { messageIds: [ids.dmMessageA] }, { category: 'direct-read-receipt-binding' });
  addDm('anonymous caller cannot record a DM receipt', 'anonymous', 'POST', `${mp}/read`, [401], { messageIds: [ids.dmMessageA] }, { category: 'direct-read-receipt-binding' });

  addDm('DM participant can pin its conversation message', 'B', 'POST', `/api/channels/${dm}/pin/${ids.dmMessageA}`, [200], undefined, {
    category: 'direct-pin-participant-access',
    check: async (_body, ctx) => (await ctx.models.Channel.findById(dm)).pinnedMessages.some((pin) => String(pin.messageId) === ids.dmMessageA && String(pin.pinnedBy) === String(ctx.users.B._id)),
  });
  addDm('DM outsider cannot pin a conversation message', 'D', 'POST', `/api/channels/${dm}/pin/${ids.dmMessageA}`, [403], undefined, { category: 'direct-pin-participant-access' });
  addDm('DM participant cannot pin a foreign message', 'A', 'POST', `/api/channels/${dm}/pin/${ids.dmOtherMessage}`, [404], undefined, { category: 'direct-pin-foreign-message' });
  addDm('DM outsider cannot unpin conversation metadata', 'D', 'DELETE', `/api/channels/${dm}/pin/${ids.dmMessageA}`, [403], undefined, { category: 'direct-pin-participant-access' });

  addDm('archived DM participant cannot read messages', 'E', 'GET', `/api/channels/${ids.dmArchived}/messages`, [403], undefined, { category: 'direct-archived-channel' });
  addDm('archived DM participant cannot send messages', 'E', 'POST', `/api/channels/${ids.dmArchived}/messages`, [403], { type: 'text', content: { text: 'Archived direct write' } }, { category: 'direct-archived-channel' });
};
