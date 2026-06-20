const Channel = require('../features/channels/channel.model');
const Space = require('../features/spaces/space.model');
const { respond } = require('./apiResponse');
const { CHANNEL_TYPES } = require('../constants');

/**
 * Verify channel access for REST handlers.
 * Returns { channel, space } or sends an error response and returns null.
 */
const resolveChannelAccess = async (req, res) => {
  const channel = await Channel.findById(req.params.channelId);
  if (!channel) {
    respond.notFound(res, 'Channel not found');
    return null;
  }

  if (channel.isArchived) {
    respond.forbidden(res, 'Channel is archived');
    return null;
  }

  if (channel.type === CHANNEL_TYPES.DIRECT) {
    const isMember = channel.members.some(
      (id) => id.toString() === req.user._id.toString(),
    );
    if (!isMember) {
      respond.forbidden(res, 'Not a channel member');
      return null;
    }
    return { channel, space: null };
  }

  const space = await Space.findById(channel.spaceId);
  if (!space?.isMember(req.user._id)) {
    respond.forbidden(res, 'Not a space member');
    return null;
  }

  if (channel.isPrivate) {
    const isChannelMember = channel.members.some(
      (id) => id.toString() === req.user._id.toString(),
    );
    if (!isChannelMember && !space.isAdmin(req.user._id)) {
      respond.forbidden(res, 'Not a channel member');
      return null;
    }
  }

  return { channel, space };
};

/**
 * Socket join guard — same rules as REST channel access.
 */
const canAccessChannel = async (userId, channelId) => {
  const channel = await Channel.findById(channelId).lean();
  if (!channel || channel.isArchived) return false;

  if (channel.type === CHANNEL_TYPES.DIRECT) {
    return channel.members.some((id) => id.toString() === userId.toString());
  }

  const space = await Space.findById(channel.spaceId);
  if (!space?.isMember(userId)) return false;

  if (channel.isPrivate) {
    const isChannelMember = channel.members.some(
      (id) => id.toString() === userId.toString(),
    );
    return isChannelMember || space.isAdmin(userId);
  }

  return true;
};

const assertMessageInChannel = (message, channelId, res) => {
  if (!message || message.channelId.toString() !== channelId) {
    respond.forbidden(res, 'Message does not belong to this channel');
    return false;
  }
  return true;
};

module.exports = {
  resolveChannelAccess,
  canAccessChannel,
  assertMessageInChannel,
};
