/**
 * USER CONTROLLER
 */

const User = require('./user.model');
const { respond } = require('../../utils/apiResponse');
const escapeRegex = require('../../utils/escapeRegex');
const asyncHandler = require('../../utils/asyncHandler');
const { emitNotification } = require('../../socket');
const { getIO } = require('../../socket');
const { isUserOnline } = require('../../socket/handlers/presence.handler');
const { SOCKET_EVENTS } = require('../../constants');
const logger = require('../../utils/logger');
const { normalizePhoneToE164 } = require('../../services/msg91Widget.service');
const { MESSAGE_REQUEST_STATUS } = require('../../constants');

/**
 * GET /api/users/me
 * Return the full authenticated user profile
 */
const getMe = asyncHandler(async (req, res) => {
  // req.user is already attached by protect middleware
  // Re-fetch to get the latest data (availability may have changed via socket)
  const user = await User.findById(req.user._id);
  return respond.ok(res, 'Profile fetched', { user: user.toPublicProfile() });
});

/**
 * PUT /api/users/me
 * Update profile fields. Sets isOnboarded=true once name+role are present.
 */
const updateMe = asyncHandler(async (req, res) => {
  const allowed = ['name', 'displayTitle', 'role', 'speciality', 'pgYear',
                   'institution', 'city', 'bio', 'notifications', 'avatarUrl'];

  const updates = {};
  allowed.forEach((field) => {
    if (req.body[field] !== undefined) updates[field] = req.body[field];
  });

  // Promote to onboarded once they have the minimum required fields
  const user = await User.findById(req.user._id);
  const nameAfter  = updates.name  ?? user.name;
  const roleAfter  = updates.role  ?? user.role;

  if (nameAfter && roleAfter && !user.isOnboarded) {
    updates.isOnboarded = true;
  }

  // Merge nested notifications so one toggle never wipes sibling prefs.
  if (updates.notifications && typeof updates.notifications === 'object') {
    const current = user.notifications?.toObject
      ? user.notifications.toObject()
      : { ...(user.notifications || {}) };
    updates.notifications = { ...current, ...updates.notifications };
  }

  const updated = await User.findByIdAndUpdate(
    req.user._id,
    { $set: updates },
    { new: true, runValidators: true }
  );

  return respond.ok(res, 'Profile updated', { user: updated.toPublicProfile() });
});

/**
 * PUT /api/users/me/availability
 * Update availability status and broadcast to all space rooms via socket
 */
const updateAvailability = asyncHandler(async (req, res) => {
  const { status, until, note } = req.body;

  const updated = await User.findByIdAndUpdate(
    req.user._id,
    {
      'availability.status': status,
      'availability.until': until || null,
      'availability.note': note || '',
      'availability.updatedAt': new Date(),
    },
    { new: true }
  );

  // Broadcast presence update to all spaces this user is in — other members
  // will see the status dot change in real time without refreshing
  try {
    const Space = require('../spaces/space.model');
    const spaces = await Space.find(
      { 'members.userId': req.user._id },
      { _id: 1 }
    ).lean();

    const io = getIO();
    spaces.forEach(({ _id }) => {
      io.to(`space:${_id}`).emit(SOCKET_EVENTS.PRESENCE_UPDATE, {
        userId: req.user._id.toString(),
        isOnline: isUserOnline(req.user._id),
        availability: {
          status: updated.availability.status,
          until: updated.availability.until || null,
          note: updated.availability.note || '',
        },
        updatedAt: new Date().toISOString(),
      });
    });
  } catch (err) {
    // Non-fatal — socket may not be up in test env
    logger.debug(`Availability broadcast skipped: ${err.message}`);
  }

  return respond.ok(res, 'Availability updated', {
    availability: updated.availability,
  });
});

/**
 * PUT /api/users/me/fcm-token
 * Register a device FCM token for push notifications
 */
const registerFcmToken = asyncHandler(async (req, res) => {
  const { token } = req.body;
  const user = await User.findById(req.user._id);
  await user.addFcmToken(token);   // Instance method handles dedup + cap
  return respond.ok(res, 'Device registered for notifications');
});

/**
 * GET /api/users/:id
 * Get another user's public profile
 */
const getUserById = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id);
  if (!user) return respond.notFound(res, 'User not found');
  return respond.ok(res, 'User fetched', { user: user.toPublicProfile() });
});

/**
 * GET /api/users/search?q=priya&spaceId=...
 * Search known users only (shared spaces ∪ DMs ∪ same institution).
 * Optional spaceId further narrows to that group's members ∩ known set.
 */
const searchUsers = asyncHandler(async (req, res) => {
  const { q, spaceId } = req.query;

  if (!q || q.trim().length < 2) {
    return respond.badRequest(res, 'Search query must be at least 2 characters');
  }

  const searchRegex = new RegExp(escapeRegex(q.trim()), 'i');
  const { resolveKnownUserIds } = require('../../utils/knownUsers');
  const Space = require('../spaces/space.model');

  let filteredIds = await resolveKnownUserIds(req.user._id);

  if (spaceId) {
    const space = await Space.findById(spaceId).select('members');
    if (!space) {
      return respond.ok(res, 'Search results', { users: [] });
    }
    const spaceMemberIds = new Set(
      (space.members || []).map((m) => m.userId.toString())
    );
    filteredIds = filteredIds.filter((id) => spaceMemberIds.has(id));
  }

  if (filteredIds.length === 0) {
    return respond.ok(res, 'Search results', { users: [] });
  }

  const digitQuery = q.trim().replace(/\D/g, '');
  const orClauses = [
    { name: searchRegex },
    { displayTitle: searchRegex },
    { speciality: searchRegex },
  ];
  // Allow finding known colleagues by partial/full mobile digits too.
  if (digitQuery.length >= 4) {
    orClauses.push({ phone: new RegExp(escapeRegex(digitQuery) + '$') });
    orClauses.push({ phone: new RegExp(escapeRegex(digitQuery)) });
  }

  const users = await User.find({
    _id: { $in: filteredIds },
    isActive: true,
    isOnboarded: true,
    $or: orClauses,
  })
    .select('name displayTitle role speciality institution avatarUrl availability')
    .limit(20)
    .lean();

  return respond.ok(res, 'Search results', { users });
});

/**
 * GET /api/users/lookup?phone=9876543210
 * Find a doctor by mobile number (E.164 or 10-digit Indian).
 * Returns relationship metadata for DM / message-request flows.
 */
const lookupByPhone = asyncHandler(async (req, res) => {
  const { phone } = req.query;
  const normalized = normalizePhoneToE164(phone);
  if (!normalized) {
    return respond.badRequest(res, 'Enter a valid mobile number');
  }

  const digits = normalized.replace(/\D/g, '');
  const last10 = digits.length >= 10 ? digits.slice(-10) : digits;
  const phoneVariants = [
    ...new Set(
      [
        normalized,
        digits,
        last10,
        last10.length === 10 ? `+91${last10}` : null,
        last10.length === 10 ? `91${last10}` : null,
      ].filter(Boolean)
    ),
  ];

  const user = await User.findOne({
    phone: { $in: phoneVariants },
    isActive: true,
    isOnboarded: true,
  });
  if (!user) {
    return respond.notFound(res, 'No doctor found with this number on Vocle');
  }

  if (user._id.toString() === req.user._id.toString()) {
    return respond.ok(res, 'Lookup result', {
      user: user.toPublicProfile(),
      relationship: 'self',
      canMessage: true,
      sharesGroup: false,
      acceptsMessageRequests: false,
      canRequest: false,
      pendingRequest: null,
      isSelf: true,
    });
  }

  const { canMessageUser, canRequestMessage, shareActiveSpace } = require('../../utils/knownUsers');
  const MessageRequest = require('../message-requests/messageRequest.model');

  const canMessage = await canMessageUser(req.user._id, user._id);
  const sharesGroup = await shareActiveSpace(req.user._id, user._id);
  const canRequest = await canRequestMessage(req.user._id, user._id);
  const acceptsMessageRequests = canRequest;

  let pendingRequest = null;
  const pending = await MessageRequest.findOne({
    status: MESSAGE_REQUEST_STATUS.PENDING,
    $or: [
      { fromUserId: req.user._id, toUserId: user._id },
      { fromUserId: user._id, toUserId: req.user._id },
    ],
  }).select('_id fromUserId toUserId introMessage createdAt');

  if (pending) {
    pendingRequest = {
      id: pending._id.toString(),
      direction:
        pending.fromUserId.toString() === req.user._id.toString()
          ? 'sent'
          : 'received',
      introMessage: pending.introMessage || '',
      createdAt: pending.createdAt,
    };
  }

  return respond.ok(res, 'Lookup result', {
    user: user.toPublicProfile(),
    relationship: canMessage
      ? 'known'
      : sharesGroup
        ? 'group_member'
        : 'stranger',
    canMessage,
    sharesGroup,
    acceptsMessageRequests,
    canRequest,
    pendingRequest,
  });
});

/**
 * GET /api/users/me/needl
 * Thread roots the doctor cares about (Needl inbox).
 */
const getNeedl = asyncHandler(async (req, res) => {
  const Message = require('../messages/message.model');
  const Channel = require('../channels/channel.model');
  const Space = require('../spaces/space.model');

  const spaces = await Space.find(
    { 'members.userId': req.user._id, isActive: true },
    { _id: 1 }
  ).lean();
  const spaceIds = spaces.map((s) => s._id);

  const channels = await Channel.find({
    isArchived: false,
    $or: [
      { members: req.user._id },
      { spaceId: { $in: spaceIds } },
    ],
  })
    .select('_id spaceId type name')
    .lean();
  const channelIds = channels.map((c) => c._id);
  const channelById = Object.fromEntries(
    channels.map((c) => [c._id.toString(), c])
  );

  if (channelIds.length === 0) {
    return respond.ok(res, 'Needl empty', { threads: [] });
  }

  const myReplyRoots = await Message.find({
    senderId: req.user._id,
    threadId: { $ne: null },
    isDeleted: false,
    channelId: { $in: channelIds },
  })
    .select('threadId')
    .limit(80)
    .lean();
  const replyRootIds = [
    ...new Set(myReplyRoots.map((m) => m.threadId?.toString()).filter(Boolean)),
  ];

  const roots = await Message.find({
    channelId: { $in: channelIds },
    isDeleted: false,
    $or: [
      { threadId: null, replyCount: { $gt: 0 } },
      { _id: { $in: replyRootIds } },
    ],
  })
    .sort({ updatedAt: -1, _id: -1 })
    .limit(40)
    .populate('senderId', 'name displayTitle role avatarUrl')
    .lean();

  const threads = roots.map((m) => {
    const ch = channelById[m.channelId?.toString()] || {};
    return {
      rootMessageId: m._id.toString(),
      channelId: m.channelId?.toString(),
      spaceId: ch.spaceId?.toString() || null,
      channelName: ch.name || null,
      channelType: ch.type || null,
      preview: m.content?.text || '',
      replyCount: m.replyCount || 0,
      lastReplyAt: m.lastReply?.sentAt || m.updatedAt || m.createdAt,
      sender: m.senderId,
    };
  });

  return respond.ok(res, 'Needl threads', { threads });
});

module.exports = {
  getMe, updateMe, updateAvailability,
  registerFcmToken, getUserById, searchUsers, lookupByPhone, getNeedl,
};
