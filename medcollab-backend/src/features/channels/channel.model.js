/**
 * CHANNEL MODEL
 *
 * A Channel is a conversation stream inside a Space.
 * Every Space gets default channels on creation (seeded by a service).
 *
 * Default channels for every new Space:
 *  #general    — open discussion
 *  #emergency  — high-priority alerts (different notification behaviour)
 *  #academics  — case discussions, journal clubs
 *
 * Design decisions:
 *
 * 1. lastMessage embedded
 *    The channel list screen (like WhatsApp's home screen) shows the last
 *    message preview for each channel. Without embedding, we'd need N+1
 *    queries to build this list. Embedding the last message gives us the
 *    preview in one query.
 *    Trade-off: slight duplication of data. Worth it at our scale.
 *
 * 2. unreadCount NOT stored on Channel
 *    Unread count is per-user, per-channel. We'd need a separate
 *    UserChannelState collection to store this cleanly.
 *    For MVP: calculate unread by comparing message timestamps to
 *    user's lastSeenAt for that channel. Add the dedicated collection later.
 *
 * 3. DM channels live in this collection
 *    type: 'direct' — exactly 2 members in the members array.
 *    No spaceId needed for DMs (set to null).
 *    This means one query type handles both group channels and DMs.
 *
 * 4. Emergency channel has enforced notification behaviour
 *    type: 'emergency' is not just cosmetic. The notification service
 *    checks channel type and sends a high-priority FCM message with
 *    a different sound and a full-screen intent on Android.
 */

const mongoose = require('mongoose');
const { CHANNEL_TYPES } = require('../../constants');

const channelSchema = new mongoose.Schema(
  {
    // null for DM channels
    spaceId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Space',
      default: null,
      index: true,
    },

    name: {
      type: String,
      trim: true,
      maxlength: [80, 'Channel name cannot exceed 80 characters'],
      // e.g. "general", "emergency", "cardiology-rounds"
      // Convention: lowercase, hyphen-separated (like Slack)
    },

    description: {
      type: String,
      trim: true,
      maxlength: [200, 'Description cannot exceed 200 characters'],
      default: '',
    },

    type: {
      type: String,
      enum: Object.values(CHANNEL_TYPES),
      default: CHANNEL_TYPES.GENERAL,
    },

    // ── Access Control ────────────────────────────────────────────────────
    // Private channels require explicit invitation (like Slack private channels)
    isPrivate: {
      type: Boolean,
      default: false,
    },

    // For DMs and private channels — explicit member list
    // For public channels — all space members have access
    members: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    ],

    // ── Last Message Preview ──────────────────────────────────────────────
    // Embedded for channel list screen performance
    lastMessage: {
      messageId: { type: mongoose.Schema.Types.ObjectId, ref: 'Message' },
      text: { type: String, maxlength: 200 }, // truncated preview
      senderName: { type: String },
      type: { type: String },               // text, image, document
      sentAt: { type: Date },
    },

    // ── Pinned Messages ───────────────────────────────────────────────────
    // Max 5 pinned messages per channel (like Telegram)
    pinnedMessages: [
      {
        messageId: { type: mongoose.Schema.Types.ObjectId, ref: 'Message' },
        pinnedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        pinnedAt: { type: Date, default: Date.now },
      },
    ],

    // ── Channel Settings ──────────────────────────────────────────────────
    // For announcements channel: only admins can post
    onlyAdminsCanPost: {
      type: Boolean,
      default: false,
    },

    // ── Ordering ─────────────────────────────────────────────────────────
    // Lower position = higher in the list
    // Default channels (general, emergency) get position 0, 1, 2
    position: {
      type: Number,
      default: 99,
    },

    // ── Lifecycle ─────────────────────────────────────────────────────────
    isArchived: {
      type: Boolean,
      default: false,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// ── Indexes ───────────────────────────────────────────────────────────────────
channelSchema.index({ spaceId: 1, type: 1 });
channelSchema.index({ spaceId: 1, isArchived: 1, position: 1 });
// For DM lookup: find the DM channel between two specific users
channelSchema.index({ type: 1, members: 1 });

// ── Statics ───────────────────────────────────────────────────────────────────

/**
 * Find existing DM channel between two users, or return null
 */
channelSchema.statics.findDMChannel = async function (userId1, userId2) {
  return this.findOne({
    type: CHANNEL_TYPES.DIRECT,
    members: { $all: [userId1, userId2], $size: 2 },
  });
};

const Channel = mongoose.model('Channel', channelSchema);
module.exports = Channel;
