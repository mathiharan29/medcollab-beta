/**
 * HANDOFF CONTROLLER
 *
 * The most clinically significant controller in the system.
 * Every state transition is logged and, when submitted/acknowledged,
 * triggers notifications and a system message in the linked channel.
 */

const Handoff = require('./handoff.model');
const Channel = require('../channels/channel.model');
const Space = require('../spaces/space.model');
const Message = require('../messages/message.model');
const User = require('../users/user.model');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { emitNewMessage, getIO } = require('../../socket');
const {
  notifyHandoffReceived,
  notifyHandoffAcknowledged,
} = require('../../services/notification.service');
const { HANDOFF_STATUS, MESSAGE_TYPES, SOCKET_EVENTS } = require('../../constants');
const logger = require('../../utils/logger');

/**
 * POST a system message to the channel linking to the handoff
 * Appears in chat as a special card: "Dr. Priya sent a handoff to Dr. Arjun [View →]"
 */
const postHandoffSystemMessage = async ({ channel, handoff, fromUser, toUser, action }) => {
  try {
    const textMap = {
      submitted: `${fromUser.name} sent a ${handoff.shiftType} shift handoff to ${toUser.name}`,
      acknowledged: `${toUser.name} acknowledged ${fromUser.name}'s ${handoff.shiftType} shift handoff ✓`,
    };

    const message = await Message.create({
      channelId: channel._id,
      spaceId: channel.spaceId,
      senderId: fromUser._id,
      type: MESSAGE_TYPES.HANDOFF,
      content: {
        text: textMap[action] || 'Handoff update',
        handoffId: handoff._id,
      },
    });

    emitNewMessage(channel._id.toString(), message.toObject());
  } catch (err) {
    logger.error(`Handoff system message failed: ${err.message}`);
  }
};

/**
 * POST /api/handoffs
 * Create a new DRAFT handoff
 */
const createHandoff = asyncHandler(async (req, res) => {
  const { spaceId, channelId, toUserId, shiftDate, shiftType, patients, shiftSummary } = req.body;

  // Verify the space membership
  const space = await Space.findById(spaceId);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isMember(req.user._id)) return respond.forbidden(res, 'Not a space member');
  if (!space.isMember(toUserId)) return respond.badRequest(res, 'Recipient is not a member of this space');

  // Channel must belong to this space (VR-S2).
  const channel = await Channel.findById(channelId).select('spaceId isArchived');
  if (!channel) return respond.notFound(res, 'Channel not found');
  if (!channel.spaceId || channel.spaceId.toString() !== spaceId.toString()) {
    return respond.badRequest(res, 'Channel does not belong to this space');
  }
  if (channel.isArchived) {
    return respond.badRequest(res, 'Cannot create a handoff in an archived channel');
  }

  const handoff = await Handoff.create({
    spaceId,
    channelId,
    fromUserId: req.user._id,
    toUserId,
    shiftDate: new Date(shiftDate),
    shiftType,
    patients: patients || [],
    shiftSummary: shiftSummary || '',
    status: HANDOFF_STATUS.DRAFT,
  });

  return respond.created(res, 'Handoff draft created', { handoff });
});

/**
 * GET /api/handoffs
 * My handoff inbox — sent and received
 */
const getMyHandoffs = asyncHandler(async (req, res) => {
  const { type = 'all', status, spaceId, date } = req.query;

  const query = {};
  if (spaceId) query.spaceId = spaceId;
  if (status) query.status = status;
  if (date) {
    const day = new Date(date);
    const next = new Date(day);
    next.setDate(next.getDate() + 1);
    query.shiftDate = { $gte: day, $lt: next };
  }

  if (type === 'sent') {
    query.fromUserId = req.user._id;
  } else if (type === 'received') {
    query.toUserId = req.user._id;
    // Receivers never see drafts — even with explicit status=draft (VR-S4).
    const visibleToReceiver = [
      HANDOFF_STATUS.SUBMITTED,
      HANDOFF_STATUS.ACKNOWLEDGED,
    ];
    if (status && visibleToReceiver.includes(status)) {
      query.status = status;
    } else {
      query.status = { $in: visibleToReceiver };
    }
  } else if (type === 'reassigned') {
    // Handoffs this user reassigned to someone else.
    query['assignmentHistory.byUserId'] = req.user._id;
  } else {
    // 'all' — sent (any status), received (non-draft), or previously
    // reassigned by / away from me (so past assignees keep visibility).
    query.$or = [
      { fromUserId: req.user._id },
      { toUserId: req.user._id, status: { $in: [HANDOFF_STATUS.SUBMITTED, HANDOFF_STATUS.ACKNOWLEDGED] } },
      { 'assignmentHistory.byUserId': req.user._id },
      { 'assignmentHistory.fromUserId': req.user._id },
    ];
  }

  const handoffs = await Handoff.find(query)
    .sort({ shiftDate: -1, createdAt: -1 })
    .populate('fromUserId', 'name displayTitle role avatarUrl')
    .populate('toUserId', 'name displayTitle role avatarUrl')
    .populate('writeBackNotes.authorId', 'name displayTitle role avatarUrl')
    .lean();

  return respond.ok(res, 'Handoffs fetched', { handoffs });
});

/**
 * GET /api/handoffs/:id
 * Full handoff detail (sender or receiver only)
 */
const getHandoffById = asyncHandler(async (req, res) => {
  const handoff = await Handoff.findById(req.params.id)
    .populate('fromUserId', 'name displayTitle role avatarUrl speciality')
    .populate('toUserId', 'name displayTitle role avatarUrl speciality')
    .populate('writeBackNotes.authorId', 'name displayTitle role avatarUrl')
    .lean();

  if (!handoff) return respond.notFound(res, 'Handoff not found');

  const userId = req.user._id.toString();
  const isSender = handoff.fromUserId._id.toString() === userId;
  const isReceiver = handoff.toUserId._id.toString() === userId;
  // Previous assignees keep read-only visibility (Reassigned tab); writes stay locked.
  const isPreviousParticipant = (handoff.assignmentHistory || []).some(
    (entry) =>
      entry.byUserId?.toString() === userId ||
      entry.fromUserId?.toString() === userId
  );

  // Space admins can also view for audit purposes
  const space = await Space.findById(handoff.spaceId);
  const isAdmin = space?.isAdmin(req.user._id);

  if (!isSender && !isReceiver && !isPreviousParticipant && !isAdmin) {
    return respond.forbidden(res, 'Access denied');
  }

  // Drafts are sender (or admin) only until submitted (VR-S4).
  if (
    handoff.status === HANDOFF_STATUS.DRAFT &&
    !isSender &&
    !isAdmin
  ) {
    return respond.forbidden(res, 'Draft handoff is not visible yet');
  }

  return respond.ok(res, 'Handoff fetched', { handoff });
});

const populateHandoff = (id) =>
  Handoff.findById(id)
    .populate('fromUserId', 'name displayTitle role avatarUrl speciality')
    .populate('toUserId', 'name displayTitle role avatarUrl speciality')
    .populate('writeBackNotes.authorId', 'name displayTitle role avatarUrl')
    .lean();

const emitHandoffEvent = (event, handoff, extra = {}) => {
  try {
    getIO().to(`space:${handoff.spaceId}`).emit(event, {
      handoffId: handoff._id.toString(),
      spaceId: handoff.spaceId.toString(),
      fromUserId: handoff.fromUserId.toString(),
      toUserId: handoff.toUserId.toString(),
      status: handoff.status,
      ...extra,
    });
  } catch (err) {
    logger.debug(`Handoff socket broadcast skipped: ${err.message}`);
  }
};

/**
 * PUT /api/handoffs/:id
 * Sender edits a handoff — drafts freely; after submit too (REQ 10).
 *
 * Clinical safety for submitted handoffs:
 *  - every edit is recorded in editHistory + a visible write-back note;
 *  - an acknowledged handoff goes back to "submitted" so the receiver
 *    re-acknowledges the changed content;
 *  - the receiver is notified.
 */
const updateHandoff = asyncHandler(async (req, res) => {
  const handoff = await Handoff.findById(req.params.id);
  if (!handoff) return respond.notFound(res, 'Handoff not found');
  if (handoff.fromUserId.toString() !== req.user._id.toString()) {
    return respond.forbidden(res, 'Only the sender can edit a handoff');
  }

  const allowed = ['patients', 'shiftSummary', 'shiftDate', 'shiftType'];
  allowed.forEach((f) => {
    if (req.body[f] !== undefined) handoff[f] = req.body[f];
  });
  const changed = allowed.filter((f) => handoff.isModified(f));

  const wasDraft = handoff.status === HANDOFF_STATUS.DRAFT;
  if (wasDraft || changed.length === 0) {
    await handoff.save();
    return respond.ok(res, 'Handoff updated', {
      handoff: wasDraft ? handoff : await populateHandoff(handoff._id),
    });
  }

  if (handoff.patients.length === 0) {
    return respond.badRequest(res, 'A submitted handoff needs at least one patient');
  }

  const statusBefore = handoff.status;
  handoff.editHistory.push({
    byUserId: req.user._id,
    fields: changed,
    statusBefore,
    at: new Date(),
  });
  const reAck = statusBefore === HANDOFF_STATUS.ACKNOWLEDGED;
  if (reAck) {
    handoff.status = HANDOFF_STATUS.SUBMITTED;
    handoff.acknowledgedAt = null;
    handoff.acknowledgementNote = '';
  }
  handoff.writeBackNotes.push({
    authorId: req.user._id,
    text: reAck
      ? 'Handoff edited after acknowledgement — please review and acknowledge again.'
      : 'Handoff edited — please review the changes.',
    kind: 'note',
    createdAt: new Date(),
  });
  await handoff.save();

  const populated = await populateHandoff(handoff._id);
  respond.ok(res, 'Handoff updated', { handoff: populated });

  emitHandoffEvent(SOCKET_EVENTS.HANDOFF_UPDATED, handoff, { fields: changed });
  setImmediate(async () => {
    try {
      const { sendNotification } = require('../../services/notification.service');
      const { NOTIFICATION_TYPES, MESSAGE_PRIORITY } = require('../../constants');
      await sendNotification({
        userId: handoff.toUserId,
        type: NOTIFICATION_TYPES.HANDOFF_RECEIVED,
        title: 'Handoff updated',
        body: `${req.user.name} edited the ${handoff.shiftType} shift handoff${reAck ? ' — please acknowledge again' : ''}`,
        referenceId: handoff._id,
        referenceType: 'Handoff',
        metadata: { spaceId: handoff.spaceId, handoffId: handoff._id },
        actor: req.user,
        priority: reAck ? MESSAGE_PRIORITY.URGENT : MESSAGE_PRIORITY.NORMAL,
      });
    } catch (err) {
      logger.error(`Handoff edit notify failed: ${err.message}`);
    }
  });
});

/**
 * POST /api/handoffs/:id/submit
 * Submit a draft — makes it visible to the receiver and triggers notification
 */
const submitHandoff = asyncHandler(async (req, res) => {
  const existing = await Handoff.findById(req.params.id);
  if (!existing) return respond.notFound(res, 'Handoff not found');
  if (existing.fromUserId.toString() !== req.user._id.toString()) {
    return respond.forbidden(res, 'Only the sender can submit');
  }
  if (existing.patients.length === 0) {
    return respond.badRequest(res, 'Add at least one patient before submitting');
  }

  const handoff = await Handoff.findOneAndUpdate(
    {
      _id: req.params.id,
      fromUserId: req.user._id,
      status: HANDOFF_STATUS.DRAFT,
    },
    {
      status: HANDOFF_STATUS.SUBMITTED,
      submittedAt: new Date(),
    },
    { new: true },
  );

  if (!handoff) {
    return respond.badRequest(res, 'Handoff is already submitted');
  }

  // Real-time list refresh for anyone viewing handoffs in this space
  try {
    getIO().to(`space:${handoff.spaceId}`).emit(SOCKET_EVENTS.HANDOFF_SUBMITTED, {
      handoffId: handoff._id.toString(),
      spaceId: handoff.spaceId.toString(),
      fromUserId: handoff.fromUserId.toString(),
      toUserId: handoff.toUserId.toString(),
      status: handoff.status,
      submittedAt: handoff.submittedAt?.toISOString(),
    });
  } catch (err) {
    logger.debug(`Handoff socket broadcast skipped: ${err.message}`);
  }

  const [fromUser, toUser] = await Promise.all([
    User.findById(handoff.fromUserId).select('name avatarUrl'),
    User.findById(handoff.toUserId).select('name avatarUrl fcmTokens'),
  ]);

  respond.ok(res, 'Handoff submitted', { handoff });

  // Post-response async side-effects
  setImmediate(async () => {
    try {
      await notifyHandoffReceived({ toUser, fromUser, handoff });
    } catch (err) {
      logger.error(`Handoff submit side-effects failed: ${err.message}`);
    }
  });
});

/**
 * POST /api/handoffs/:id/acknowledge
 * Receiver confirms they have read and accepted the handoff
 */
const acknowledgeHandoff = asyncHandler(async (req, res) => {
  const handoff = await Handoff.findOneAndUpdate(
    {
      _id: req.params.id,
      toUserId: req.user._id,
      status: HANDOFF_STATUS.SUBMITTED,
    },
    {
      status: HANDOFF_STATUS.ACKNOWLEDGED,
      acknowledgedAt: new Date(),
      acknowledgementNote: req.body.note || '',
    },
    { new: true },
  );

  if (!handoff) {
    return respond.badRequest(res, 'Handoff must be submitted before acknowledging');
  }

  const [fromUser, toUser] = await Promise.all([
    User.findById(handoff.fromUserId).select('name avatarUrl fcmTokens'),
    User.findById(handoff.toUserId).select('name avatarUrl'),
  ]);

  respond.ok(res, 'Handoff acknowledged', { handoff });

  try {
    getIO().to(`space:${handoff.spaceId}`).emit(SOCKET_EVENTS.HANDOFF_ACKNOWLEDGED, {
      handoffId: handoff._id.toString(),
      spaceId: handoff.spaceId.toString(),
      fromUserId: handoff.fromUserId.toString(),
      toUserId: handoff.toUserId.toString(),
      status: handoff.status,
      acknowledgedAt: handoff.acknowledgedAt?.toISOString(),
    });
  } catch (err) {
    logger.debug(`Handoff acknowledge socket broadcast skipped: ${err.message}`);
  }

  setImmediate(async () => {
    try {
      await notifyHandoffAcknowledged({ fromUser, toUser, handoff });
    } catch (err) {
      logger.error(`Handoff acknowledge side-effects failed: ${err.message}`);
    }
  });
});

/**
 * POST /api/handoffs/:id/notes
 * Assignee or sender adds a write-back note (can attend / can't / clinical update).
 */
const addHandoffNote = asyncHandler(async (req, res) => {
  const text = (req.body.text || '').trim();
  if (!text) return respond.badRequest(res, 'Note text is required');
  if (text.length > 1000) {
    return respond.badRequest(res, 'Note cannot exceed 1000 characters');
  }
  const kind = ['note', 'cant_cover', 'covered_late', 'reassign', 'missed'].includes(
    req.body.kind
  )
    ? req.body.kind
    : 'note';

  const handoff = await Handoff.findById(req.params.id);
  if (!handoff) return respond.notFound(res, 'Handoff not found');

  const uid = req.user._id.toString();
  const isParty =
    handoff.fromUserId.toString() === uid || handoff.toUserId.toString() === uid;
  if (!isParty) return respond.forbidden(res, 'Only participants can add notes');
  if (handoff.status === HANDOFF_STATUS.DRAFT) {
    return respond.badRequest(res, 'Submit the handoff before adding notes');
  }

  handoff.writeBackNotes.push({
    authorId: req.user._id,
    text,
    kind,
    createdAt: new Date(),
  });
  await handoff.save();

  const populated = await Handoff.findById(handoff._id)
    .populate('fromUserId', 'name displayTitle role avatarUrl')
    .populate('toUserId', 'name displayTitle role avatarUrl')
    .populate('writeBackNotes.authorId', 'name displayTitle role avatarUrl')
    .lean();

  respond.ok(res, 'Note added', { handoff: populated });

  try {
    getIO().to(`space:${handoff.spaceId}`).emit(SOCKET_EVENTS.HANDOFF_NOTE_ADDED, {
      handoffId: handoff._id.toString(),
      spaceId: handoff.spaceId.toString(),
    });
  } catch (err) {
    logger.debug(`Handoff note socket skipped: ${err.message}`);
  }
});

/**
 * POST /api/handoffs/:id/reassign
 * Current assignee (or sender) redirects to another space member.
 */
const reassignHandoff = asyncHandler(async (req, res) => {
  const { toUserId, note } = req.body;
  if (!toUserId) return respond.badRequest(res, 'toUserId is required');

  const handoff = await Handoff.findById(req.params.id);
  if (!handoff) return respond.notFound(res, 'Handoff not found');
  if (handoff.status === HANDOFF_STATUS.DRAFT) {
    return respond.badRequest(res, 'Submit before reassigning');
  }

  const uid = req.user._id.toString();
  const isAssignee = handoff.toUserId.toString() === uid;
  const isSender = handoff.fromUserId.toString() === uid;
  if (!isAssignee && !isSender) {
    return respond.forbidden(res, 'Only the assignee or sender can reassign');
  }
  if (toUserId === handoff.toUserId.toString()) {
    return respond.badRequest(res, 'Already assigned to this doctor');
  }

  const space = await Space.findById(handoff.spaceId);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isMember(toUserId)) {
    return respond.badRequest(res, 'New assignee must be a group member');
  }

  const previousTo = handoff.toUserId;
  handoff.assignmentHistory.push({
    fromUserId: previousTo,
    toUserId,
    byUserId: req.user._id,
    note: (note || '').trim().slice(0, 500),
    at: new Date(),
  });
  handoff.toUserId = toUserId;
  handoff.status = HANDOFF_STATUS.SUBMITTED;
  handoff.acknowledgedAt = null;
  handoff.acknowledgementNote = '';
  handoff.writeBackNotes.push({
    authorId: req.user._id,
    text:
      (note || '').trim() ||
      'Reassigned — please take over this shift handoff.',
    kind: 'reassign',
    createdAt: new Date(),
  });
  await handoff.save();

  const populated = await Handoff.findById(handoff._id)
    .populate('fromUserId', 'name displayTitle role avatarUrl')
    .populate('toUserId', 'name displayTitle role avatarUrl')
    .populate('writeBackNotes.authorId', 'name displayTitle role avatarUrl')
    .lean();

  const [fromUser, toUser] = await Promise.all([
    User.findById(handoff.fromUserId).select('name avatarUrl fcmTokens'),
    User.findById(toUserId).select('name avatarUrl fcmTokens'),
  ]);

  respond.ok(res, 'Handoff reassigned', { handoff: populated });

  try {
    getIO().to(`space:${handoff.spaceId}`).emit(SOCKET_EVENTS.HANDOFF_REASSIGNED, {
      handoffId: handoff._id.toString(),
      spaceId: handoff.spaceId.toString(),
      toUserId: toUserId.toString(),
      previousToUserId: previousTo.toString(),
    });
  } catch (err) {
    logger.debug(`Handoff reassign socket skipped: ${err.message}`);
  }

  setImmediate(async () => {
    try {
      if (fromUser && toUser) {
        await notifyHandoffReceived({ toUser, fromUser, handoff });
      }
    } catch (err) {
      logger.error(`Handoff reassign notify failed: ${err.message}`);
    }
  });
});

/**
 * DELETE /api/handoffs/:id
 * Sender deletes a handoff (REQ 10). Drafts are removed; submitted or
 * acknowledged handoffs are soft-deleted — hidden from everyone, kept in
 * the database for the medical audit trail — and the receiver is told.
 */
const deleteHandoff = asyncHandler(async (req, res) => {
  const handoff = await Handoff.findById(req.params.id);
  if (!handoff) return respond.notFound(res, 'Handoff not found');
  if (handoff.fromUserId.toString() !== req.user._id.toString()) {
    return respond.forbidden(res, 'Only the sender can delete');
  }

  if (handoff.status === HANDOFF_STATUS.DRAFT) {
    await handoff.deleteOne();
    return respond.ok(res, 'Draft handoff deleted');
  }

  handoff.isDeleted = true;
  handoff.deletedAt = new Date();
  handoff.deletedBy = req.user._id;
  await handoff.save();

  respond.ok(res, 'Handoff deleted');

  emitHandoffEvent(SOCKET_EVENTS.HANDOFF_DELETED, handoff);
  setImmediate(async () => {
    try {
      const { sendNotification } = require('../../services/notification.service');
      const { NOTIFICATION_TYPES, MESSAGE_PRIORITY } = require('../../constants');
      await sendNotification({
        userId: handoff.toUserId,
        type: NOTIFICATION_TYPES.HANDOFF_RECEIVED,
        title: 'Handoff withdrawn',
        body: `${req.user.name} deleted the ${handoff.shiftType} shift handoff they sent you`,
        referenceId: handoff._id,
        referenceType: 'Handoff',
        // No handoffId: the alert must not open a handoff that is gone.
        metadata: { spaceId: handoff.spaceId, deletedHandoffId: handoff._id },
        actor: req.user,
        priority: MESSAGE_PRIORITY.NORMAL,
      });
    } catch (err) {
      logger.error(`Handoff delete notify failed: ${err.message}`);
    }
  });
});

/**
 * GET /api/spaces/:spaceId/handoffs
 * Space-level handoff history (admin audit view)
 */
const getSpaceHandoffs = asyncHandler(async (req, res) => {
  const { spaceId } = req.params;
  const { date, shiftType, fromUserId, status, limit = 20, before } = req.query;

  const space = await Space.findById(spaceId);
  if (!space) return respond.notFound(res, 'Space not found');
  if (!space.isMember(req.user._id)) return respond.forbidden(res, 'Not a space member');

  const query = {
    spaceId,
    // Drafts are private to their author, including from space admins.
    $and: [{
      $or: [
        { status: { $ne: HANDOFF_STATUS.DRAFT } },
        { fromUserId: req.user._id },
      ],
    }],
  };

  if (status) query.$and.push({ status });
  if (date) {
    const day = new Date(date);
    const next = new Date(day);
    next.setDate(next.getDate() + 1);
    query.shiftDate = { $gte: day, $lt: next };
  }
  if (shiftType) query.shiftType = shiftType;
  if (fromUserId) query.fromUserId = fromUserId;

  if (before) {
    const cursor = await Handoff.findOne({ ...query, _id: before })
      .select('shiftDate _id')
      .lean();
    if (!cursor) return respond.badRequest(res, 'Invalid handoff cursor');
    query.$and.push({
      $or: [
        { shiftDate: { $lt: cursor.shiftDate } },
        { shiftDate: cursor.shiftDate, _id: { $lt: cursor._id } },
      ],
    });
  }

  const pageLimit = Math.min(parseInt(limit, 10) || 20, 50);
  const handoffs = await Handoff.find(query)
    .sort({ shiftDate: -1, _id: -1 })
    .limit(pageLimit + 1)
    .populate('fromUserId', 'name displayTitle role avatarUrl')
    .populate('toUserId', 'name displayTitle role avatarUrl')
    .lean();

  const hasMore = handoffs.length > pageLimit;
  if (hasMore) handoffs.pop();

  return respond.ok(res, 'Space handoffs fetched', { handoffs, hasMore });
});

module.exports = {
  createHandoff, getMyHandoffs, getHandoffById, updateHandoff,
  submitHandoff, acknowledgeHandoff, addHandoffNote, reassignHandoff,
  deleteHandoff, getSpaceHandoffs,
};
