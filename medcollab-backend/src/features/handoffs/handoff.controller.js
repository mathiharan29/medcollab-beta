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
const { emitNewMessage } = require('../../socket');
const {
  notifyHandoffReceived,
  notifyHandoffAcknowledged,
} = require('../../services/notification.service');
const { HANDOFF_STATUS, MESSAGE_TYPES } = require('../../constants');
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
    const visibleToReceiver = [
      HANDOFF_STATUS.SUBMITTED,
      HANDOFF_STATUS.ACKNOWLEDGED,
    ];
    if (status && visibleToReceiver.includes(status)) {
      query.status = status;
    } else if (!status) {
      query.status = { $in: visibleToReceiver };
    } else {
      query.status = status;
    }
  } else {
    // 'all' — both sent (any status) and received (non-draft)
    query.$or = [
      { fromUserId: req.user._id },
      { toUserId: req.user._id, status: { $in: [HANDOFF_STATUS.SUBMITTED, HANDOFF_STATUS.ACKNOWLEDGED] } },
    ];
  }

  const handoffs = await Handoff.find(query)
    .sort({ shiftDate: -1, createdAt: -1 })
    .populate('fromUserId', 'name displayTitle role avatarUrl')
    .populate('toUserId', 'name displayTitle role avatarUrl')
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
    .lean();

  if (!handoff) return respond.notFound(res, 'Handoff not found');

  const userId = req.user._id.toString();
  const isParticipant =
    handoff.fromUserId._id.toString() === userId ||
    handoff.toUserId._id.toString() === userId;

  // Space admins can also view for audit purposes
  const space = await Space.findById(handoff.spaceId);
  const isAdmin = space?.isAdmin(req.user._id);

  if (!isParticipant && !isAdmin) {
    return respond.forbidden(res, 'Access denied');
  }

  return respond.ok(res, 'Handoff fetched', { handoff });
});

/**
 * PUT /api/handoffs/:id
 * Update a DRAFT handoff (sender only)
 */
const updateHandoff = asyncHandler(async (req, res) => {
  const handoff = await Handoff.findById(req.params.id);
  if (!handoff) return respond.notFound(res, 'Handoff not found');
  if (handoff.fromUserId.toString() !== req.user._id.toString()) {
    return respond.forbidden(res, 'Only the sender can edit a handoff');
  }
  if (handoff.status !== HANDOFF_STATUS.DRAFT) {
    return respond.badRequest(res, 'Cannot edit a submitted handoff');
  }

  const allowed = ['patients', 'shiftSummary', 'shiftDate', 'shiftType'];
  allowed.forEach((f) => {
    if (req.body[f] !== undefined) handoff[f] = req.body[f];
  });

  await handoff.save();
  return respond.ok(res, 'Handoff updated', { handoff });
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

  const [fromUser, toUser] = await Promise.all([
    User.findById(handoff.fromUserId).select('name avatarUrl'),
    User.findById(handoff.toUserId).select('name avatarUrl fcmTokens'),
  ]);

  respond.ok(res, 'Handoff submitted', { handoff });

  // Post-response async side-effects
  setImmediate(async () => {
    try {
      const channel = await Channel.findById(handoff.channelId);
      if (channel) {
        await postHandoffSystemMessage({ channel, handoff, fromUser, toUser, action: 'submitted' });
      }
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

  setImmediate(async () => {
    try {
      const channel = await Channel.findById(handoff.channelId);
      if (channel) {
        await postHandoffSystemMessage({ channel, handoff, fromUser, toUser, action: 'acknowledged' });
      }
      await notifyHandoffAcknowledged({ fromUser, toUser, handoff });
    } catch (err) {
      logger.error(`Handoff acknowledge side-effects failed: ${err.message}`);
    }
  });
});

/**
 * DELETE /api/handoffs/:id
 * Delete a DRAFT handoff (cannot delete submitted/acknowledged)
 */
const deleteHandoff = asyncHandler(async (req, res) => {
  const handoff = await Handoff.findById(req.params.id);
  if (!handoff) return respond.notFound(res, 'Handoff not found');
  if (handoff.fromUserId.toString() !== req.user._id.toString()) {
    return respond.forbidden(res, 'Only the sender can delete');
  }
  if (handoff.status !== HANDOFF_STATUS.DRAFT) {
    return respond.badRequest(res, 'Cannot delete a submitted handoff — medical audit trail');
  }

  await handoff.deleteOne();
  return respond.ok(res, 'Draft handoff deleted');
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
    // Non-admins can only see submitted/acknowledged handoffs (not other people's drafts)
    status: space.isAdmin(req.user._id)
      ? status || { $exists: true }
      : { $in: [HANDOFF_STATUS.SUBMITTED, HANDOFF_STATUS.ACKNOWLEDGED] },
  };

  if (date) {
    const day = new Date(date);
    const next = new Date(day);
    next.setDate(next.getDate() + 1);
    query.shiftDate = { $gte: day, $lt: next };
  }
  if (shiftType) query.shiftType = shiftType;
  if (fromUserId) query.fromUserId = fromUserId;
  if (before) query._id = { $lt: before };

  const handoffs = await Handoff.find(query)
    .sort({ shiftDate: -1, _id: -1 })
    .limit(Math.min(parseInt(limit), 50) + 1)
    .populate('fromUserId', 'name displayTitle role avatarUrl')
    .populate('toUserId', 'name displayTitle role avatarUrl')
    .lean();

  const hasMore = handoffs.length > parseInt(limit);
  if (hasMore) handoffs.pop();

  return respond.ok(res, 'Space handoffs fetched', { handoffs, hasMore });
});

module.exports = {
  createHandoff, getMyHandoffs, getHandoffById, updateHandoff,
  submitHandoff, acknowledgeHandoff, deleteHandoff, getSpaceHandoffs,
};
