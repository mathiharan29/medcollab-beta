/**
 * Beta / debug-only developer tools.
 * Enabled when NODE_ENV !== 'production' OR ENABLE_DEV_TOOLS=true.
 */

const express = require('express');
const { protect } = require('../../middleware/auth');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const Notification = require('../notifications/notification.model');
const Handoff = require('../handoffs/handoff.model');
const Space = require('../spaces/space.model');
const Channel = require('../channels/channel.model');
const Message = require('../messages/message.model');
const {
  NOTIFICATION_TYPES,
  MESSAGE_PRIORITY,
  CHANNEL_TYPES,
  HANDOFF_STATUS,
  SHIFT_TYPES,
  PATIENT_STATUS,
  MESSAGE_TYPES,
} = require('../../constants');
const { emitNotification } = require('../../socket');

const router = express.Router();

function devToolsEnabled() {
  return (
    process.env.NODE_ENV !== 'production' ||
    process.env.ENABLE_DEV_TOOLS === 'true'
  );
}

router.use((req, res, next) => {
  if (!devToolsEnabled()) {
    return respond.forbidden(res, 'Developer tools are disabled');
  }
  return next();
});

router.use(protect);

/**
 * POST /api/dev/seed-notifications
 */
router.post(
  '/seed-notifications',
  asyncHandler(async (req, res) => {
    const samples = [
      {
        type: NOTIFICATION_TYPES.NEW_MESSAGE,
        title: 'Beta sample message',
        body: 'This is a seeded notification for Vocle beta testing.',
        priority: MESSAGE_PRIORITY.NORMAL,
      },
      {
        type: NOTIFICATION_TYPES.MENTION,
        title: 'Someone mentioned you',
        body: 'Seeded @mention — safe to dismiss.',
        priority: MESSAGE_PRIORITY.URGENT,
      },
      {
        type: NOTIFICATION_TYPES.HANDOFF_RECEIVED,
        title: 'Sample handoff',
        body: 'Seeded handoff alert for UI testing.',
        priority: MESSAGE_PRIORITY.URGENT,
      },
    ];

    const created = [];
    const mongoose = require('mongoose');
    for (const sample of samples) {
      // Schema requires referenceId + referenceType; use disposable ObjectIds.
      const notification = await Notification.create({
        userId: req.user._id,
        type: sample.type,
        title: sample.title,
        body: sample.body,
        priority: sample.priority,
        actorName: 'Vocle Beta',
        referenceId: new mongoose.Types.ObjectId(),
        referenceType:
          sample.type === NOTIFICATION_TYPES.HANDOFF_RECEIVED
            ? 'Handoff'
            : 'Message',
      });
      created.push(notification);
      try {
        emitNotification(req.user._id, notification.toObject());
      } catch (_) {
        /* non-fatal */
      }
    }

    return respond.ok(res, 'Seeded notifications', {
      count: created.length,
    });
  })
);

/**
 * POST /api/dev/seed-conversation
 */
router.post(
  '/seed-conversation',
  asyncHandler(async (req, res) => {
    let channel = await Channel.findOne({
      type: CHANNEL_TYPES.DIRECT,
      members: req.user._id,
      isArchived: false,
    });

    if (!channel) {
      const space = await Space.findOne({
        'members.userId': req.user._id,
        isActive: true,
      });
      if (!space) {
        return respond.badRequest(
          res,
          'Join or create a group first, then seed again'
        );
      }
      channel = await Channel.findOne({
        spaceId: space._id,
        name: 'general',
        isArchived: false,
      });
      if (!channel) {
        return respond.badRequest(res, 'No #general channel found to seed');
      }
    }

    const message = await Message.create({
      channelId: channel._id,
      spaceId: channel.spaceId || null,
      senderId: req.user._id,
      type: MESSAGE_TYPES.TEXT,
      content: {
        text: 'Vocle beta seed message — safe to delete.',
      },
      priority: MESSAGE_PRIORITY.NORMAL,
    });

    return respond.ok(res, 'Seeded conversation message', {
      channelId: channel._id,
      messageId: message._id,
    });
  })
);

/**
 * POST /api/dev/seed-handoff
 */
router.post(
  '/seed-handoff',
  asyncHandler(async (req, res) => {
    const space = await Space.findOne({
      'members.userId': req.user._id,
      isActive: true,
    });
    if (!space) {
      return respond.badRequest(res, 'Join a group before seeding a handoff');
    }

    const channel = await Channel.findOne({
      spaceId: space._id,
      name: 'general',
      isArchived: false,
    });
    if (!channel) {
      return respond.badRequest(res, 'No #general channel found for handoff');
    }

    const handoff = await Handoff.create({
      spaceId: space._id,
      channelId: channel._id,
      fromUserId: req.user._id,
      toUserId: req.user._id,
      shiftType: SHIFT_TYPES.MORNING,
      shiftDate: new Date(),
      status: HANDOFF_STATUS.DRAFT,
      patients: [
        {
          bedNumber: '12',
          ward: 'Demo',
          clinicalAlias: 'Demo patient (beta)',
          diagnosis: 'Seeded demo — delete after testing',
          status: PATIENT_STATUS.STABLE,
          pendingTasks: ['Review labs', 'Update family'],
        },
      ],
      shiftSummary: 'Vocle beta seed handoff',
    });

    return respond.ok(res, 'Seeded draft handoff', {
      handoffId: handoff._id,
      spaceId: space._id,
    });
  })
);

module.exports = router;
