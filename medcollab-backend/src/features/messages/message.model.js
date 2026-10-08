/**
 * MESSAGE MODEL
 *
 * This will be the largest and most-queried collection in the database.
 * Every design decision here has performance implications.
 *
 * Design decisions:
 *
 * 1. Flat thread model (not nested/recursive)
 *    Messages have a `threadId` pointing to the ROOT message of a thread.
 *    We do NOT nest replies inside the parent document (that would make
 *    documents grow unboundedly).
 *    To fetch a thread: query { threadId: rootMessageId }
 *    This is exactly how Slack and Discord implement threads.
 *
 * 2. Cursor-based pagination (not offset/page-based)
 *    Clients fetch messages like:
 *      GET /channels/:id/messages?before=<messageId>&limit=30
 *    This is stable even when new messages arrive.
 *    Page-based pagination shifts when new items are inserted.
 *
 * 3. readBy array is intentionally omitted for group channels
 *    Storing readBy: [{ userId, readAt }] on every message in a
 *    busy channel creates massive write amplification.
 *    (100 users × 500 messages = 50,000 read-receipt writes per session)
 *    For MVP: show read receipts only in DMs (2 participants).
 *    Use a separate UserChannelRead collection for group read tracking later.
 *
 * 4. Soft delete
 *    Medical context: we never hard-delete messages.
 *    deletedAt is set, content is replaced with a placeholder,
 *    but the document remains for audit purposes.
 *
 * 5. content is a single embedded object (not separate fields)
 *    A message has ONE type of content. Embedding avoids optional
 *    top-level fields (textContent, imageUrl, documentUrl) all on the
 *    same schema. Cleaner and easier to extend.
 *
 * 6. reactions stored as array of { emoji, userIds[] }
 *    Not as a Map, not as individual documents.
 *    For a 15-doctor beta, a message will have <10 reactions max.
 *    Array is perfectly efficient here.
 */

const mongoose = require('mongoose');
const { MESSAGE_TYPES, MESSAGE_PRIORITY } = require('../../constants');

// ── Content Subdocument ───────────────────────────────────────────────────────
// One message has one content block
const contentSchema = new mongoose.Schema(
  {
    // For type: text, alert, handoff
    text: {
      type: String,
      maxlength: [4000, 'Message cannot exceed 4000 characters'],
      default: null,
    },

    // For type: image, document, ecg
    mediaUrl: { type: String, default: null },       // Full Cloudinary URL
    thumbnailUrl: { type: String, default: null },   // Auto-generated thumbnail
    fileName: { type: String, default: null },       // Original filename
    fileSize: { type: Number, default: null },       // Bytes
    mimeType: { type: String, default: null },       // 'image/jpeg', 'application/pdf'
    width: { type: Number, default: null },          // Image dimensions (for layout)
    height: { type: Number, default: null },

    // For type: handoff — reference to the Handoff document
    handoffId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Handoff',
      default: null,
    },
  },
  { _id: false }
);

// ── Reaction Subdocument ──────────────────────────────────────────────────────
const reactionSchema = new mongoose.Schema(
  {
    emoji: { type: String, required: true },  // '👍', '❤️', '⚠️'
    userIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  },
  { _id: false }
);

// ── Message Schema ────────────────────────────────────────────────────────────
const messageSchema = new mongoose.Schema(
  {
    channelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Channel',
      required: true,
      index: true,
    },

    spaceId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Space',
      default: null,
      // Denormalised from channel for faster space-wide search
    },

    senderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },

    type: {
      type: String,
      enum: Object.values(MESSAGE_TYPES),
      default: MESSAGE_TYPES.TEXT,
    },

    content: {
      type: contentSchema,
      required: true,
    },

    // ── WhatsApp-style quote reply (same channel timeline) ─────────────────
    // Snapshot taken at send time so soft-deleted parents still show a preview.
    replyTo: {
      messageId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Message',
        default: null,
      },
      senderId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null,
      },
      senderName: { type: String, default: null },
      text: { type: String, maxlength: 120, default: null },
      type: { type: String, default: null },
    },

    // ── Threading (Slack-style side discussion) ────────────────────────────
    // null = this IS a root message (not a thread reply)
    // ObjectId = this is a reply in the thread started by that root message
    threadId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Message',
      default: null,
      index: true,
    },

    // Stored on the ROOT message only — count of all replies in its thread
    replyCount: {
      type: Number,
      default: 0,
    },

    // Snapshot of the last reply (for thread preview in channel view)
    lastReply: {
      senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      senderName: { type: String },
      text: { type: String, maxlength: 100 },
      sentAt: { type: Date },
    },

    // ── Engagement ────────────────────────────────────────────────────────
    reactions: {
      type: [reactionSchema],
      default: [],
    },

    // User IDs mentioned in this message (extracted from @mentions in text)
    mentions: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    ],

    // ── Priority ──────────────────────────────────────────────────────────
    // Controls notification sound and visual treatment on client
    priority: {
      type: String,
      enum: Object.values(MESSAGE_PRIORITY),
      default: MESSAGE_PRIORITY.NORMAL,
    },

    // ── Read Receipts (DMs only) ──────────────────────────────────────────
    // Only populated for DIRECT channel messages (2 participants)
    readBy: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        readAt: { type: Date, default: Date.now },
        _id: false,
      },
    ],

    // ── Editing ───────────────────────────────────────────────────────────
    isEdited: {
      type: Boolean,
      default: false,
    },

    editedAt: {
      type: Date,
      default: null,
    },

    // ── Soft Delete ───────────────────────────────────────────────────────
    // Never hard delete. Set deletedAt and blank the content.
    deletedAt: {
      type: Date,
      default: null,
    },

    isDeleted: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true, // createdAt is our message timestamp
  }
);

// ── Indexes ───────────────────────────────────────────────────────────────────
// Primary query: fetch messages in a channel, newest first, cursor-based
messageSchema.index({ channelId: 1, createdAt: -1 });

// Thread query: fetch all replies to a root message
messageSchema.index({ threadId: 1, createdAt: 1 });

// Space-wide search (future feature)
messageSchema.index({ spaceId: 1, createdAt: -1 });

// Mention-based notification lookup
messageSchema.index({ mentions: 1 });

// ── Pre-save Hook ─────────────────────────────────────────────────────────────
// When a message is soft-deleted, blank out its content.
// Mongoose 9+: use async middleware (no `next` callback).
messageSchema.pre('save', async function () {
  if (this.isModified('isDeleted') && this.isDeleted) {
    this.deletedAt = new Date();
    this.content = {
      text: 'This message was deleted',
      mediaUrl: null,
      thumbnailUrl: null,
      fileName: null,
      fileSize: null,
      mimeType: null,
    };
    this.reactions = [];
  }
});

// ── Instance Methods ──────────────────────────────────────────────────────────

/**
 * Toggle one emoji for a user. Multiple emojis per user are allowed.
 * Same emoji again removes only that emoji; other reactions stay.
 */
messageSchema.methods.toggleReaction = function (emoji, userId) {
  const uid = userId.toString();
  const group = this.reactions.find((r) => r.emoji === emoji);

  if (group) {
    const already = group.userIds.some((id) => id.toString() === uid);
    if (already) {
      group.userIds = group.userIds.filter((id) => id.toString() !== uid);
      if (group.userIds.length === 0) {
        this.reactions = this.reactions.filter((r) => r.emoji !== emoji);
      }
    } else {
      group.userIds.push(userId);
    }
  } else {
    this.reactions.push({ emoji, userIds: [userId] });
  }

  return this.save();
};

const Message = mongoose.model('Message', messageSchema);
module.exports = Message;
