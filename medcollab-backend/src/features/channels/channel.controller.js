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

  return respond.ok(res, 'Channels fetched', { channels });
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

  if (isDirect) {
    if (!isMember) return respond.forbidden(res, 'Not a conversation member');
    if (req.body.name !== undefined) {
      const name = String(req.body.name).trim().slice(0, 80);
      channel.name = name || null;
    }
    await channel.save();
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
  if (req.body.name && !['general', 'emergency', 'academics'].includes(channel.name)) {
    channel.name = req.body.name.toLowerCase();
  }

  await channel.save();
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

  const enriched = channels.map((ch) => enrichDM(ch, req.user._id));
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

  // Atomic upsert to prevent TOCTOU race when two users create the same DM simultaneously.
  const sortedMembers = [req.user._id.toString(), targetUserId].sort();
  let channel = await Channel.findOneAndUpdate(
    {
      type: CHANNEL_TYPES.DIRECT,
      'members': { $all: sortedMembers, $size: 2 },
    },
    {
      $setOnInsert: {
        spaceId: null,
        type: CHANNEL_TYPES.DIRECT,
        members: [req.user._id, targetUserId],
        createdBy: req.user._id,
        name: null,
      },
    },
    { upsert: true, new: true }
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
  const { canMessageUser, canRequestMessage } = require('../../utils/knownUsers');

  for (const targetId of uniqueOthers) {
    const target = await User.findById(targetId).select('_id name');
    if (!target) return respond.notFound(res, 'One of the users was not found');
    const allowed =
      (await canMessageUser(req.user._id, targetId)) ||
      (await canRequestMessage(req.user._id, targetId));
    if (!allowed) {
      return respond.forbidden(
        res,
        `Cannot add ${target.name || 'user'} — send a message request first or share a group`
      );
    }
  }

  const memberIds = [req.user._id.toString(), ...uniqueOthers].sort();
  const objectIds = memberIds.map((id) => id);

  let channel = await Channel.findOne({
    type: CHANNEL_TYPES.DIRECT,
    members: { $all: objectIds, $size: memberIds.length },
    isArchived: false,
  });

  if (!channel) {
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

    channel = await Channel.create({
      spaceId: null,
      type: CHANNEL_TYPES.DIRECT,
      members: objectIds,
      createdBy: req.user._id,
      name: defaultName,
    });
  } else {
    const current = (channel.name || '').trim();
    if (!current || current.toLowerCase() === 'direct message') {
      const users = await User.find({ _id: { $in: uniqueOthers } })
        .select('name displayTitle')
        .lean();
      channel.name =
        users
          .map(
            (u) =>
              [u.displayTitle, u.name].filter(Boolean).join(' ').trim() ||
              u.name
          )
          .filter(Boolean)
          .slice(0, 4)
          .join(', ') || 'Needl';
      await channel.save();
    }
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
  const { canMessageUser, canRequestMessage } = require('../../utils/knownUsers');

  for (const targetId of uniqueNew) {
    const target = await User.findById(targetId).select('_id name');
    if (!target) return respond.notFound(res, 'One of the users was not found');
    const allowed =
      (await canMessageUser(req.user._id, targetId)) ||
      (await canRequestMessage(req.user._id, targetId));
    if (!allowed) {
      return respond.forbidden(
        res,
        `Cannot add ${target.name || 'user'} — send a message request first or share a group`
      );
    }
  }

  const memberIds = [...existing, ...uniqueNew].sort();
  if (memberIds.length > 9) {
    return respond.badRequest(res, 'Needls support up to 9 people');
  }

  let channel = await Channel.findOne({
    type: CHANNEL_TYPES.DIRECT,
    members: { $all: memberIds, $size: memberIds.length },
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

  if (!channel) {
    channel = await Channel.create({
      spaceId: null,
      type: CHANNEL_TYPES.DIRECT,
      members: memberIds,
      createdBy: req.user._id,
      name: needlTitle,
    });

    if (history !== 'none') {
      const filter = {
        channelId: source._id,
        isDeleted: { $ne: true },
      };
      if (history === 'today') {
        const start = new Date();
        start.setHours(0, 0, 0, 0);
        filter.createdAt = { $gte: start };
      }
      const messages = await Message.find(filter)
        .sort({ createdAt: 1 })
        .limit(500)
        .lean();

      if (messages.length > 0) {
        const copies = messages.map((m) => ({
          channelId: channel._id,
          spaceId: null,
          senderId: m.senderId,
          type: m.type,
          content: m.content,
          priority: m.priority,
          mentions: m.mentions || [],
          replyTo: m.replyTo || undefined,
          createdAt: m.createdAt,
          updatedAt: m.updatedAt,
        }));
        await Message.insertMany(copies);
        const last = messages[messages.length - 1];
        await Channel.findByIdAndUpdate(channel._id, {
          lastMessage: {
            messageId: last._id,
            text: last.content?.text?.slice(0, 200) || null,
            senderName: null,
            type: last.type,
            sentAt: last.createdAt,
          },
        });
      }
    }
  } else {
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
    .select('name displayTitle role speciality avatarUrl availability')
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
