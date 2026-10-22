'use strict';

// Appended-only repairs: these controls deliberately begin after the legacy
// 352 registrations so historical VOCLE IDs never move.
module.exports = ({ add, ids }) => {
  const base = '/api/message-requests';
  const sources = [
    'src/features/message-requests/messageRequest.routes.js',
    'src/features/message-requests/messageRequest.controller.js',
    'src/utils/knownUsers.js',
  ];
  const pairCount = (ctx, from, to) => ctx.models.MessageRequest.countDocuments({
    fromUserId: ctx.users[from]._id,
    toUserId: ctx.users[to]._id,
  });
  const noDm = (ctx, from, to) => ctx.models.Channel.countDocuments({
    // A pre-existing archived E/G fixture is not an opened conversation.
    type: 'direct', isArchived: false, members: { $all: [ctx.users[from]._id, ctx.users[to]._id], $size: 2 },
  });
  for (const [label, from, to, existingFrom, existingTo, expectedId, expectedActionPairCount] of [
    ['pending replay target', 'E', 'F', 'E', 'F', ids.requestPending, 1],
    ['reciprocal pending target', 'F', 'E', 'E', 'F', ids.requestPending, 0],
    ['declined replay target', 'E', 'G', 'E', 'G', ids.requestDeclined, 1],
  ]) add(`opted-out ${label} denies request before lifecycle handling`, from, 'POST', base, [403], { toUserId: `:${to}` }, {
    module: 'Phase 0 Repair Controls',
    category: 'message-request-opted-out-denial',
    context: 'Controlled unrelated fixture identities have no shared space. The target remains opted out; this is a distinct denial control, not a lifecycle positive.',
    sources,
    check: async (_body, ctx) => {
      const exact = await ctx.models.MessageRequest.findById(expectedId).lean();
      return !!exact && (await pairCount(ctx, existingFrom, existingTo)) === 1 &&
        (await pairCount(ctx, from, to)) === expectedActionPairCount && (await noDm(ctx, from, to)) === 0;
    },
  });
};
