/**
 * NOTIFICATION MODEL
 *
 * Two notification layers exist in this system:
 *
 * Layer 1 — FCM Push (Firebase Cloud Messaging)
 *   Delivered to the phone OS even when the app is closed.
 *   Handled by the notification service. NOT stored here.
 *
 * Layer 2 — In-app Notification Inbox (this model)
 *   Stored in MongoDB. Shown inside the app as a notification list.
 *   Like the notification bell in Slack or LinkedIn.
 *
 * Why both?
 * FCM notifications are ephemeral — if a doctor dismisses the push,
 * the information is gone. The in-app inbox persists so they can
 * review all notifications from the past 30 days.
 *
 * Design decisions:
 *
 * 1. TTL index — auto-delete after 30 days
 *    Notifications older than 30 days are irrelevant and waste storage.
 *    MongoDB's TTL index handles cleanup automatically.
 *
 * 2. referenceId + referenceType (polymorphic reference)
 *    A notification can point to a Message, Handoff, or Space.
 *    We use a pattern similar to "generic foreign key" in Django.
 *    referenceType tells the client what screen to navigate to.
 *
 * 3. Batch-read support
 *    "Mark all as read" is a single update query on { userId, read: false }.
 *    No N+1 problem.
 */

const mongoose = require('mongoose');
const { NOTIFICATION_TYPES, MESSAGE_PRIORITY } = require('../../constants');

const notificationSchema = new mongoose.Schema(
  {
    // Who receives this notification
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    type: {
      type: String,
      enum: Object.values(NOTIFICATION_TYPES),
      required: true,
    },

    // Human-readable notification body
    // e.g. "Dr. Priya mentioned you in #emergency"
    body: {
      type: String,
      required: true,
      maxlength: 300,
    },

    // Short title for the push notification
    // e.g. "New mention"
    title: {
      type: String,
      maxlength: 100,
    },

    // ── Polymorphic Reference ──────────────────────────────────────────────
    // What this notification is about
    referenceId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      // Can reference a Message, Handoff, Space, etc.
    },

    referenceType: {
      type: String,
      required: true,
      enum: ['Message', 'Handoff', 'Space', 'Channel'],
    },

    // Deep link data for client-side navigation
    // When tapped, Flutter uses this to navigate to the right screen
    metadata: {
      spaceId: { type: mongoose.Schema.Types.ObjectId },
      channelId: { type: mongoose.Schema.Types.ObjectId },
      messageId: { type: mongoose.Schema.Types.ObjectId },
      handoffId: { type: mongoose.Schema.Types.ObjectId },
    },

    // Who triggered this notification (the sender, not the receiver)
    actorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },

    // Actor name embedded — avoids a join just to show "Dr. Priya sent you a handoff"
    actorName: {
      type: String,
      maxlength: 100,
    },

    actorAvatarUrl: {
      type: String,
      default: null,
    },

    // ── State ──────────────────────────────────────────────────────────────
    read: {
      type: Boolean,
      default: false,
      index: true,
    },

    readAt: {
      type: Date,
      default: null,
    },

    // Priority mirrors message priority for emergency alerts
    priority: {
      type: String,
      enum: Object.values(MESSAGE_PRIORITY),
      default: MESSAGE_PRIORITY.NORMAL,
    },

    // ── TTL ───────────────────────────────────────────────────────────────
    // Document auto-deleted 30 days after creation
    expiresAt: {
      type: Date,
      default: () => new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  },
  {
    timestamps: true,
  }
);

// ── Indexes ───────────────────────────────────────────────────────────────────
// TTL index — MongoDB deletes documents after expiresAt
notificationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

// Primary read pattern: get all unread notifications for a user
notificationSchema.index({ userId: 1, read: 1, createdAt: -1 });

// ── Instance Methods ──────────────────────────────────────────────────────────

notificationSchema.methods.markRead = function () {
  this.read = true;
  this.readAt = new Date();
  return this.save();
};

// ── Static Methods ────────────────────────────────────────────────────────────

/**
 * Mark all notifications as read for a user
 */
notificationSchema.statics.markAllRead = function (userId) {
  return this.updateMany(
    { userId, read: false },
    { $set: { read: true, readAt: new Date() } }
  );
};

/**
 * Get unread count for a user (shown as badge on notification bell)
 */
notificationSchema.statics.getUnreadCount = function (userId) {
  return this.countDocuments({ userId, read: false });
};

const Notification = mongoose.model('Notification', notificationSchema);
module.exports = Notification;
