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
 * 4. Deletion (beta feedback 2026-11-10)
 *    "Delete for everyone" (sender or space admin) removes the message, its
 *    thread replies, their media and alerts from the database.
 *    "Delete for me" only adds the user to `hiddenFor`.
 *    The isDeleted/deletedAt soft-delete fields remain for legacy rows.
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

    // For type: audio (voice note, REQ 12) — length in milliseconds and a
    // small loudness profile (0–100 values) for the waveform.
    durationMs: { type: Number, default: null, min: 0 },
    waveform: {
      type: [Number],
      default: undefined,
      validate: {
        validator: (v) => !v || (v.length <= 64 && v.every((n) => n >= 0 && n <= 100)),
        message: 'Invalid waveform',
      },
    },

    // For type: system (REQ 2) — what happened and to whom.
    systemEvent: { type: String, default: null },
    // Needl Voice (issue 13): on-device transcript of an audio message,
    // written by the sender's phone after recording.
    transcript: { type: String, maxlength: 8000, default: undefined },
    transcriptStatus: {
      type: String,
      enum: ['pending', 'done', 'unavailable'],
      default: undefined,
    },
    // Sent from the voice-first Needl Voice screen (shown with a mic badge).
    voiceMode: { type: Boolean, default: undefined },
    // needl_continued: the conversation that continues with the new people.
    movedToChannelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Channel',
      default: undefined,
    },
    targetUserIds: {
      type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      default: undefined,
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

    // "Delete for me": users who hid this message from their own view.
    // ("Delete for everyone" removes the document entirely.)
    hiddenFor: {
      type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      default: [],
    },

    // Sender-chosen idempotency key (FR-AST-25): a retry or a second tap
    // with the same key returns the stored message instead of a new one.
    clientMessageId: {
      type: String,
      default: undefined,
    },

    // Forwarded copy (beta 11-26): who wrote the original and where it is.
    // Opening the source works only for people who can read that chat.
    forwarded: {
      type: new mongoose.Schema(
        {
          fromName: { type: String, maxlength: 120 },
          fromUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
          sourceChannelId: { type: mongoose.Schema.Types.ObjectId, ref: 'Channel' },
          sourceMessageId: { type: mongoose.Schema.Types.ObjectId, ref: 'Message' },
        },
        { _id: false }
      ),
      default: undefined,
    },

    // Set on history copied into an expanded Needl: the source message id.
    // Lets an interrupted copy be redone without duplicates (FR-NDL-29).
    copiedFromId: {
      type: mongoose.Schema.Types.ObjectId,
      default: undefined,
    },
  },
  {
    timestamps: true, // createdAt is our message timestamp
    // Who hid a message for themselves is private to them.
    toJSON: { transform: (_doc, ret) => { delete ret.hiddenFor; return ret; } },
    toObject: { transform: (_doc, ret) => { delete ret.hiddenFor; return ret; } },
  }
);

// ── Indexes ───────────────────────────────────────────────────────────────────
// Primary query: fetch messages in a channel, newest first, cursor-based
messageSchema.index({ channelId: 1, createdAt: -1 });

// Timeline / thread pages: filter by channel + thread, newest first by _id
// (getMessages / getThread). Without it MongoDB sorted every message of the
// chat in memory on each open (issue 2).
messageSchema.index({ channelId: 1, threadId: 1, _id: -1 });

// Thread query: fetch all replies to a root message
messageSchema.index({ threadId: 1, createdAt: 1 });

// Space-wide search (future feature)
messageSchema.index({ spaceId: 1, createdAt: -1 });

// Mention-based notification lookup
messageSchema.index({ mentions: 1 });

// One stored message per (sender, chat, client key). Partial: old messages
// have no key.
messageSchema.index(
  { senderId: 1, channelId: 1, clientMessageId: 1 },
  { unique: true, partialFilterExpression: { clientMessageId: { $type: 'string' } } }
);

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

/** Limits that keep a reaction row readable. */
const REACTION_LIMITS = Object.freeze({ perUser: 8, distinct: 20 });

/**
 * Add or remove ONE emoji for a user; other emojis the user gave stay (a
 * doctor may react with several, beta 11-26). Same emoji again removes it.
 *
 * Atomic per step ($pull / $addToSet / $push on the stored document), so two
 * fast taps or two people reacting at once never collide. The old
 * read-modify-save raised a VersionError → "Something went wrong".
 *
 * [want]: true = add, false = remove, undefined = toggle.
 * Returns the stored reactions after the change.
 */
messageSchema.statics.setReaction = async function (messageId, emoji, userId, want) {
  const uid = new mongoose.Types.ObjectId(String(userId));
  const current = await this.findById(messageId).select('reactions').lean();
  if (!current) return null;
  const mine = (current.reactions || []).filter((r) => (r.userIds || []).some((id) => String(id) === String(uid)));
  const has = mine.some((r) => r.emoji === emoji);
  const add = want === undefined ? !has : want;

  if (!add) {
    await this.updateOne(
      { _id: messageId, reactions: { $elemMatch: { emoji, userIds: uid } } },
      { $pull: { 'reactions.$.userIds': uid } }
    );
  } else if (!has) {
    if (mine.length >= REACTION_LIMITS.perUser) {
      const err = new Error(`You can add up to ${REACTION_LIMITS.perUser} reactions to a message`);
      err.statusCode = 400;
      throw err;
    }
    // Join an existing emoji group, else start one (retry once on a race
    // where someone else started the same group in between).
    for (let attempt = 0; attempt < 3; attempt++) {
      const joined = await this.updateOne(
        { _id: messageId, 'reactions.emoji': emoji },
        { $addToSet: { 'reactions.$.userIds': uid } }
      );
      if (joined.matchedCount > 0) break;
      const started = await this.updateOne(
        {
          _id: messageId,
          'reactions.emoji': { $ne: emoji },
          [`reactions.${REACTION_LIMITS.distinct - 1}`]: { $exists: false },
        },
        { $push: { reactions: { emoji, userIds: [uid] } } }
      );
      if (started.matchedCount > 0) break;
      const full = await this.exists({ _id: messageId, [`reactions.${REACTION_LIMITS.distinct - 1}`]: { $exists: true } });
      if (full) {
        const err = new Error('This message has too many different reactions');
        err.statusCode = 400;
        throw err;
      }
    }
  }
  // Drop emoji groups nobody uses any more.
  await this.updateOne({ _id: messageId }, { $pull: { reactions: { userIds: { $size: 0 } } } });
  const after = await this.findById(messageId).select('reactions').lean();
  return after?.reactions || [];
};
messageSchema.statics.REACTION_LIMITS = REACTION_LIMITS;

/** Compatibility wrapper (one emoji toggled for one user). */
messageSchema.methods.toggleReaction = async function (emoji, userId) {
  const reactions = await this.constructor.setReaction(this._id, emoji, userId);
  this.reactions = reactions || [];
  return this;
};

const Message = mongoose.model('Message', messageSchema);
module.exports = Message;
