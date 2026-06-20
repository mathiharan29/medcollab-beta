/**
 * SPACE CONTROLLER
 */

const Space = require('./space.model');
const Channel = require('../channels/channel.model');
const { joinUserToSpaceRoom } = require('../../socket');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { SPACE_ROLES, CHANNEL_TYPES } = require('../../constants');

/**
 * Seed the three default channels every new space gets.
 * Called immediately after space creation — never exposed as its own route.
 */
const seedDefaultChannels = async (spaceId, creatorId) => {
  const defaults = [
    {
      name: 'general',
      type: CHANNEL_TYPES.GENERAL,
      description: 'General department discussion',
      position: 0,
      onlyAdminsCanPost: false,
    },
    {
      name: 'emergency',
      type: CHANNEL_TYPES.EMERGENCY,
      description: '🚨 High-priority alerts only',
      position: 1,
      onlyAdminsCanPost: false,
    },
    {
      name: 'academics',
      type: CHANNEL_TYPES.ACADEMIC,
      description: 'Case discussions and journal club',
      position: 2,
      onlyAdminsCanPost: false,
    },
  ];

  await Channel.insertMany(
    defaults.map((ch) => ({ ...ch, spaceId, createdBy: creatorId }))
  );
};

/**
 * POST /api/spaces
 * Create a new space and seed default channels
 */
const createSpace = asyncHandler(async (req, res) => {
  const { name, type, description } = req.body;

  const inviteCode = await Space.generateInviteCode();

  const space = await Space.create({
    name: name.trim(),
    type,
    description: description?.trim() || '',
    inviteCode,
    createdBy: req.user._id,
    members: [{ userId: req.user._id, role: SPACE_ROLES.OWNER }],
  });

  // Seed default channels
  await seedDefaultChannels(space._id, req.user._id);

  // Join creator's socket to the space room for presence broadcasts
  joinUserToSpaceRoom(req.user._id, space._id);

  // Fetch channels to include in response
  const channels = await Channel.find({ spaceId: space._id }).sort({ position: 1 }).lean();

  return respond.created(res, 'Space created', { space, channels });
});

/**
 * GET /api/spaces
 * List all spaces the current user belongs to, with their channels
 */
const getMySpaces = asyncHandler(async (req, res) => {
  const spaces = await Space.find({
    'members.userId': req.user._id,
    isActive: true,
  })
    .populate('createdBy', 'name avatarUrl')
    .lean();

  // Attach channels to each space (one extra query, worth the UX)
  const spaceIds = spaces.map((s) => s._id);
  const allChannels = await Channel.find({
    spaceId: { $in: spaceIds },
    isArchived: false,
  })
    .sort({ position: 1 })
    .lean();

  // Group channels by spaceId
  const channelsBySpace = allChannels.reduce((acc, ch) => {
    const key = ch.spaceId.toString();
    if (!acc[key]) acc[key] = [];
    acc[key].push(ch);
    return acc;
  }, {});

  const result = spaces.map((s) => ({
    ...s,
    channels: channelsBySpace[s._id.toString()] || [],
    myRole: s.members.find((m) => m.userId.toString() === req.user._id.toString())?.role,
  }));

  return respond.ok(res, 'Spaces fetched', { spaces: result });
});

/**
 * GET /api/spaces/:id
 * Get a single space with its channels (must be a member)
 */
const getSpaceById = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id)
    .populate('createdBy', 'name avatarUrl')
    .lean();

  if (!space) return respond.notFound(res, 'Space not found');

  const isMember = space.members.some(
    (m) => m.userId.toString() === req.user._id.toString()
  );
  if (!isMember) return respond.forbidden(res, 'You are not a member of this space');

  const channels = await Channel.find({ spaceId: space._id, isArchived: false })
    .sort({ position: 1 })
    .lean();

  const myRole = space.members.find(
    (m) => m.userId.toString() === req.user._id.toString()
  )?.role;

  return respond.ok(res, 'Space fetched', { space: { ...space, channels, myRole } });
});

/**
 * POST /api/spaces/join
 * Join a space using a 6-character invite code
 */
const joinSpace = asyncHandler(async (req, res) => {
  const { inviteCode } = req.body;

  const space = await Space.findOne({
    inviteCode: inviteCode.toUpperCase(),
    isActive: true,
  });

  if (!space) return respond.notFound(res, 'Invalid invite code');

  // Already a member?
  if (space.isMember(req.user._id)) {
    return respond.conflict(res, 'You are already a member of this space');
  }

  // Handle approval-required spaces
  if (space.settings.requireApproval) {
    const alreadyPending = space.pendingRequests.some(
      (r) => r.userId.toString() === req.user._id.toString()
    );
    if (!alreadyPending) {
      space.pendingRequests.push({ userId: req.user._id });
      await space.save();
    }
    return respond.ok(res, 'Join request sent. Waiting for admin approval.');
  }

  // Direct join
  space.members.push({ userId: req.user._id, role: SPACE_ROLES.MEMBER });
  await space.save();

  const channels = await Channel.find({ spaceId: space._id, isArchived: false })
    .sort({ position: 1 })
    .lean();

  // Join member's socket to the space room for presence broadcasts
  joinUserToSpaceRoom(req.user._id, space._id);

  return respond.ok(res, `Joined "${space.name}"`, { space, channels });
});

/**
 * POST /api/spaces/:id/invite
 * Regenerate the invite code (admin only)
 */
const regenerateInviteCode = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  space.inviteCode = await Space.generateInviteCode();
  await space.save();

  return respond.ok(res, 'Invite code regenerated', { inviteCode: space.inviteCode });
});

/**
 * PUT /api/spaces/:id
 * Update space name, description, or settings (admin only)
 */
const updateSpace = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  const allowed = ['name', 'description', 'settings', 'avatarUrl'];
  allowed.forEach((f) => {
    if (req.body[f] !== undefined) space[f] = req.body[f];
  });

  await space.save();
  return respond.ok(res, 'Space updated', { space });
});

/**
 * GET /api/spaces/:id/members
 * List members with their current availability status
 */
const getMembers = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isMember(req.user._id)) return respond.forbidden(res, 'Not a member');

  const User = require('../users/user.model');
  const { isUserOnline } = require('../../socket/handlers/presence.handler');
  const memberIds = space.members.map((m) => m.userId);

  const users = await User.find({ _id: { $in: memberIds } })
    .select('name displayTitle role speciality avatarUrl availability lastSeenAt')
    .lean();

  // Merge space role into user objects
  const roleMap = space.members.reduce((acc, m) => {
    acc[m.userId.toString()] = m.role;
    return acc;
  }, {});

  const members = users.map((u) => ({
    ...u,
    spaceRole: roleMap[u._id.toString()],
    isOnline: isUserOnline(u._id),
  }));

  // Sort: on_call → in_ot → available → others → off_duty
  const statusOrder = { on_call: 0, in_ot: 1, on_rounds: 1, in_icu: 1, available: 2, do_not_disturb: 3, off_duty: 4 };
  members.sort((a, b) =>
    (statusOrder[a.availability?.status] ?? 3) -
    (statusOrder[b.availability?.status] ?? 3)
  );

  return respond.ok(res, 'Members fetched', { members });
});

/**
 * DELETE /api/spaces/:id/members/:userId
 * Remove a member (admin only)
 */
const removeMember = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  const targetId = req.params.userId;
  const target = space.members.find((m) => m.userId.toString() === targetId);
  if (!target) return respond.notFound(res, 'Member not found');
  if (target.role === SPACE_ROLES.OWNER) return respond.forbidden(res, 'Cannot remove the owner');

  space.members = space.members.filter((m) => m.userId.toString() !== targetId);
  await space.save();

  return respond.ok(res, 'Member removed');
});

/**
 * POST /api/spaces/:id/leave
 * Current user leaves the space
 */
const leaveSpace = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isMember(req.user._id)) return respond.badRequest(res, 'Not a member');

  const myRole = space.getMemberRole(req.user._id);
  if (myRole === SPACE_ROLES.OWNER) {
    return respond.badRequest(res, 'Transfer ownership before leaving');
  }

  space.members = space.members.filter(
    (m) => m.userId.toString() !== req.user._id.toString()
  );
  await space.save();

  return respond.ok(res, `Left "${space.name}"`);
});

module.exports = {
  createSpace, getMySpaces, getSpaceById,
  joinSpace, regenerateInviteCode, updateSpace,
  getMembers, removeMember, leaveSpace,
};
