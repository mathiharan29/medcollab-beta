/**
 * NOTIFICATION SERVICE
 *
 * The single place where all notifications are created and delivered.
 * Every feature that needs to notify a user imports this service.
 *
 * Two-layer delivery:
 * Layer 1 — In-app (Socket.io):  Instant, if the user is connected
 * Layer 2 — Push (FCM):          Delivered even when app is closed/background
 * Layer 3 — Inbox (MongoDB):     Persisted, visible in notification bell
 *
 * Flow for every notification:
 * 1. Create Notification document in MongoDB (inbox record)
 * 2. Emit socket event to user's personal room (if online)
 * 3. Send FCM push to all their registered device tokens (if they have any)
 *
 * FCM priority:
 * - NORMAL messages: FCM "normal" priority → batched delivery, saves battery
 * - URGENT/EMERGENCY: FCM "high" priority → immediate delivery, wakes screen
 *
 * Emergency channel messages always use high priority FCM.
 */

const Notification = require('../features/notifications/notification.model');
const User = require('../features/users/user.model');
const { emitNotification } = require('../socket');
const { NOTIFICATION_TYPES, MESSAGE_PRIORITY } = require('../constants');
const logger = require('../utils/logger');

/**
 * Send a notification to a single user
 *
 * @param {Object} options
 * @param {string}   options.userId        - Recipient user ID
 * @param {string}   options.type          - NOTIFICATION_TYPES constant
 * @param {string}   options.title         - Push notification title
 * @param {string}   options.body          - Notification body text
 * @param {string}   options.referenceId   - ID of the related document (message, handoff, etc.)
 * @param {string}   options.referenceType - 'Message' | 'Handoff' | 'Space' | 'Channel'
 * @param {Object}   options.metadata      - Deep-link data { spaceId, channelId, messageId, handoffId }
 * @param {Object}   options.actor         - The user who triggered this (sender)
 * @param {string}   options.priority      - MESSAGE_PRIORITY constant (default: 'normal')
 */
const sendNotification = async ({
  userId,
  type,
  title,
  body,
  referenceId,
  referenceType,
  metadata = {},
  actor = null,
  priority = MESSAGE_PRIORITY.NORMAL,
}) => {
  try {
    // 1. Create persistent inbox record
    const notification = await Notification.create({
      userId,
      type,
      title,
      body,
      referenceId,
      referenceType,
      metadata,
      actorId: actor?._id || null,
      actorName: actor?.name || null,
      actorAvatarUrl: actor?.avatarUrl || null,
      priority,
    });

    // 2. Emit via socket (instant, if user is connected)
    try {
      emitNotification(userId, notification.toObject());
    } catch (socketErr) {
      // Socket might not be initialised yet in tests — non-fatal
      logger.debug(`Socket emit skipped: ${socketErr.message}`);
    }

    // 3. Send FCM push notification
    const recipient = await User.findById(userId).select('fcmTokens notifications');

    if (recipient?.fcmTokens?.length > 0) {
      // Check user's notification preferences before sending
      const prefs = recipient.notifications || {};
      const shouldSend = shouldSendPush(type, prefs);

      if (shouldSend) {
        await sendFCMPush({
          tokens: recipient.fcmTokens,
          title,
          body,
          data: {
            type,
            notificationId: notification._id.toString(),
            ...flattenMetadata(metadata),
          },
          priority,
        });
      }
    }

    return notification;
  } catch (err) {
    // Notification failure should NEVER crash the main operation
    // (e.g. sending a message should succeed even if notification fails)
    logger.error(`Notification failed for user ${userId}: ${err.message}`);
    return null;
  }
};

/**
 * Send notifications to multiple users at once
 * Used for channel messages where multiple members need to be notified
 *
 * @param {string[]} userIds  - Array of recipient user IDs
 * @param {Object}   options  - Same as sendNotification but without userId
 */
const sendBulkNotification = async (userIds, options) => {
  if (!userIds?.length) return;

  // Fire all notifications concurrently — don't await each one serially
  const promises = userIds.map((userId) =>
    sendNotification({ ...options, userId })
  );

  // allSettled — don't let one failure cancel the others
  const results = await Promise.allSettled(promises);

  const failed = results.filter((r) => r.status === 'rejected');
  if (failed.length > 0) {
    logger.warn(`${failed.length}/${userIds.length} bulk notifications failed`);
  }
};

/**
 * Send an FCM push notification to a list of device tokens
 * Uses FCM v1 HTTP API via Firebase Admin SDK
 */
const sendFCMPush = async ({ tokens, title, body, data = {}, priority }) => {
  let admin;
  try {
    const { getFirebaseAdmin } = require('../config/firebase');
    admin = getFirebaseAdmin();
  } catch {
    logger.debug('Firebase not initialised — skipping FCM push');
    return;
  }

  const fcmPriority = priority === MESSAGE_PRIORITY.EMERGENCY ||
    priority === MESSAGE_PRIORITY.URGENT ? 'high' : 'normal';

  // Convert all data values to strings (FCM requirement)
  const stringData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v ?? '')])
  );

  // Send to each token — collect invalid tokens to remove
  const invalidTokens = [];

  await Promise.allSettled(
    tokens.map(async (token) => {
      try {
        await admin.messaging().send({
          token,
          notification: { title, body },
          data: stringData,
          android: {
            priority: fcmPriority,
            notification: {
              // Emergency gets a distinct sound and vibration pattern
              sound: priority === MESSAGE_PRIORITY.EMERGENCY ? 'emergency_alert' : 'default',
              channelId: priority === MESSAGE_PRIORITY.EMERGENCY
                ? 'emergency'
                : 'messages',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: priority === MESSAGE_PRIORITY.EMERGENCY
                  ? 'emergency_alert.wav'
                  : 'default',
                badge: 1,
                // Critical alerts bypass Do Not Disturb on iOS
                // Requires special Apple entitlement — plan for later
              },
            },
            headers: {
              'apns-priority': fcmPriority === 'high' ? '10' : '5',
            },
          },
        });
      } catch (err) {
        // Invalid tokens (uninstalled app, etc.) should be cleaned up
        if (
          err.code === 'messaging/invalid-registration-token' ||
          err.code === 'messaging/registration-token-not-registered'
        ) {
          invalidTokens.push(token);
        } else {
          logger.warn(`FCM send failed for token: ${err.message}`);
        }
      }
    })
  );

  // Clean up stale tokens asynchronously
  if (invalidTokens.length > 0) {
    User.updateMany(
      { fcmTokens: { $in: invalidTokens } },
      { $pull: { fcmTokens: { $in: invalidTokens } } }
    ).exec();
    logger.info(`Removed ${invalidTokens.length} stale FCM tokens`);
  }
};

/**
 * Check user's notification preferences to decide if we should send a push
 */
const shouldSendPush = (notificationType, prefs) => {
  const typeMap = {
    [NOTIFICATION_TYPES.EMERGENCY_ALERT]: 'emergencyAlerts',
    [NOTIFICATION_TYPES.MENTION]: 'mentions',
    [NOTIFICATION_TYPES.NEW_MESSAGE]: 'newMessages',
    [NOTIFICATION_TYPES.THREAD_REPLY]: 'newMessages',
    [NOTIFICATION_TYPES.HANDOFF_RECEIVED]: 'handoffs',
    [NOTIFICATION_TYPES.HANDOFF_ACKNOWLEDGED]: 'handoffs',
  };

  const prefKey = typeMap[notificationType];
  if (!prefKey) return true; // Unknown types always send

  return prefs[prefKey] !== false; // Default to true if preference not set
};

/**
 * Flatten metadata object to top-level strings for FCM data payload
 */
const flattenMetadata = (metadata) => {
  const flat = {};
  Object.entries(metadata).forEach(([key, val]) => {
    if (val != null) flat[key] = val.toString();
  });
  return flat;
};

// ── Convenience helpers for common notification types ─────────────────────────

const notifyNewMessage = async ({ recipientIds, message, sender, channel }) => {
  const isEmergency = message.priority === MESSAGE_PRIORITY.EMERGENCY;

  await sendBulkNotification(
    recipientIds.filter((id) => id.toString() !== sender._id.toString()),
    {
      type: isEmergency
        ? NOTIFICATION_TYPES.EMERGENCY_ALERT
        : NOTIFICATION_TYPES.NEW_MESSAGE,
      title: isEmergency ? '🚨 Emergency Alert' : sender.name || 'New message',
      body: message.content?.text
        ? message.content.text.slice(0, 100)
        : `Sent ${message.type === 'image' ? 'an image' : 'a file'}`,
      referenceId: message._id,
      referenceType: 'Message',
      metadata: {
        spaceId: channel.spaceId,
        channelId: channel._id,
        messageId: message._id,
      },
      actor: sender,
      priority: message.priority,
    }
  );
};

const notifyMention = async ({ mentionedUserIds, message, sender, channel }) => {
  await sendBulkNotification(mentionedUserIds, {
    type: NOTIFICATION_TYPES.MENTION,
    title: `${sender.name} mentioned you`,
    body: message.content?.text?.slice(0, 100) || 'Mentioned you in a message',
    referenceId: message._id,
    referenceType: 'Message',
    metadata: {
      spaceId: channel.spaceId,
      channelId: channel._id,
      messageId: message._id,
    },
    actor: sender,
    priority: MESSAGE_PRIORITY.URGENT,
  });
};

const notifyHandoffReceived = async ({ toUser, fromUser, handoff }) => {
  await sendNotification({
    userId: toUser._id,
    type: NOTIFICATION_TYPES.HANDOFF_RECEIVED,
    title: 'New handoff received',
    body: `${fromUser.name} sent you a ${handoff.shiftType} shift handoff`,
    referenceId: handoff._id,
    referenceType: 'Handoff',
    metadata: {
      spaceId: handoff.spaceId,
      handoffId: handoff._id,
    },
    actor: fromUser,
    priority: MESSAGE_PRIORITY.URGENT,
  });
};

const notifyHandoffAcknowledged = async ({ fromUser, toUser, handoff }) => {
  await sendNotification({
    userId: fromUser._id,
    type: NOTIFICATION_TYPES.HANDOFF_ACKNOWLEDGED,
    title: 'Handoff acknowledged',
    body: `${toUser.name} acknowledged your ${handoff.shiftType} shift handoff`,
    referenceId: handoff._id,
    referenceType: 'Handoff',
    metadata: {
      spaceId: handoff.spaceId,
      handoffId: handoff._id,
    },
    actor: toUser,
    priority: MESSAGE_PRIORITY.NORMAL,
  });
};

module.exports = {
  sendNotification,
  sendBulkNotification,
  notifyNewMessage,
  notifyMention,
  notifyHandoffReceived,
  notifyHandoffAcknowledged,
};
