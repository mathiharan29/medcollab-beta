/**
 * MESSAGE REQUEST CONTROLLER
 * Stranger DM discovery — request → accept → createOrGetDM
 */

const MessageRequest = require('./messageRequest.model');
const User = require('../users/user.model');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { canMessageUser, canRequestMessage } = require('../../utils/knownUsers');
const { MESSAGE_REQUEST_STATUS, NOTIFICATION_TYPES } = require('../../constants');
const { sendNotification } = require('../../services/notification.service');

const userSelect =
  'name displayTitle role speciality institution avatarUrl availability';

function publicFromUser(u) {
  if (!u) return null;
  if (typeof u.toPublicProfile === 'function') return u.toPublicProfile();
  return {
    id: u._id?.toString(),
    name: u.name,
    displayTitle: u.displayTitle,
    role: u.role,
    speciality: u.speciality,
    institution: u.institution,
    avatarUrl: u.avatarUrl,
    availability: u.availability,
  };
}

function serializeRequest(doc, viewerId) {
  const from = doc.fromUserId?._id?.toString() || doc.fromUserId?.toString();
  const to = doc.toUserId?._id?.toString() || doc.toUserId?.toString();
  const peer =
    from === viewerId.toString() ? doc.toUserId : doc.fromUserId;

  return {
    id: doc._id.toString(),
    status: doc.status,
    introMessage: doc.introMessage || '',
    direction: from === viewerId.toString() ? 'sent' : 'received',
    createdAt: doc.createdAt,
    peer: publicFromUser(peer),
  };
}

/**
 * POST /api/message-requests
 * @body { toUserId, introMessage? }
 */
const createRequest = asyncHandler(async (req, res) => {
  const { toUserId, introMessage } = req.body;
  const callerId = req.user._id;

  if (toUserId === callerId.toString()) {
    return respond.badRequest(res, 'Cannot send a request to yourself');
  }

  const target = await User.findById(toUserId).select(
    '_id name isOnboarded isActive'
  );
  if (!target || !target.isActive || !target.isOnboarded) {
    return respond.notFound(res, 'Doctor not found');
  }

  if (await canMessageUser(callerId, toUserId)) {
    return respond.badRequest(
      res,
      'You can message this doctor directly — no request needed'
    );
  }

  if (!(await canRequestMessage(callerId, toUserId))) {
    return respond.forbidden(
      res,
      'This doctor is not accepting message requests from outside their network'
    );
  }

  const blocked = await MessageRequest.findOne({
    status: MESSAGE_REQUEST_STATUS.BLOCKED,
    $or: [
      { fromUserId: callerId, toUserId },
      { fromUserId: toUserId, toUserId: callerId },
    ],
  }).select('_id');
  if (blocked) {
    return respond.forbidden(res, 'Messaging is not available with this doctor');
  }

  const existingPending = await MessageRequest.findOne({
    status: MESSAGE_REQUEST_STATUS.PENDING,
    $or: [
      { fromUserId: callerId, toUserId },
      { fromUserId: toUserId, toUserId: callerId },
    ],
  })
    .populate('fromUserId', userSelect)
    .populate('toUserId', userSelect);

  if (existingPending) {
    const incoming =
      existingPending.fromUserId._id.toString() === toUserId;
    if (incoming) {
      return respond.ok(res, 'They already sent you a request', {
        request: serializeRequest(existingPending, callerId),
        action: 'accept_incoming',
      });
    }
    return respond.ok(res, 'Request already pending', {
      request: serializeRequest(existingPending, callerId),
    });
  }

  const request = await MessageRequest.create({
    fromUserId: callerId,
    toUserId,
    introMessage: (introMessage || '').trim().slice(0, 280),
  });

  const populated = await MessageRequest.findById(request._id)
    .populate('fromUserId', userSelect)
    .populate('toUserId', userSelect);

  await sendNotification({
    userId: toUserId,
    type: NOTIFICATION_TYPES.MESSAGE_REQUEST,
    title: 'Message request',
    body: `${req.user.name} wants to message you on Vocle`,
    referenceId: request._id.toString(),
    referenceType: 'MessageRequest',
    metadata: { messageRequestId: request._id.toString(), fromUserId: callerId.toString() },
    actor: req.user,
  });

  return respond.created(res, 'Message request sent', {
    request: serializeRequest(populated, callerId),
  });
});

/**
 * GET /api/message-requests?direction=received|sent|all&status=pending
 */
const listRequests = asyncHandler(async (req, res) => {
  const direction = req.query.direction || 'received';
  const status = req.query.status || MESSAGE_REQUEST_STATUS.PENDING;
  const callerId = req.user._id;

  const filter = { status };
  if (direction === 'received') {
    filter.toUserId = callerId;
  } else if (direction === 'sent') {
    filter.fromUserId = callerId;
  } else {
    filter.$or = [{ fromUserId: callerId }, { toUserId: callerId }];
  }

  const requests = await MessageRequest.find(filter)
    .sort({ createdAt: -1 })
    .limit(50)
    .populate('fromUserId', userSelect)
    .populate('toUserId', userSelect)
    .lean();

  const serialized = requests.map((doc) => {
    const fromPop = doc.fromUserId;
    const toPop = doc.toUserId;
    return serializeRequest(
      {
        ...doc,
        fromUserId: fromPop,
        toUserId: toPop,
      },
      callerId
    );
  });

  return respond.ok(res, 'Message requests', { requests: serialized });
});

/**
 * GET /api/message-requests/pending-count
 */
const pendingCount = asyncHandler(async (req, res) => {
  const count = await MessageRequest.countDocuments({
    toUserId: req.user._id,
    status: MESSAGE_REQUEST_STATUS.PENDING,
  });
  return respond.ok(res, 'Pending count', { count });
});

/**
 * POST /api/message-requests/:id/accept
 * Accept → open DM (no chat / Seen until this step).
 */
const acceptRequest = asyncHandler(async (req, res) => {
  const Channel = require('../channels/channel.model');
  const { CHANNEL_TYPES } = require('../../constants');

  const request = await MessageRequest.findById(req.params.id)
    .populate('fromUserId', userSelect)
    .populate('toUserId', userSelect);

  if (!request) return respond.notFound(res, 'Request not found');
  if (request.toUserId._id.toString() !== req.user._id.toString()) {
    return respond.forbidden(res, 'Only the recipient can accept this request');
  }
  if (
    request.status !== MESSAGE_REQUEST_STATUS.PENDING &&
    request.status !== MESSAGE_REQUEST_STATUS.ACCEPTED
  ) {
    return respond.badRequest(res, 'This request is no longer pending');
  }

  const newlyAccepted = request.status === MESSAGE_REQUEST_STATUS.PENDING;
  if (newlyAccepted) {
    request.status = MESSAGE_REQUEST_STATUS.ACCEPTED;
    await request.save();
  }

  const fromId = request.fromUserId._id.toString();
  const toId = request.toUserId._id.toString();
  // Atomic DM upsert via memberPairKey — findAndModify is the intentional
  // failpoint edge for FR-REQ-05 (accepted request without conversation).
  const { memberPairKey } = require('../../utils/memberPairKey');
  const pairKey = memberPairKey([fromId, toId]);
  const channel = await Channel.findOneAndUpdate(
    { type: CHANNEL_TYPES.DIRECT, memberPairKey: pairKey },
    {
      $setOnInsert: {
        spaceId: null,
        type: CHANNEL_TYPES.DIRECT,
        members: [request.fromUserId._id, request.toUserId._id],
        memberPairKey: pairKey,
        createdBy: req.user._id,
        name: null,
        isArchived: false,
      },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  const populated = await Channel.findById(channel._id)
    .populate(
      'members',
      'name displayTitle role speciality avatarUrl availability lastSeenAt'
    )
    .lean();

  // Lightweight enrich (peer for current viewer) — mirrors channel.controller
  const peer = (populated.members || []).find(
    (m) => m._id.toString() !== req.user._id.toString()
  );
  const enrichedChannel = {
    ...populated,
    id: populated._id.toString(),
    peer: peer
      ? {
          _id: peer._id,
          name: peer.name,
          displayTitle: peer.displayTitle,
          role: peer.role,
          speciality: peer.speciality,
          avatarUrl: peer.avatarUrl,
          availability: peer.availability,
          lastSeenAt: peer.lastSeenAt,
        }
      : null,
  };

  if (newlyAccepted) {
    await sendNotification({
      userId: fromId,
      type: NOTIFICATION_TYPES.MESSAGE_REQUEST,
      title: 'Request accepted',
      body: `${req.user.name} accepted your message request`,
      referenceId: request._id.toString(),
      referenceType: 'MessageRequest',
      metadata: {
        messageRequestId: request._id.toString(),
        toUserId: req.user._id.toString(),
        accepted: true,
        channelId: channel._id.toString(),
      },
      actor: req.user,
    });
  }

  return respond.ok(res, 'Request accepted', {
    request: serializeRequest(request, req.user._id),
    channel: enrichedChannel,
  });
});

/**
 * POST /api/message-requests/:id/decline
 */
const declineRequest = asyncHandler(async (req, res) => {
  const request = await MessageRequest.findById(req.params.id)
    .populate('fromUserId', userSelect)
    .populate('toUserId', userSelect);

  if (!request) return respond.notFound(res, 'Request not found');
  if (request.toUserId._id.toString() !== req.user._id.toString()) {
    return respond.forbidden(res, 'Only the recipient can decline this request');
  }
  if (request.status !== MESSAGE_REQUEST_STATUS.PENDING) {
    return respond.badRequest(res, 'This request is no longer pending');
  }

  request.status = MESSAGE_REQUEST_STATUS.DECLINED;
  await request.save();

  return respond.ok(res, 'Request declined', {
    request: serializeRequest(request, req.user._id),
  });
});

module.exports = {
  createRequest,
  listRequests,
  pendingCount,
  acceptRequest,
  declineRequest,
};
