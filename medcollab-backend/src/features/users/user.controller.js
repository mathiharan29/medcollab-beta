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
const {
  normalizeOwnedMediaPublicId,
  deleteStoredMedia,
} = require('../media/media.controller');

const avatarPublicIdFromUrl = (rawUrl, userId) => {
  if (!rawUrl) return null;
  let pathname;
  try {
    pathname = rawUrl.startsWith('/') ? rawUrl : new URL(rawUrl).pathname;
  } catch {
    return null;
  }

  let publicId = null;
  if (pathname.startsWith('/uploads/')) {
    publicId = decodeURIComponent(pathname.slice('/uploads/'.length));
  } else {
    const marker = `/medcollab/avatars/${userId}/`;
    const markerIndex = pathname.indexOf(marker);
    if (markerIndex >= 0) {
      publicId = pathname
        .slice(markerIndex + 1)
        .replace(/\.[^/.]+$/, '');
    }
  }

  const normalized = normalizeOwnedMediaPublicId(publicId, userId);
  return normalized?.startsWith(`medcollab/avatars/${userId}/`) ? normalized : null;
};

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
                   'institution', 'city', 'bio', 'notifications', 'avatarUrl',
                   'vocleUsername'];

  const updates = {};
  allowed.forEach((field) => {
    if (req.body[field] !== undefined) updates[field] = req.body[field];
  });

  // Blank username means "not set" — never store an empty string on a unique index.
  if (typeof updates.vocleUsername === 'string' && !updates.vocleUsername.trim()) {
    delete updates.vocleUsername;
  }

  // REQ 5: Vocle ID = unique @username. Clear message instead of a raw 409.
  const usernames = require('../../utils/username');
  if (updates.vocleUsername !== undefined) {
    const wanted = usernames.normalizeUsername(updates.vocleUsername);
    const problem = usernames.usernameProblem(wanted);
    if (problem) return respond.badRequest(res, problem);
    if (await usernames.isUsernameTaken(wanted, req.user._id)) {
      return respond.conflict(res, `@${wanted} is taken — try another`);
    }
    updates.vocleUsername = wanted;
  }

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

  // Every onboarded doctor has a Vocle ID from day one.
  if (updated.isOnboarded && !updated.vocleUsername) {
    await usernames.ensureUsername(updated);
  }

  if (
    updates.avatarUrl !== undefined &&
    updates.avatarUrl !== user.avatarUrl
  ) {
    const previousPublicId = avatarPublicIdFromUrl(
      user.avatarUrl,
      req.user._id.toString()
    );
    if (previousPublicId) {
      try {
        await deleteStoredMedia(previousPublicId);
      } catch (err) {
        logger.warn(`Previous avatar cleanup failed: ${err.message}`);
      }
    }
  }

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

const SEARCH_SELECT =
  'name displayTitle role speciality institution avatarUrl availability vocleUsername';

/**
 * GET /api/users/search?q=priya&spaceId=...
 *
 * REQ 5: search every active, onboarded doctor on Vocle — by name,
 * @username (Vocle ID), speciality or institution. People you already know
 * (shared groups, chats, same institution) come first and are flagged
 * `isKnown`. A phone number finds anyone only by the full number; partial
 * digits match only people you know (no number enumeration).
 * Optional spaceId narrows to that group's members (for @mentions).
 */
const searchUsers = asyncHandler(async (req, res) => {
  const { q, spaceId } = req.query;

  if (!q || q.trim().length < 2) {
    return respond.badRequest(res, 'Search query must be at least 2 characters');
  }

  const raw = q.trim().slice(0, 60);
  const { resolveKnownUserIds } = require('../../utils/knownUsers');
  const Space = require('../spaces/space.model');
  const knownIds = new Set(await resolveKnownUserIds(req.user._id));

  let scopeIds = null;
  if (spaceId) {
    const space = await Space.findById(spaceId).select('members');
    if (!space || !space.isMember(req.user._id)) {
      return respond.ok(res, 'Search results', { users: [] });
    }
    scopeIds = (space.members || []).map((m) => m.userId);
  }

  const handle = raw.replace(/^@/, '');
  const textRegex = new RegExp(escapeRegex(handle), 'i');
  const prefixRegex = new RegExp('^' + escapeRegex(handle.toLowerCase()));
  const orClauses = [
    { name: textRegex },
    { speciality: textRegex },
    { institution: textRegex },
    { vocleUsername: prefixRegex },
  ];

  const digits = raw.replace(/\D/g, '');
  const looksLikePhone = digits.length >= 4 && digits.length >= raw.replace(/\s/g, '').length - 1;
  if (looksLikePhone) {
    const last10 = digits.length > 10 ? digits.slice(-10) : digits;
    if (last10.length === 10) {
      // Full number: anyone on Vocle.
      orClauses.push({ phone: new RegExp(escapeRegex(last10) + '$') });
    } else {
      // Partial digits: only people you already know.
      orClauses.push({
        _id: { $in: [...knownIds] },
        phone: new RegExp(escapeRegex(last10)),
      });
    }
  }

  const filter = {
    _id: scopeIds ? { $in: scopeIds, $ne: req.user._id } : { $ne: req.user._id },
    isActive: true,
    isOnboarded: true,
    $or: orClauses,
  };

  const found = await User.find(filter).select(SEARCH_SELECT).limit(60).lean();

  // Known people first, then exact @username, then name starts-with, A–Z.
  const lower = handle.toLowerCase();
  const rank = (u) =>
    (knownIds.has(u._id.toString()) ? 0 : 4) +
    (u.vocleUsername === lower ? 0 : 2) +
    ((u.name || '').toLowerCase().startsWith(lower) ? 0 : 1);
  found.sort(
    (a, b) => rank(a) - rank(b) || (a.name || '').localeCompare(b.name || '')
  );

  const users = found.slice(0, 25).map((u) => ({
    ...u,
    isKnown: knownIds.has(u._id.toString()),
  }));
  return respond.ok(res, 'Search results', { users });
});

/**
 * GET /api/users/username-available?u=asharao
 * Live check for Edit profile (REQ 5).
 */
const usernameAvailable = asyncHandler(async (req, res) => {
  const usernames = require('../../utils/username');
  const wanted = usernames.normalizeUsername(req.query.u);
  const problem = usernames.usernameProblem(wanted);
  if (problem) {
    return respond.ok(res, problem, { username: wanted, available: false, reason: problem });
  }
  const taken = await usernames.isUsernameTaken(wanted, req.user._id);
  return respond.ok(res, taken ? 'Taken' : 'Available', {
    username: wanted,
    available: !taken,
    reason: taken ? `@${wanted} is taken` : null,
  });
});

/**
 * POST /api/users/contacts/match  { phones: string[] }
 *
 * REQ 5 contact sync: which of my phone contacts are on Vocle?
 * Numbers are matched in memory and never stored. Up to 3000 per call.
 * Returns each match with the number it matched, so the app can show the
 * name saved in the phone's address book.
 */
const matchContacts = asyncHandler(async (req, res) => {
  const list = Array.isArray(req.body?.phones) ? req.body.phones : null;
  if (!list) return respond.badRequest(res, 'phones must be an array');
  if (list.length > 3000) {
    return respond.badRequest(res, 'Send at most 3000 numbers at a time');
  }

  // Indian-first normalisation to the last 10 digits (+91 / 0 prefixes).
  const byLast10 = new Map();
  for (const entry of list) {
    if (typeof entry !== 'string' || entry.length > 32) continue;
    const digits = entry.replace(/\D/g, '');
    if (digits.length < 10) continue;
    const last10 = digits.slice(-10);
    if (!byLast10.has(last10)) byLast10.set(last10, entry);
  }
  if (byLast10.size === 0) {
    return respond.ok(res, 'Contacts matched', { matches: [] });
  }

  const variants = [];
  for (const last10 of byLast10.keys()) {
    variants.push(`+91${last10}`, last10, `91${last10}`);
  }
  const users = await User.find({
    phone: { $in: variants },
    isActive: true,
    isOnboarded: true,
    _id: { $ne: req.user._id },
  })
    .select(`${SEARCH_SELECT} phone`)
    .lean();

  const { describeRelationship } = require('../../utils/knownUsers');
  const matches = [];
  for (const u of users) {
    const last10 = (u.phone || '').replace(/\D/g, '').slice(-10);
    const relation = await describeRelationship(req.user._id, u._id);
    const { phone: _phone, ...profile } = u;
    matches.push({
      contactPhone: byLast10.get(last10) || null,
      user: profile,
      canMessage: relation.canMessage,
      pendingRequest: relation.pendingRequest,
    });
  }
  return respond.ok(res, 'Contacts matched', { matches });
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

  const { describeRelationship } = require('../../utils/knownUsers');
  const relation = await describeRelationship(req.user._id, user._id);

  return respond.ok(res, 'Lookup result', {
    user: user.toPublicProfile(),
    ...relation,
  });
});

/**
 * GET /api/users/:id/relationship
 * Same shape as phone lookup, by user id — lets every "Message" button decide
 * between opening the chat, sending a request, or accepting one (REQ 11).
 */
const getRelationship = asyncHandler(async (req, res) => {
  const user = await User.findOne({
    _id: req.params.id,
    isActive: true,
    isOnboarded: true,
  });
  if (!user) return respond.notFound(res, 'Doctor not found');

  if (user._id.toString() === req.user._id.toString()) {
    return respond.ok(res, 'Relationship', {
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

  const { describeRelationship } = require('../../utils/knownUsers');
  const relation = await describeRelationship(req.user._id, user._id);
  return respond.ok(res, 'Relationship', {
    user: user.toPublicProfile(),
    ...relation,
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
  const { canAccessChannel } = require('../../utils/channelAccess');

  const spaces = await Space.find(
    { 'members.userId': req.user._id, isActive: true },
    { _id: 1 }
  ).lean();
  const spaceIds = spaces.map((s) => s._id);

  // Candidate set (may include private channels caller cannot read).
  const candidates = await Channel.find({
    isArchived: false,
    $or: [
      { members: req.user._id },
      { spaceId: { $in: spaceIds } },
    ],
  })
    .select('_id spaceId type name isPrivate members')
    .lean();

  // Live access policy — drop private/revoked channels (VR-N1).
  const channels = [];
  for (const ch of candidates) {
    if (await canAccessChannel(req.user._id, ch._id)) {
      channels.push(ch);
    }
  }
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
  getRelationship, usernameAvailable, matchContacts,
};
