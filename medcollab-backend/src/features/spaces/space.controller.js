/**
 * SPACE CONTROLLER
 */

const Space = require('./space.model');
const Channel = require('../channels/channel.model');
const User = require('../users/user.model');
const { accessibleChannelFilter } = require('../../utils/accessibleChannels');
const { joinUserToSpaceRoom, leaveUserFromSpaceRoom } = require('../../socket');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { SPACE_ROLES, CHANNEL_TYPES } = require('../../constants');
const {
  SYSTEM_EVENTS,
  personName,
  joinNames,
  postSpaceSystemMessage,
} = require('../../utils/systemMessages');

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

  await postSpaceSystemMessage(space, {
    actor: req.user,
    event: SYSTEM_EVENTS.GROUP_CREATED,
    text: `${personName(req.user)} created the group "${space.name}"`,
  });

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
    ...accessibleChannelFilter(req.user._id),
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

  const channels = await Channel.find(
    accessibleChannelFilter(req.user._id, { spaceId: space._id }),
  )
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
    return respond.ok(res, 'Join request sent. Waiting for admin approval.', {
      pending: true,
      spaceId: space._id,
    });
  }

  // Direct join
  space.members.push({ userId: req.user._id, role: SPACE_ROLES.MEMBER });
  await space.save();

  // First invite join — attribute acquisition channel for ops analytics
  if (!req.user.joinedVia || req.user.joinedVia === 'direct') {
    User.findByIdAndUpdate(req.user._id, { joinedVia: 'invite_code' }).exec();
  }

  const channels = await Channel.find(
    accessibleChannelFilter(req.user._id, { spaceId: space._id }),
  )
    .sort({ position: 1 })
    .lean();

  // Join member's socket to the space room for presence broadcasts
  joinUserToSpaceRoom(req.user._id, space._id);

  // Tell existing members to refresh members / lists without pull-to-refresh.
  try {
    const { getIO } = require('../../socket');
    const { SOCKET_EVENTS } = require('../../constants');
    getIO().to(`space:${space._id}`).emit(SOCKET_EVENTS.SPACE_MEMBER_JOINED, {
      spaceId: space._id.toString(),
      userId: req.user._id.toString(),
      userName: req.user.name || '',
      memberCount: space.members.length,
    });
  } catch (_) {
    /* non-fatal */
  }

  await postSpaceSystemMessage(space, {
    actor: req.user,
    event: SYSTEM_EVENTS.MEMBER_JOINED,
    text: `${personName(req.user)} joined using the invite code`,
    targetUserIds: [req.user._id],
  });

  return respond.ok(res, `Joined "${space.name}"`, { space, channels });
});

/**
 * POST /api/spaces/:id/pending/:userId/approve
 * Approve a pending join request (admin/owner only)
 */
const approveJoinRequest = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  const targetId = req.params.userId;
  const pending = space.pendingRequests.find(
    (request) => request.userId.toString() === targetId
  );
  if (!pending) return respond.notFound(res, 'Pending join request not found');

  if (!space.isMember(targetId)) {
    space.members.push({ userId: targetId, role: SPACE_ROLES.MEMBER });
  }
  space.pendingRequests = space.pendingRequests.filter(
    (request) => request.userId.toString() !== targetId
  );
  await space.save();

  const channels = await Channel.find(
    accessibleChannelFilter(targetId, { spaceId: space._id }),
  )
    .sort({ position: 1 })
    .lean();

  joinUserToSpaceRoom(targetId, space._id);

  const approvedUser = await User.findById(targetId)
    .select('name displayTitle')
    .lean();
  try {
    const { getIO } = require('../../socket');
    const { SOCKET_EVENTS } = require('../../constants');
    getIO().to(`space:${space._id}`).emit(SOCKET_EVENTS.SPACE_MEMBER_JOINED, {
      spaceId: space._id.toString(),
      userId: targetId,
      userName: approvedUser?.name || '',
      memberCount: space.members.length,
    });
  } catch (_) {
    /* non-fatal */
  }

  await postSpaceSystemMessage(space, {
    actor: req.user,
    event: SYSTEM_EVENTS.MEMBER_JOINED,
    text: `${personName(approvedUser)} joined (approved by ${personName(req.user)})`,
    targetUserIds: [targetId],
  });

  return respond.ok(res, `Approved join request for "${space.name}"`, {
    space,
    channels,
  });
});

/**
 * GET /api/spaces/invite/:code
 * Preview a space invite before joining (name, type, member count)
 */
const previewInvite = asyncHandler(async (req, res) => {
  const code = (req.params.code || '').toUpperCase();
  const space = await Space.findOne({
    inviteCode: code,
    isActive: true,
  }).lean();

  if (!space) return respond.notFound(res, 'Invalid invite code');

  const alreadyMember = (space.members || []).some(
    (m) => m.userId.toString() === req.user._id.toString()
  );

  return respond.ok(res, 'Invite preview', {
    invite: {
      inviteCode: space.inviteCode,
      name: space.name,
      type: space.type,
      description: space.description || '',
      memberCount: (space.members || []).length,
      alreadyMember,
      joinUrl: `https://medcollab.up.railway.app/join/${space.inviteCode}`,
    },
  });
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

  return respond.ok(res, 'Invite code regenerated', {
    inviteCode: space.inviteCode,
    joinUrl: `https://medcollab.up.railway.app/join/${space.inviteCode}`,
  });
});

/**
 * PUT /api/spaces/:id
 * Update space name, description, or settings (admin only)
 */
const updateSpace = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  const previousName = space.name;
  const allowed = ['name', 'description', 'settings', 'avatarUrl'];
  allowed.forEach((f) => {
    if (req.body[f] !== undefined) space[f] = req.body[f];
  });

  await space.save();

  if (space.name !== previousName) {
    await postSpaceSystemMessage(space, {
      actor: req.user,
      event: SYSTEM_EVENTS.GROUP_RENAMED,
      text: `${personName(req.user)} changed the group name to "${space.name}"`,
    });
  }
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
  await leaveUserFromSpaceRoom(targetId, space._id);
  emitSpaceMemberLeft(space._id, targetId, {
    reason: 'removed',
    byUserId: req.user._id,
    byUserName: req.user.name || '',
  });

  const removedUser = await User.findById(targetId)
    .select('name displayTitle')
    .lean();
  await postSpaceSystemMessage(space, {
    actor: req.user,
    event: SYSTEM_EVENTS.MEMBER_REMOVED,
    text: `${personName(req.user)} removed ${personName(removedUser)}`,
    targetUserIds: [targetId],
    // The removed doctor still sees why the chat went read-only.
    notifyUserIds: [targetId],
  });

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
  await leaveUserFromSpaceRoom(req.user._id, space._id);
  emitSpaceMemberLeft(space._id, req.user._id, { reason: 'left' });

  await postSpaceSystemMessage(space, {
    actor: req.user,
    event: SYSTEM_EVENTS.MEMBER_LEFT,
    text: `${personName(req.user)} left`,
    targetUserIds: [req.user._id],
  });

  return respond.ok(res, `Left "${space.name}"`);
});

/**
 * Can `actorId` put `targetId` straight into a group? (REQ 2 / REQ 5)
 * People who already know the doctor (shared group, or an existing chat /
 * accepted request) can; strangers only if the doctor allows group adds from
 * anyone. Everyone else must use the invite link — they choose to join.
 */
async function canAddToGroup(actorId, target) {
  const { canAddToConversation } = require('../../utils/knownUsers');
  return canAddToConversation(actorId, target._id);
}

/**
 * POST /api/spaces/:id/members  { userIds: string[] }
 * Admins add doctors directly (WhatsApp "Add participants", REQ 2).
 * New members see the group's full history (channel reads are not limited
 * by join date) and an "X added Y" line is posted to #general.
 */
const addMembers = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id);
  if (!space || !space.isActive) return respond.notFound(res, 'Space not found');
  if (!space.isAdmin(req.user._id)) {
    return respond.forbidden(res, 'Only group admins can add members');
  }

  const rawIds = Array.isArray(req.body.userIds) ? req.body.userIds : [];
  const ids = [...new Set(rawIds.map((id) => id?.toString()).filter(Boolean))];
  if (ids.length === 0) return respond.badRequest(res, 'Select at least one doctor');
  if (ids.length > 50) return respond.badRequest(res, 'Add up to 50 doctors at a time');
  if (!ids.every((id) => /^[a-f\d]{24}$/i.test(id))) {
    return respond.badRequest(res, 'Invalid user id');
  }

  const users = await User.find({
    _id: { $in: ids },
    isActive: true,
    isOnboarded: true,
  }).select('name displayTitle notifications');
  const byId = new Map(users.map((u) => [u._id.toString(), u]));

  const added = [];
  const skipped = [];
  for (const id of ids) {
    const user = byId.get(id);
    if (!user) {
      skipped.push({ userId: id, reason: 'not_found' });
    } else if (space.isMember(id)) {
      skipped.push({ userId: id, reason: 'already_member', name: personName(user) });
    } else if (!(await canAddToGroup(req.user._id, user))) {
      skipped.push({ userId: id, reason: 'privacy', name: personName(user) });
    } else {
      added.push(user);
    }
  }

  if (added.length > 0) {
    for (const user of added) {
      space.members.push({ userId: user._id, role: SPACE_ROLES.MEMBER });
    }
    // A direct add also settles any pending join request from them.
    const addedIds = new Set(added.map((u) => u._id.toString()));
    space.pendingRequests = space.pendingRequests.filter(
      (r) => !addedIds.has(r.userId.toString())
    );
    await space.save();

    const { getIO } = require('../../socket');
    const { SOCKET_EVENTS, NOTIFICATION_TYPES } = require('../../constants');
    for (const user of added) {
      joinUserToSpaceRoom(user._id, space._id);
      try {
        getIO().to(`space:${space._id}`).emit(SOCKET_EVENTS.SPACE_MEMBER_JOINED, {
          spaceId: space._id.toString(),
          userId: user._id.toString(),
          userName: user.name || '',
          memberCount: space.members.length,
          addedBy: req.user._id.toString(),
        });
      } catch (_) {
        /* non-fatal */
      }
    }

    await postSpaceSystemMessage(space, {
      actor: req.user,
      event: SYSTEM_EVENTS.MEMBER_ADDED,
      text: `${personName(req.user)} added ${joinNames(added.map(personName))}`,
      targetUserIds: added.map((u) => u._id),
    });

    setImmediate(async () => {
      try {
        const { sendNotification } = require('../../services/notification.service');
        for (const user of added) {
          await sendNotification({
            userId: user._id,
            type: NOTIFICATION_TYPES.SPACE_INVITE,
            title: `Added to ${space.name}`,
            body: `${personName(req.user)} added you to "${space.name}"`,
            referenceId: space._id,
            referenceType: 'Space',
            metadata: { spaceId: space._id.toString() },
            actor: req.user,
          });
        }
      } catch (err) {
        const logger = require('../../utils/logger');
        logger.error(`Add-member notify failed: ${err.message}`);
      }
    });
  }

  const status = added.length > 0 ? 200 : 400;
  const message = added.length > 0
    ? `Added ${added.length} ${added.length === 1 ? 'doctor' : 'doctors'}`
    : skipped.some((s) => s.reason === 'privacy')
      ? 'They only accept group adds from people they know — share the invite link instead'
      : 'No one new to add';
  return res.status(status).json({
    success: added.length > 0,
    message,
    data: {
      added: added.map((u) => ({ _id: u._id, name: u.name, displayTitle: u.displayTitle })),
      skipped,
      memberCount: space.members.length,
    },
    errors: [],
  });
});

/**
 * Notify the affected user (and space room) that membership ended.
 * Clients keep history readable and disable the composer (Q10).
 */
const emitSpaceMemberLeft = (spaceId, userId, { reason, byUserId, byUserName } = {}) => {
  try {
    const { getIO } = require('../../socket');
    const { SOCKET_EVENTS } = require('../../constants');
    const payload = {
      spaceId: spaceId.toString(),
      userId: userId.toString(),
      reason: reason || 'left',
      byUserId: byUserId ? byUserId.toString() : null,
      byUserName: byUserName || null,
    };
    const io = getIO();
    io.to(`user:${userId}`).emit(SOCKET_EVENTS.SPACE_MEMBER_LEFT, payload);
    io.to(`space:${spaceId}`).emit(SOCKET_EVENTS.SPACE_MEMBER_LEFT, payload);
  } catch (_) {
    /* non-fatal */
  }
};

/**
 * GET /api/spaces/:id/pending
 * List pending join requests (admin/owner only)
 */
const getPendingJoins = asyncHandler(async (req, res) => {
  const space = await Space.findById(req.params.id);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isAdmin(req.user._id)) return respond.forbidden(res, 'Admins only');

  const ids = space.pendingRequests.map((request) => request.userId);
  const users = await User.find({ _id: { $in: ids } })
    .select('name displayTitle role speciality avatarUrl')
    .lean();
  const byId = new Map(users.map((user) => [user._id.toString(), user]));
  const pending = space.pendingRequests.map((request) => ({
    userId: request.userId,
    requestedAt: request.requestedAt,
    message: request.message || '',
    user: byId.get(request.userId.toString()) || null,
  }));

  return respond.ok(res, 'Pending joins fetched', { pending });
});

module.exports = {
  createSpace, getMySpaces, getSpaceById,
  joinSpace, approveJoinRequest, getPendingJoins, previewInvite, regenerateInviteCode, updateSpace,
  getMembers, removeMember, leaveSpace, addMembers,
};
