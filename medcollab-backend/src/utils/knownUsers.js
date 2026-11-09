/**
 * Privacy helpers for discovery + DMs.
 *
 * Open DM (canMessage): existing DM channel OR accepted message request only.
 * Shared groups / same college do NOT auto-open a chat — they may request.
 *
 * Message request (canRequestMessage):
 *  - mutual active group → always allowed (network intro)
 *  - otherwise → only if target opted in allowMessageRequestsFromAnyone
 */

const Space = require('../features/spaces/space.model');
const Channel = require('../features/channels/channel.model');
const User = require('../features/users/user.model');
const MessageRequest = require('../features/message-requests/messageRequest.model');
const { CHANNEL_TYPES, MESSAGE_REQUEST_STATUS } = require('../constants');

function normalizeInstitution(value) {
  return (value || '').trim().toLowerCase().replace(/\s+/g, ' ');
}

/**
 * Shared active space member ids (never includes self).
 */
async function resolveSharedSpaceUserIds(userId) {
  const selfId = userId.toString();
  const known = new Set();

  const spaces = await Space.find(
    { 'members.userId': userId, isActive: true },
    { members: 1 }
  ).lean();

  for (const space of spaces) {
    for (const member of space.members || []) {
      const id = member.userId?.toString();
      if (id && id !== selfId) known.add(id);
    }
  }

  return [...known];
}

/**
 * Users visible in name search: shared spaces ∪ DM peers ∪ same institution.
 * @param {import('mongoose').Types.ObjectId|string} userId
 * @returns {Promise<string[]>}
 */
async function resolveKnownUserIds(userId) {
  const selfId = userId.toString();
  const known = new Set(await resolveSharedSpaceUserIds(userId));

  const dms = await Channel.find({
    type: CHANNEL_TYPES.DIRECT,
    members: userId,
    isArchived: false,
  })
    .select('members')
    .lean();

  for (const dm of dms) {
    for (const memberId of dm.members || []) {
      const id = memberId.toString();
      if (id !== selfId) known.add(id);
    }
  }

  const me = await User.findById(userId).select('institution').lean();
  const myInstitution = normalizeInstitution(me?.institution);
  if (myInstitution.length >= 2) {
    const colleagues = await User.find({
      _id: { $ne: userId },
      isActive: true,
      isOnboarded: true,
      institution: { $exists: true, $nin: [null, ''] },
    })
      .select('_id institution')
      .lean();

    for (const colleague of colleagues) {
      if (normalizeInstitution(colleague.institution) === myInstitution) {
        known.add(colleague._id.toString());
      }
    }
  }

  return [...known];
}

async function shareActiveSpace(callerId, targetUserId) {
  const shared = await resolveSharedSpaceUserIds(callerId);
  return shared.includes(targetUserId.toString());
}

/**
 * True when caller may open a full DM (Seen, chat history) with target.
 */
async function canMessageUser(callerId, targetUserId) {
  if (!targetUserId || callerId.toString() === targetUserId.toString()) {
    return false;
  }

  // Exact 1:1 DM only — a group Needl that happens to contain both users
  // must not count as an open pair conversation. An archived 1:1 does not
  // count either: archiving ends the relationship (security suite), so a
  // fresh request/accept is needed — the app offers it (REQ 11).
  const existingDm = await Channel.findOne({
    type: CHANNEL_TYPES.DIRECT,
    members: { $all: [callerId, targetUserId], $size: 2 },
    isArchived: false,
  })
    .select('_id')
    .lean();
  if (existingDm) return true;

  const acceptedRequest = await MessageRequest.findOne({
    status: MESSAGE_REQUEST_STATUS.ACCEPTED,
    $or: [
      { fromUserId: callerId, toUserId: targetUserId },
      { fromUserId: targetUserId, toUserId: callerId },
    ],
  })
    .select('_id')
    .lean();
  if (acceptedRequest) return true;

  return false;
}

/**
 * True when either side blocked the other via a message request.
 */
async function isBlockedPair(callerId, targetUserId) {
  const blocked = await MessageRequest.findOne({
    status: MESSAGE_REQUEST_STATUS.BLOCKED,
    $or: [
      { fromUserId: callerId, toUserId: targetUserId },
      { fromUserId: targetUserId, toUserId: callerId },
    ],
  })
    .select('_id')
    .lean();
  return Boolean(blocked);
}

/**
 * True when caller may send a message request to target.
 *
 * REQ 5: requests are open by default — any active, onboarded doctor can be
 * asked. The recipient still decides (accept / decline), so no chat or Seen
 * happens without consent. Privacy settings only guard being added to groups.
 */
async function canRequestMessage(callerId, targetUserId) {
  if (!targetUserId || callerId.toString() === targetUserId.toString()) {
    return false;
  }
  if (await canMessageUser(callerId, targetUserId)) {
    return false;
  }

  const target = await User.findById(targetUserId)
    .select('isActive isOnboarded')
    .lean();
  // Blocks are enforced separately (createRequest, describeRelationship) so
  // the controller's own block check stays independently testable.
  return Boolean(target && target.isActive !== false && target.isOnboarded);
}

/**
 * May `callerId` put `targetUserId` straight into a group conversation
 * (Needl / group DM, or a group via "Add members")?
 *
 * REQ 5: message *requests* are open to everyone, but being *added* is the
 * privacy boundary: only people who already know you (an open 1:1 chat or
 * accepted request, or a shared group) — or anyone, if you allow it.
 * Never across a block.
 */
async function canAddToConversation(callerId, targetUserId) {
  if (!targetUserId || callerId.toString() === targetUserId.toString()) {
    return false;
  }
  const target = await User.findById(targetUserId)
    .select('isActive isOnboarded notifications.allowGroupAddsFromAnyone')
    .lean();
  if (!target || target.isActive === false || !target.isOnboarded) return false;
  if (await isBlockedPair(callerId, targetUserId)) return false;
  if (target.notifications?.allowGroupAddsFromAnyone === true) return true;
  return (
    (await canMessageUser(callerId, targetUserId)) ||
    (await shareActiveSpace(callerId, targetUserId))
  );
}

/**
 * Everything the app needs to decide between "Message", "Send request",
 * "Request pending" and "Accept" for one person (REQ 11).
 */
async function describeRelationship(callerId, targetUserId) {
  const canMessage = await canMessageUser(callerId, targetUserId);
  const sharesGroup = await shareActiveSpace(callerId, targetUserId);
  const canRequest =
    (await canRequestMessage(callerId, targetUserId)) &&
    !(await isBlockedPair(callerId, targetUserId));

  let pendingRequest = null;
  const pending = await MessageRequest.findOne({
    status: MESSAGE_REQUEST_STATUS.PENDING,
    $or: [
      { fromUserId: callerId, toUserId: targetUserId },
      { fromUserId: targetUserId, toUserId: callerId },
    ],
  }).select('_id fromUserId toUserId introMessage createdAt');

  if (pending) {
    pendingRequest = {
      id: pending._id.toString(),
      direction:
        pending.fromUserId.toString() === callerId.toString()
          ? 'sent'
          : 'received',
      introMessage: pending.introMessage || '',
      createdAt: pending.createdAt,
    };
  }

  return {
    relationship: canMessage
      ? 'known'
      : sharesGroup
        ? 'group_member'
        : 'stranger',
    canMessage,
    sharesGroup,
    acceptsMessageRequests: canRequest,
    canRequest,
    pendingRequest,
  };
}

module.exports = {
  resolveKnownUserIds,
  resolveSharedSpaceUserIds,
  shareActiveSpace,
  canMessageUser,
  canRequestMessage,
  isBlockedPair,
  canAddToConversation,
  describeRelationship,
  normalizeInstitution,
};
