const Channel = require('../features/channels/channel.model');
const Space = require('../features/spaces/space.model');
const { respond } = require('./apiResponse');
const { CHANNEL_TYPES } = require('../constants');

const memberIdEquals = (member, userId) => {
  const id = member?._id || member?.userId || member;
  return id?.toString() === userId.toString();
};

/**
 * Core authorization for a loaded channel document (+ optional space).
 * Policy: inactive space = revoked; private = member or space admin;
 * DM/Needl = members list; archived denied unless allowArchived.
 */
const evaluateChannelAccess = (channel, space, userId, { allowArchived = false } = {}) => {
  if (!channel) return { ok: false, status: 404, message: 'Channel not found' };

  if (channel.isArchived && !allowArchived) {
    return { ok: false, status: 403, message: 'Channel is archived' };
  }

  if (channel.type === CHANNEL_TYPES.DIRECT || !channel.spaceId) {
    const isMember = (channel.members || []).some((m) => memberIdEquals(m, userId));
    if (!isMember) {
      return { ok: false, status: 403, message: 'Not a channel member' };
    }
    return { ok: true, channel, space: null };
  }

  if (!space) {
    return { ok: false, status: 404, message: 'Space not found' };
  }

  if (space.isActive === false) {
    return { ok: false, status: 403, message: 'This group is no longer active' };
  }

  if (!space.isMember(userId)) {
    return { ok: false, status: 403, message: 'Not a space member' };
  }

  if (channel.isPrivate) {
    const isChannelMember = (channel.members || []).some((m) =>
      memberIdEquals(m, userId)
    );
    if (!isChannelMember && !space.isAdmin(userId)) {
      return { ok: false, status: 403, message: 'Not a channel member' };
    }
  }

  return { ok: true, channel, space };
};

const sendAccessFailure = (res, result) => {
  if (result.status === 404) return respond.notFound(res, result.message);
  return respond.forbidden(res, result.message);
};

/**
 * Verify channel access for REST handlers using req.params.channelId.
 * Returns { channel, space } or sends an error response and returns null.
 */
const resolveChannelAccess = async (req, res, options = {}) => {
  const channelId = req.params.channelId || req.params.id;
  return resolveChannelAccessById(channelId, req.user._id, res, options);
};

/**
 * Same checks as resolveChannelAccess, keyed by explicit channel id.
 */
const resolveChannelAccessById = async (channelId, userId, res, options = {}) => {
  const channel = await Channel.findById(channelId);
  if (!channel) {
    respond.notFound(res, 'Channel not found');
    return null;
  }

  let space = null;
  if (channel.spaceId) {
    space = await Space.findById(channel.spaceId);
  }

  const result = evaluateChannelAccess(channel, space, userId, options);
  if (!result.ok) {
    sendAccessFailure(res, result);
    return null;
  }
  return { channel: result.channel, space: result.space };
};

/**
 * Socket join guard — same rules as REST channel access.
 */
const canAccessChannel = async (userId, channelId) => {
  const channel = await Channel.findById(channelId).lean();
  if (!channel) return false;

  let space = null;
  if (channel.spaceId) {
    space = await Space.findById(channel.spaceId);
  }

  const result = evaluateChannelAccess(channel, space, userId);
  return result.ok;
};

const assertMessageInChannel = (message, channelId, res) => {
  if (!message || message.channelId.toString() !== channelId.toString()) {
    respond.forbidden(res, 'Message does not belong to this channel');
    return false;
  }
  return true;
};

/**
 * Authorized personal-room / notification audience for a message (VR-S8).
 * Private channels: channel members + space admins only (not entire space).
 */
const resolveMessageAudienceIds = (channel, space) => {
  if (!channel) return [];

  if (channel.type === CHANNEL_TYPES.DIRECT || !channel.spaceId) {
    return (channel.members || [])
      .map((m) => (m?._id || m)?.toString())
      .filter(Boolean);
  }

  if (channel.isPrivate) {
    const ids = new Set(
      (channel.members || [])
        .map((m) => (m?._id || m)?.toString())
        .filter(Boolean)
    );
    for (const m of space?.members || []) {
      const uid = m.userId?.toString?.() || m.userId?.toString();
      if (uid && space.isAdmin(uid)) ids.add(uid);
    }
    return [...ids];
  }

  return (space?.members || [])
    .map((m) => m.userId?.toString?.() || m.userId?.toString())
    .filter(Boolean);
};

module.exports = {
  evaluateChannelAccess,
  resolveChannelAccess,
  resolveChannelAccessById,
  canAccessChannel,
  assertMessageInChannel,
  resolveMessageAudienceIds,
};
