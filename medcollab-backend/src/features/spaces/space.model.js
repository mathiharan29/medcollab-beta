/**
 * SPACE MODEL
 *
 * A Space is the top-level container in MedCollab.
 * Think of it like a Slack workspace or a WhatsApp group's parent.
 *
 * Examples of spaces:
 *  - "AIIMS Medicine PG 2024 Batch"
 *  - "Apollo Cardiology Department"
 *  - "GMC Emergency Medicine"
 *
 * Design decisions:
 *
 * 1. Members embedded as subdocuments (not a separate collection)
 *    For beta with 15 doctors, a space will have <50 members.
 *    Embedding is faster (one DB read) and simpler to query.
 *    If a space grows to 500+ members, we can extract to a SpaceMembers
 *    collection later — but that is not a today problem.
 *
 * 2. Invite code (6 characters, alphanumeric)
 *    The primary onboarding mechanism. A senior resident shares a code
 *    in an existing WhatsApp group → juniors join the space.
 *    This is our core growth loop. Keep it frictionless.
 *
 * 3. No patient data ever lives in a Space
 *    Spaces are organisational containers. Clinical data lives in
 *    messages, handoffs, and case threads only.
 *
 * 4. settings.requireApproval
 *    For sensitive departments (psychiatry, oncology), admins may want
 *    to approve each join request. Default is open join via code.
 */

const mongoose = require('mongoose');
const { SPACE_TYPES, SPACE_ROLES } = require('../../constants');

// ── Member Subdocument ────────────────────────────────────────────────────────
const memberSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    role: {
      type: String,
      enum: Object.values(SPACE_ROLES),
      default: SPACE_ROLES.MEMBER,
    },
    joinedAt: {
      type: Date,
      default: Date.now,
    },
    // Soft mute — member stays in space but gets no notifications
    isMuted: {
      type: Boolean,
      default: false,
    },
  },
  { _id: false }
);

// ── Space Schema ──────────────────────────────────────────────────────────────
const spaceSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Space name is required'],
      trim: true,
      minlength: [2, 'Name must be at least 2 characters'],
      maxlength: [100, 'Name cannot exceed 100 characters'],
    },

    description: {
      type: String,
      trim: true,
      maxlength: [300, 'Description cannot exceed 300 characters'],
      default: '',
    },

    type: {
      type: String,
      enum: Object.values(SPACE_TYPES),
      required: [true, 'Space type is required'],
    },

    // Optional avatar for the space (hospital logo, department icon)
    avatarUrl: {
      type: String,
      default: null,
    },

    // ── Invite System ─────────────────────────────────────────────────────
    // 6-char alphanumeric code. Generated on creation, can be regenerated.
    inviteCode: {
      type: String,
      required: true,
      unique: true,
      uppercase: true,
      // e.g. "A3K7BX" — easy to share verbally or in a WhatsApp message
    },

    // Full invite link that the app generates:
    // medcollab://join/A3K7BX
    // When pasted on mobile, opens the app or the Play Store

    // ── Members ───────────────────────────────────────────────────────────
    members: {
      type: [memberSchema],
      default: [],
    },

    // Pending join requests (when requireApproval is true)
    pendingRequests: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        requestedAt: { type: Date, default: Date.now },
        message: { type: String, maxlength: 200 }, // "I'm a PG in medicine here"
      },
    ],

    // ── Settings ──────────────────────────────────────────────────────────
    settings: {
      // If true, admin must approve each join request
      requireApproval: { type: Boolean, default: false },
      // If true, only admins can post in #announcements channel
      // (channels enforce this themselves, but stored here as space policy)
      onlyAdminsCanAnnounce: { type: Boolean, default: true },
    },

    // ── Lifecycle ─────────────────────────────────────────────────────────
    isActive: {
      type: Boolean,
      default: true,
    },

    // Who created this space (always an admin)
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
  }
);

// ── Indexes ───────────────────────────────────────────────────────────────────
spaceSchema.index({ inviteCode: 1 }); // Fast join-by-code lookups
spaceSchema.index({ 'members.userId': 1 }); // Fast "find all spaces for a user"
spaceSchema.index({ createdBy: 1 });

// ── Virtuals ──────────────────────────────────────────────────────────────────
// memberCount is computed, not stored — avoids keeping a counter in sync
spaceSchema.virtual('memberCount').get(function () {
  return this.members.length;
});

// ── Instance Methods ──────────────────────────────────────────────────────────

/**
 * Check if a userId is a member of this space
 */
spaceSchema.methods.isMember = function (userId) {
  return this.members.some((m) => m.userId.toString() === userId.toString());
};

/**
 * Check if a userId is an admin or owner of this space
 */
spaceSchema.methods.isAdmin = function (userId) {
  const member = this.members.find(
    (m) => m.userId.toString() === userId.toString()
  );
  return member && [SPACE_ROLES.ADMIN, SPACE_ROLES.OWNER].includes(member.role);
};

/**
 * Get a member's role in this space
 */
spaceSchema.methods.getMemberRole = function (userId) {
  const member = this.members.find(
    (m) => m.userId.toString() === userId.toString()
  );
  return member ? member.role : null;
};

// ── Static Methods ────────────────────────────────────────────────────────────

/**
 * Generate a unique 6-character alphanumeric invite code
 */
spaceSchema.statics.generateInviteCode = async function () {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, O, 0, 1 (confusing)
  let code;
  let isUnique = false;

  while (!isUnique) {
    code = Array.from({ length: 6 }, () =>
      chars.charAt(Math.floor(Math.random() * chars.length))
    ).join('');

    const existing = await this.findOne({ inviteCode: code });
    if (!existing) isUnique = true;
  }

  return code;
};

const Space = mongoose.model('Space', spaceSchema);
module.exports = Space;
