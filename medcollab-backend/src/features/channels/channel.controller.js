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
  const channel = await Channel.findById(req.params.id)
    .populate('pinnedMessages.messageId')
    .lean();

  if (!channel) return respond.notFound(res, 'Channel not found');

  // Access check
  if (channel.spaceId) {
    const space = await Space.findById(channel.spaceId);
    if (!space?.isMember(req.user._id)) return respond.forbidden(res, 'Not a space member');
  } else {
    // DM channel — must be a member
    const isMember = channel.members.some(
      (id) => id.toString() === req.user._id.toString()
    );
    if (!isMember) return respond.forbidden(res, 'Not a channel member');
  }

  return respond.ok(res, 'Channel fetched', { channel });
});

/**
 * PUT /api/channels/:id
 * Update channel name or description (admin only)
 */
const updateChannel = asyncHandler(async (req, res) => {
  const channel = await Channel.findById(req.params.id);
  if (!channel) return respond.notFound(res, 'Channel not found');

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
 * POST /api/channels/dm
 * Create or retrieve a 1:1 DM channel between two users
 * Idempotent — always returns the same channel for the same pair
 */
const createOrGetDM = asyncHandler(async (req, res) => {
  const { userId: targetUserId } = req.body;

  if (targetUserId === req.user._id.toString()) {
    return respond.badRequest(res, 'Cannot create a DM with yourself');
  }

  // Check if DM already exists
  let channel = await Channel.findDMChannel(req.user._id, targetUserId);

  if (!channel) {
    channel = await Channel.create({
      spaceId: null,
      type: CHANNEL_TYPES.DIRECT,
      members: [req.user._id, targetUserId],
      createdBy: req.user._id,
      name: null,
    });
  }

  return respond.ok(res, 'DM channel ready', { channel });
});

/**
 * GET /api/channels/:id/members
 * List members of a private channel or DM
 */
const getChannelMembers = asyncHandler(async (req, res) => {
  const channel = await Channel.findById(req.params.id).lean();
  if (!channel) return respond.notFound(res, 'Channel not found');

  const User = require('../users/user.model');
  const users = await User.find({ _id: { $in: channel.members } })
    .select('name displayTitle role speciality avatarUrl availability')
    .lean();

  return respond.ok(res, 'Members fetched', { members: users });
});

/**
 * POST /api/channels/:id/pin/:messageId
 * Pin a message (max 5 per channel, admin only)
 */
const pinMessage = asyncHandler(async (req, res) => {
  const { id: channelId, messageId } = req.params;

  const channel = await Channel.findById(channelId);
  if (!channel) return respond.notFound(res, 'Channel not found');

  const space = await Space.findById(channel.spaceId);
  if (!space?.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  if (channel.pinnedMessages.length >= 5) {
    return respond.badRequest(res, 'Maximum 5 pinned messages per channel');
  }

  const alreadyPinned = channel.pinnedMessages.some(
    (p) => p.messageId.toString() === messageId
  );
  if (alreadyPinned) return respond.conflict(res, 'Message already pinned');

  channel.pinnedMessages.push({ messageId, pinnedBy: req.user._id });
  await channel.save();

  return respond.ok(res, 'Message pinned');
});

/**
 * DELETE /api/channels/:id/pin/:messageId
 * Unpin a message (admin only)
 */
const unpinMessage = asyncHandler(async (req, res) => {
  const { id: channelId, messageId } = req.params;

  const channel = await Channel.findById(channelId);
  if (!channel) return respond.notFound(res, 'Channel not found');

  const space = await Space.findById(channel.spaceId);
  if (!space?.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  channel.pinnedMessages = channel.pinnedMessages.filter(
    (p) => p.messageId.toString() !== messageId
  );
  await channel.save();

  return respond.ok(res, 'Message unpinned');
});

module.exports = {
  createChannel, getSpaceChannels, getChannelById,
  updateChannel, archiveChannel, createOrGetDM,
  getChannelMembers, pinMessage, unpinMessage,
};
