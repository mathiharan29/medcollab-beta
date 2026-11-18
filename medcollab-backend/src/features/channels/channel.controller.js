/**
 * CHANNEL CONTROLLER
 */

const Channel = require('./channel.model');
const Space = require('../spaces/space.model');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { CHANNEL_TYPES } = require('../../constants');

/**
 * POST /api/spaces/:spaceId/channels
 * Create a new channel inside a space
 */
const createChannel = asyncHandler(async (req, res) => {
  const { spaceId } = req.params;
  const { name, description, isPrivate, type } = req.body;

  const space = await Space.findById(spaceId);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isMember(req.user._id)) return respond.forbidden(res, 'Not a space member');

  // Check for duplicate channel name in this space
  const existing = await Channel.findOne({ spaceId, name: name.toLowerCase() });
  if (existing) return respond.conflict(res, `Channel #${name} already exists`);

  const channel = await Channel.create({
    spaceId,
    name: name.toLowerCase(),
    description: description?.trim() || '',
    type: type || CHANNEL_TYPES.GENERAL,
    isPrivate: isPrivate || false,
    members: isPrivate ? [req.user._id] : [],
    createdBy: req.user._id,
  });

  return respond.created(res, `Channel #${channel.name} created`, { channel });
});

/**
 * GET /api/spaces/:spaceId/channels
 * List all accessible channels in a space (sorted by position)
 */
const getSpaceChannels = asyncHandler(async (req, res) => {
  const { spaceId } = req.params;

  const space = await Space.findById(spaceId);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isMember(req.user._id)) return respond.forbidden(res, 'Not a space member');

  const channels = await Channel.find({
    spaceId,
    isArchived: false,
    $or: [
      { isPrivate: false },                       // All public channels
      { members: req.user._id },                  // Private channels they're in
    ],
  }).sort({ position: 1, createdAt: 1 }).lean();

  const { personalizeLastMessages } = require('../../utils/personalLastMessage');
  const personal = await personalizeLastMessages(channels, req.user._id);
  return respond.ok(res, 'Channels fetched', { channels: personal });
});

/**
 * GET /api/channels/:id
 * Get a single channel with its pinned messages
 */
const getChannelById = asyncHandler(async (req, res) => {
  const { resolveChannelAccessById } = require('../../utils/channelAccess');
  const access = await resolveChannelAccessById(
    req.params.id,
    req.user._id,
    res,
    { allowArchived: true }
  );
  if (!access) return;

  let channel = await Channel.findById(req.params.id)
    .populate({
      path: 'pinnedMessages.messageId',
      populate: { path: 'senderId', select: 'name displayTitle role avatarUrl' },
    })
    .populate('members', 'name displayTitle role avatarUrl speciality department institution availability')
    .lean();

  if (!channel) return respond.notFound(res, 'Channel not found');

  if (channel.type === CHANNEL_TYPES.DIRECT) {
    channel = enrichDM(channel, req.user._id);
  }

  // Pinned bar and preview follow this user's delete-for-me / clear chat.
  const { personalizePinned, personalizeLastMessages } = require('../../utils/personalLastMessage');
  channel = await personalizePinned(channel, req.user._id);
  [channel] = await personalizeLastMessages([channel], req.user._id);

  return respond.ok(res, 'Channel fetched', { channel });
});

/**
 * PUT /api/channels/:id
 * Update channel name or description (space admin, or any member of a group DM)
 */
const updateChannel = asyncHandler(async (req, res) => {
  const channel = await Channel.findById(req.params.id);
  if (!channel) return respond.notFound(res, 'Channel not found');

  const isDirect =
    channel.type === CHANNEL_TYPES.DIRECT || !channel.spaceId;
  const isMember = (channel.members || []).some(
    (m) => m.toString() === req.user._id.toString()
  );

  const sys = require('../../utils/systemMessages');

  if (isDirect) {
    if (!isMember) return respond.forbidden(res, 'Not a conversation member');
    const before = (channel.name || '').trim();
    if (req.body.name !== undefined) {
      const name = String(req.body.name).trim().slice(0, 80);
      channel.name = name || null;
    }
    await channel.save();
    const after = (channel.name || '').trim();
    // Needl (3+ people) rename → activity line, like a WhatsApp group.
    if (after && after !== before && (channel.members || []).length > 2) {
      await sys.postSystemMessage({
        channel,
        actor: req.user,
        event: sys.SYSTEM_EVENTS.GROUP_RENAMED,
        text: `${sys.personName(req.user)} changed the chat name to "${after}"`,
        notifyUserIds: channel.members.map((m) => m.toString()),
      });
    }
    const populated = await Channel.findById(channel._id)
      .populate(
        'members',
        'name displayTitle role speciality avatarUrl availability lastSeenAt'
      )
      .lean();
    return respond.ok(res, 'Conversation renamed', {
      channel: enrichDM(populated, req.user._id),
    });
  }

  const space = await Space.findById(channel.spaceId);
  if (!space?.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  const allowed = ['description', 'onlyAdminsCanPost'];
  allowed.forEach((f) => {
    if (req.body[f] !== undefined) channel[f] = req.body[f];
  });
  // Name updates only allowed for non-default channels
  const previousName = channel.name;
  if (req.body.name && !['general', 'emergency', 'academics'].includes(channel.name)) {
    channel.name = req.body.name.toLowerCase();
  }

  await channel.save();
  if (channel.name !== previousName) {
    await sys.postSystemMessage({
      channel,
      actor: req.user,
      event: sys.SYSTEM_EVENTS.CHANNEL_RENAMED,
      text: `${sys.personName(req.user)} renamed this channel to #${channel.name}`,
      notifyUserIds: space.members.map((m) => m.userId.toString()),
    });
  }
  return respond.ok(res, 'Channel updated', { channel });
});

/**
 * DELETE /api/channels/:id
 * Archive a channel (soft delete — messages preserved)
 */
const archiveChannel = asyncHandler(async (req, res) => {
  const channel = await Channel.findById(req.params.id);
  if (!channel) return respond.notFound(res, 'Channel not found');

  const space = await Space.findById(channel.spaceId);
  if (!space?.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  if (['general', 'emergency', 'academics'].includes(channel.name)) {
    return respond.badRequest(res, 'Default channels cannot be archived');
  }

  channel.isArchived = true;
  await channel.save();

  return respond.ok(res, `Channel #${channel.name} archived`);
});

/**
 * Enrich a DM channel lean doc with peer + display name for the caller.
 */
const enrichDM = (channel, currentUserId) => {
  const members = channel.members || [];
  const others = members.filter(
    (m) => (m._id || m).toString() !== currentUserId.toString()
  );
  const peer = others[0] || null;
  const isSelfNotes = members.length === 1;
  const isNeedl = members.length > 2;

  const memberLabel = (m) =>
    [m?.displayTitle, m?.name].filter(Boolean).join(' ').trim() ||
    m?.name ||
    m?.displayTitle ||
    '';

  let name = channel.name && String(channel.name).trim();
  if (!name || name.toLowerCase() === 'direct message' || name === 'channel') {
    if (isSelfNotes) {
      name = 'Notes to self';
    } else if (isNeedl) {
      name =
        others
          .map(memberLabel)
          .filter(Boolean)
          .slice(0, 4)
          .join(', ') || 'Needl';
    } else {
      name = memberLabel(peer) || 'Direct message';
    }
  } else if (isNeedl) {
    // After expanding a 1:1, stale titles sometimes equal one peer's name.
    const otherNames = others.map(memberLabel).filter(Boolean);
    if (
      otherNames.length >= 2 &&
      otherNames.some((n) => name === n)
    ) {
      name = otherNames.slice(0, 4).join(', ');
    }
  }

  return {
    ...channel,
    peer: peer || (isSelfNotes ? members[0] || null : null),
    name,
    isSelfNotes,
    isNeedl,
  };
};

/**
 * GET /api/channels/dm
 * List all DM conversations for the authenticated user
 */
const getMyDMs = asyncHandler(async (req, res) => {
  const channels = await Channel.find({
    type: CHANNEL_TYPES.DIRECT,
    members: req.user._id,
    isArchived: false,
  })
    .populate(
      'members',
      'name displayTitle role speciality avatarUrl availability lastSeenAt'
    )
    .sort({ 'lastMessage.sentAt': -1, updatedAt: -1 })
    .lean();

  const { personalizeLastMessages } = require('../../utils/personalLastMessage');
  const personal = await personalizeLastMessages(channels, req.user._id);
  const enriched = personal.map((ch) => enrichDM(ch, req.user._id));
  return respond.ok(res, 'DMs fetched', { channels: enriched });
});

/**
 * POST /api/channels/dm
 * Create or retrieve a 1:1 DM channel between two users
 * Idempotent — always returns the same channel for the same pair
 */
const createOrGetDM = asyncHandler(async (req, res) => {
  const { userId: targetUserId } = req.body;

  // Notes-to-self: single-member DM with own user id.
  const isSelfNotes =
    !targetUserId || targetUserId === req.user._id.toString();

  if (isSelfNotes) {
    let channel = await Channel.findOne({
      type: CHANNEL_TYPES.DIRECT,
      members: { $size: 1, $all: [req.user._id] },
      isArchived: false,
    });
    if (!channel) {
      channel = await Channel.create({
        spaceId: null,
        type: CHANNEL_TYPES.DIRECT,
        members: [req.user._id],
        createdBy: req.user._id,
        name: 'Notes to self',
      });
    }
    const populated = await Channel.findById(channel._id)
      .populate(
        'members',
        'name displayTitle role speciality avatarUrl availability lastSeenAt'
      )
      .lean();
    return respond.ok(res, 'Self notes ready', {
      channel: enrichDM(populated, req.user._id),
    });
  }

  const User = require('../users/user.model');
  const { canMessageUser } = require('../../utils/knownUsers');
  const target = await User.findById(targetUserId).select('_id');
  if (!target) return respond.notFound(res, 'User not found');

  const allowed = await canMessageUser(req.user._id, targetUserId);
  if (!allowed) {
    return respond.forbidden(
      res,
      'Send a message request first — chat opens only after they accept'
    );
  }

  // Atomic find-or-create via memberPairKey (unique). Uses findAndModify so
  // disposable failpoints and concurrent pair opens converge on one DM.
  const { memberPairKey } = require('../../utils/memberPairKey');
  const pairKey = memberPairKey([req.user._id, targetUserId]);
  const members = [req.user._id, targetUserId];

  // DMs saved before memberPairKey existed have no key: adopt the old
  // conversation (and its history) instead of opening a second, empty one.
  await Channel.updateOne(
    {
      type: CHANNEL_TYPES.DIRECT,
      members: { $all: members, $size: 2 },
      $or: [{ memberPairKey: null }, { memberPairKey: { $exists: false } }],
    },
    { $set: { memberPairKey: pairKey } }
  ).catch(() => {
    // A keyed duplicate already exists — the upsert below returns it.
  });

  let channel = await Channel.findOneAndUpdate(
    { type: CHANNEL_TYPES.DIRECT, memberPairKey: pairKey },
    {
      $setOnInsert: {
        spaceId: null,
        type: CHANNEL_TYPES.DIRECT,
        members,
        memberPairKey: pairKey,
        createdBy: req.user._id,
        name: null,
      },
      // An archived 1:1 would open but never show in the Direct list.
      $set: { isArchived: false },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  const populated = await Channel.findById(channel._id)
    .populate(
      'members',
      'name displayTitle role speciality avatarUrl availability lastSeenAt'
    )
    .lean();

  return respond.ok(res, 'DM channel ready', {
    channel: enrichDM(populated, req.user._id),
  });
});

/**
 * POST /api/channels/dm/group
 * Create or get a multi-person DM (Slack-style MPIM).
 * Body: { userIds: string[] } — other participants (caller included automatically).
 */
const createGroupDM = asyncHandler(async (req, res) => {
  const rawIds = Array.isArray(req.body.userIds) ? req.body.userIds : [];
  const uniqueOthers = [
    ...new Set(
      rawIds
        .map((id) => id?.toString())
        .filter((id) => id && id !== req.user._id.toString())
    ),
  ];
  if (uniqueOthers.length < 1) {
    return respond.badRequest(
      res,
      'Select at least one other doctor for a Needl'
    );
  }
  if (uniqueOthers.length === 1) {
    req.body.userId = uniqueOthers[0];
    return createOrGetDM(req, res, () => {});
  }
  if (uniqueOthers.length > 8) {
    return respond.badRequest(res, 'Group DMs support up to 8 other people');
  }

  const User = require('../users/user.model');
  // REQ 5: requests are open to all, but adding someone to a conversation
  // needs an existing relationship (or their opt-in) — see knownUsers.
  const { canAddToConversation } = require('../../utils/knownUsers');

  for (const targetId of uniqueOthers) {
    const target = await User.findById(targetId).select('_id name');
    if (!target) return respond.notFound(res, 'One of the users was not found');
    const allowed = await canAddToConversation(req.user._id, targetId);
    if (!allowed) {
      return respond.forbidden(
        res,
        `${target.name || 'This doctor'} needs to accept a message request from you before joining a Needl`
      );
    }
  }

  const { memberPairKey } = require('../../utils/memberPairKey');
  const memberIds = [req.user._id.toString(), ...uniqueOthers].sort();
  const objectIds = memberIds.map((id) => id);
  const pairKey = memberPairKey(memberIds);

  const users = await User.find({ _id: { $in: uniqueOthers } })
    .select('name displayTitle')
    .lean();
  const defaultName =
    users
      .map(
        (u) =>
          [u.displayTitle, u.name].filter(Boolean).join(' ').trim() || u.name
      )
      .filter(Boolean)
      .slice(0, 4)
      .join(', ') || 'Needl';

  let channel = await Channel.findOneAndUpdate(
    { type: CHANNEL_TYPES.DIRECT, memberPairKey: pairKey },
    {
      $setOnInsert: {
        spaceId: null,
        type: CHANNEL_TYPES.DIRECT,
        members: objectIds,
        memberPairKey: pairKey,
        createdBy: req.user._id,
        name: defaultName,
        isArchived: false,
      },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  const current = (channel.name || '').trim();
  if (!current || current.toLowerCase() === 'direct message') {
    channel.name = defaultName;
    await channel.save();
  }

  const populated = await Channel.findById(channel._id)
    .populate(
      'members',
      'name displayTitle role speciality avatarUrl availability lastSeenAt'
    )
    .lean();

  return respond.ok(res, 'Group DM ready', {
    channel: enrichDM(populated, req.user._id),
  });
});

/**
 * POST /api/channels/:id/expand
 * Slack-style: add people to a DM/Needl by creating a new conversation
 * with optional history copy.
 * Body: { userIds: string[], history: 'all' | 'today' | 'none' }
 */
/**
 * Copy a Needl's history into the expanded conversation. Thread and quote
 * links are remapped to the copies; every copy records its source id so an
 * interrupted copy can be removed and redone (FR-NDL-29). Includes
 * soft-deleted rows so the destination shows "This message was deleted".
 */
async function copyNeedlHistory({ Message, mongoose, sourceId, channel, since }) {
  const filter = { channelId: sourceId };
  if (since) filter.createdAt = { $gte: since };
  const messages = await Message.find(filter).sort({ createdAt: 1 }).lean();
  if (messages.length === 0) return;

  const idMap = new Map();
  for (const m of messages) idMap.set(String(m._id), new mongoose.Types.ObjectId());

  const copies = messages.map((m) => {
    const mappedThread = m.threadId ? idMap.get(String(m.threadId)) || null : null;
    let replyTo = undefined;
    if (m.replyTo?.messageId) {
      replyTo = {
        ...m.replyTo,
        // Remap when the quoted parent was copied; otherwise keep text snapshot.
        messageId: idMap.get(String(m.replyTo.messageId)) || m.replyTo.messageId,
      };
    }
    return {
      _id: idMap.get(String(m._id)),
      channelId: channel._id,
      spaceId: null,
      senderId: m.senderId,
      type: m.type,
      content: m.content,
      priority: m.priority,
      mentions: m.mentions || [],
      replyTo,
      threadId: mappedThread,
      replyCount: m.replyCount || 0,
      isDeleted: Boolean(m.isDeleted),
      deletedAt: m.deletedAt || null,
      copiedFromId: m._id,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    };
  });
  await Message.insertMany(copies, { ordered: true });

  // Preview points at the source message id (product Q2) so deep-links
  // back to the origin conversation remain stable.
  const last = messages[messages.length - 1];
  await Channel.findByIdAndUpdate(channel._id, {
    lastMessage: {
      messageId: last._id,
      text: last.isDeleted ? 'This message was deleted' : last.content?.text?.slice(0, 200) || null,
      senderName: null,
      type: last.type,
      sentAt: last.createdAt,
    },
  });
}

const expandDM = asyncHandler(async (req, res) => {
  const source = await Channel.findById(req.params.id);
  if (!source) return respond.notFound(res, 'Conversation not found');
  if (source.type !== CHANNEL_TYPES.DIRECT && source.spaceId) {
    return respond.badRequest(res, 'Only Needl / DM conversations can be expanded');
  }

  const isMember = (source.members || []).some(
    (m) => m.toString() === req.user._id.toString()
  );
  if (!isMember) return respond.forbidden(res, 'Not a conversation member');

  const rawIds = Array.isArray(req.body.userIds) ? req.body.userIds : [];
  const history = ['all', 'today', 'none'].includes(req.body.history)
    ? req.body.history
    : 'none';

  const existing = new Set((source.members || []).map((m) => m.toString()));
  const uniqueNew = [
    ...new Set(
      rawIds
        .map((id) => id?.toString())
        .filter((id) => id && !existing.has(id))
    ),
  ];
  if (uniqueNew.length === 0) {
    return respond.badRequest(res, 'Select at least one new person to add');
  }

  const User = require('../users/user.model');
  const Message = require('../messages/message.model');
  // REQ 5: requests are open to all, but adding someone to a conversation
  // needs an existing relationship (or their opt-in) — see knownUsers.
  const { canAddToConversation } = require('../../utils/knownUsers');

  for (const targetId of uniqueNew) {
    const target = await User.findById(targetId).select('_id name');
    if (!target) return respond.notFound(res, 'One of the users was not found');
    const allowed = await canAddToConversation(req.user._id, targetId);
    if (!allowed) {
      return respond.forbidden(
        res,
        `${target.name || 'This doctor'} needs to accept a message request from you before joining a Needl`
      );
    }
  }

  const memberIds = [...existing, ...uniqueNew].sort();
  if (memberIds.length > 9) {
    return respond.badRequest(res, 'Needls support up to 9 people');
  }

  const { memberPairKey } = require('../../utils/memberPairKey');
  const mongoose = require('mongoose');
  const pairKey = memberPairKey(memberIds);
  let channel = await Channel.findOne({
    type: CHANNEL_TYPES.DIRECT,
    memberPairKey: pairKey,
    isArchived: false,
  });

  const usersForTitle = await User.find({
    _id: { $in: memberIds.filter((id) => id !== req.user._id.toString()) },
  })
    .select('name displayTitle')
    .lean();
  const needlTitle =
    usersForTitle
      .map(
        (u) =>
          [u.displayTitle, u.name].filter(Boolean).join(' ').trim() || u.name
      )
      .filter(Boolean)
      .slice(0, 4)
      .join(', ') || 'Needl';

  // History boundary for 'today': the caller's phone local midnight
  // (product Q2). Copied timestamps stay the original createdAt values.
  let since = null;
  if (history === 'today') {
    if (req.body.todayStart) {
      const parsed = new Date(req.body.todayStart);
      if (!Number.isNaN(parsed.getTime())) since = parsed;
    } else if (Number.isFinite(Number(req.body.timezoneOffsetMinutes))) {
      const offsetMin = Number(req.body.timezoneOffsetMinutes);
      const now = new Date();
      const local = new Date(now.getTime() - offsetMin * 60 * 1000);
      since = new Date(Date.UTC(
        local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate(), 0, 0, 0, 0
      ));
      since = new Date(since.getTime() + offsetMin * 60 * 1000);
    }
    if (!since) {
      since = new Date();
      since.setHours(0, 0, 0, 0);
    }
  }

  let createdChannel = false;
  let joinedRace = false;
  if (!channel) {
    try {
      channel = await Channel.create({
        spaceId: null,
        type: CHANNEL_TYPES.DIRECT,
        members: memberIds,
        memberPairKey: pairKey,
        createdBy: req.user._id,
        name: needlTitle,
        historyCopy: {
          sourceId: source._id,
          mode: history === 'none' ? undefined : history,
          since,
          // 'none' has nothing to copy; the activity line still needs posting.
          status: 'copying',
          startedAt: new Date(),
          addedBy: req.user._id,
          addedUserIds: uniqueNew,
        },
      });
      createdChannel = true;
    } catch (err) {
      // FR-NDL-28: a concurrent identical expansion created it first — the
      // unique pair key lets exactly one win; this request joins it.
      if (err?.code !== 11000) throw err;
      joinedRace = true;
      channel = await Channel.findOne({ type: CHANNEL_TYPES.DIRECT, memberPairKey: pairKey });
      if (!channel) throw err;
    }
  }

  // Claim the copy: the creator holds it; a later request may resume one
  // that failed (FR-NDL-29) or was abandoned by a crashed request.
  let ownsCopy = createdChannel;
  if (!ownsCopy && channel.historyCopy?.status && channel.historyCopy.status !== 'done') {
    const claimed = await Channel.findOneAndUpdate(
      {
        _id: channel._id,
        $or: [
          { 'historyCopy.status': 'failed' },
          { 'historyCopy.status': 'copying', 'historyCopy.startedAt': { $lt: new Date(Date.now() - 2 * 60 * 1000) } },
        ],
      },
      { $set: { 'historyCopy.status': 'copying', 'historyCopy.startedAt': new Date() } },
      { new: true }
    );
    if (claimed) {
      channel = claimed;
      ownsCopy = true;
    }
  }

  const sysMsg = require('../../utils/systemMessages');
  if (ownsCopy) {
    const plan = channel.historyCopy;
    try {
      if (plan.mode) {
        // A resumed copy first removes whatever a failed attempt left.
        await Message.deleteMany({ channelId: channel._id, copiedFromId: { $exists: true } });
        await copyNeedlHistory({ Message, mongoose, sourceId: plan.sourceId, channel, since: plan.mode === 'today' ? plan.since : null });
      }
      const addedUsers = await User.find({ _id: { $in: plan.addedUserIds } }).select('name displayTitle').lean();
      const actor = String(plan.addedBy) === String(req.user._id)
        ? req.user
        : await User.findById(plan.addedBy).select('name displayTitle').lean();
      // Activity line in the new conversation people were added to (REQ 2).
      await sysMsg.postSystemMessage({
        channel,
        actor: actor || req.user,
        event: sysMsg.SYSTEM_EVENTS.MEMBER_ADDED,
        text: `${sysMsg.personName(actor || req.user)} added ${sysMsg.joinNames(addedUsers.map(sysMsg.personName))}`
          + (!plan.mode ? '' : plan.mode === 'all' ? ' · earlier messages shared' : " · today's messages shared"),
        targetUserIds: plan.addedUserIds,
        notifyUserIds: memberIds,
      });
      await Channel.updateOne({ _id: channel._id }, { $set: { 'historyCopy.status': 'done' } });
    } catch (err) {
      await Channel.updateOne({ _id: channel._id }, { $set: { 'historyCopy.status': 'failed' } }).catch(() => {});
      throw err;
    }
  } else if (!createdChannel && channel.historyCopy?.status !== 'copying') {
    const current = (channel.name || '').trim();
    const otherLabels = usersForTitle
      .map(
        (u) =>
          [u.displayTitle, u.name].filter(Boolean).join(' ').trim() || u.name
      )
      .filter(Boolean);
    if (!current || otherLabels.some((n) => current === n)) {
      channel.name = needlTitle;
      await channel.save();
    }
  }

  const newUsers = [];
  // Members still looking at the OLD conversation must learn about it live
  // (beta 11-14, issue 8): a line there that opens the new Needl.
  // A request that lost the creation race adds no second line.
  if (!joinedRace && channel._id.toString() !== source._id.toString()) {
    const addedUsers = newUsers.length
      ? newUsers
      : await User.find({ _id: { $in: uniqueNew } }).select('name displayTitle').lean();
    await sysMsg.postSystemMessage({
      channel: source,
      actor: req.user,
      event: sysMsg.SYSTEM_EVENTS.NEEDL_CONTINUED,
      text: `${sysMsg.personName(req.user)} added ${sysMsg.joinNames(addedUsers.map(sysMsg.personName))} · chat continues in the new Needl`,
      targetUserIds: uniqueNew,
      notifyUserIds: (source.members || []).map((m) => m.toString()),
      movedToChannelId: channel._id,
    });
  }

  const populated = await Channel.findById(channel._id)
    .populate(
      'members',
      'name displayTitle role speciality avatarUrl availability lastSeenAt'
    )
    .lean();

  return respond.ok(res, 'Needl updated', {
    channel: enrichDM(populated, req.user._id),
    createdNew: channel._id.toString() !== source._id.toString(),
  });
});

/**
 * GET /api/channels/:id/members
 * List members of a private channel or DM
 */
const getChannelMembers = asyncHandler(async (req, res) => {
  const { resolveChannelAccessById } = require('../../utils/channelAccess');
  const access = await resolveChannelAccessById(req.params.id, req.user._id, res);
  if (!access) return;

  const channel = access.channel;
  const User = require('../users/user.model');
  const users = await User.find({ _id: { $in: channel.members } })
    // vocleUsername tells same-name doctors apart in @mention suggestions.
    .select('name displayTitle role speciality avatarUrl availability vocleUsername')
    .lean();

  return respond.ok(res, 'Members fetched', { members: users });
});

/**
 * Load pinned messages with populated message + sender for clients.
 */
const loadPinnedMessages = async (channelId) => {
  const doc = await Channel.findById(channelId)
    .select('pinnedMessages')
    .populate({
      path: 'pinnedMessages.messageId',
      populate: { path: 'senderId', select: 'name displayTitle role avatarUrl' },
    })
    .lean();
  return doc?.pinnedMessages || [];
};

/**
 * POST /api/channels/:id/pin/:messageId
 * Pin a message (max 5). Space members or either DM participant may pin.
 */
const pinMessage = asyncHandler(async (req, res) => {
  const { id: channelId, messageId } = req.params;
  const { resolveChannelAccessById } = require('../../utils/channelAccess');
  const access = await resolveChannelAccessById(channelId, req.user._id, res);
  if (!access) return;

  const channel = access.channel;
  const Message = require('../messages/message.model');

  const msg = await Message.findOne({ _id: messageId, channelId: channel._id });
  if (!msg || msg.isDeleted) {
    return respond.notFound(res, 'Message not found in this chat');
  }

  if (channel.pinnedMessages.length >= 5) {
    return respond.badRequest(res, 'Maximum 5 pinned messages per channel');
  }

  const alreadyPinned = channel.pinnedMessages.some(
    (p) => p.messageId.toString() === messageId
  );
  if (alreadyPinned) return respond.conflict(res, 'Message already pinned');

  channel.pinnedMessages.push({ messageId, pinnedBy: req.user._id });
  await channel.save();

  const pinnedMessages = await loadPinnedMessages(channelId);
  return respond.ok(res, 'Message pinned', { pinnedMessages });
});

/**
 * DELETE /api/channels/:id/pin/:messageId
 * Unpin a message (same permission as pin)
 */
const unpinMessage = asyncHandler(async (req, res) => {
  const { id: channelId, messageId } = req.params;
  const { resolveChannelAccessById } = require('../../utils/channelAccess');
  const access = await resolveChannelAccessById(channelId, req.user._id, res);
  if (!access) return;

  const channel = access.channel;
  channel.pinnedMessages = channel.pinnedMessages.filter(
    (p) => p.messageId.toString() !== messageId
  );
  await channel.save();

  const pinnedMessages = await loadPinnedMessages(channelId);
  return respond.ok(res, 'Message unpinned', { pinnedMessages });
});

module.exports = {
  createChannel, getSpaceChannels, getChannelById,
  updateChannel, archiveChannel, getMyDMs, createOrGetDM, createGroupDM,
  expandDM, getChannelMembers, pinMessage, unpinMessage,
};
