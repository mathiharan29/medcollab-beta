/**
 * USER MODEL
 *
 * Design decisions explained:
 *
 * 1. Phone as primary identity (not email)
 *    Indian doctors universally have a phone number.
 *    Email is inconsistent — many use college email that expires after graduation.
 *    Phone + OTP = zero password management.
 *
 * 2. No password field
 *    OTP-only auth. Nothing to hash, nothing to forget, nothing to breach.
 *
 * 3. fcmTokens is an array (not a string)
 *    A doctor might use the app on two phones (personal + hospital phone).
 *    We store all their device tokens and send notifications to all of them.
 *    Max 5 tokens per user — if they add a 6th, drop the oldest.
 *
 * 4. availability is embedded (not a separate collection)
 *    It changes frequently and is always read alongside the user.
 *    A separate collection would mean two DB calls to show "Dr. Priya — On Call".
 *
 * 5. isVerified vs isOnboarded
 *    isVerified: phone number confirmed via OTP
 *    isOnboarded: completed profile setup (name, role, speciality)
 *    We need both because a user might verify OTP but close the app before
 *    completing their profile. The Flutter app uses isOnboarded to decide
 *    whether to show the profile setup screen.
 *
 * 6. No patient data on the User model
 *    HIPAA-awareness: we never associate a doctor's account with specific patients.
 *    Patient references in handoffs use bed numbers and aliases only.
 */

const mongoose = require('mongoose');
const {
  USER_ROLES,
  AVAILABILITY_STATUS,
} = require('../../constants');

const availabilitySchema = new mongoose.Schema({
  status: {
    type: String,
    enum: Object.values(AVAILABILITY_STATUS),
    default: AVAILABILITY_STATUS.AVAILABLE,
  },
  // When "On Call" or "In OT", optionally show until when
  until: {
    type: Date,
    default: null,
  },
  // Human-readable note: "In CICU — emergency only"
  note: {
    type: String,
    maxlength: 100,
    default: '',
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
}, { _id: false }); // No separate _id for embedded docs

const userSchema = new mongoose.Schema(
  {
    // ── Identity ──────────────────────────────────────────────────────────
    phone: {
      type: String,
      required: [true, 'Phone number is required'],
      unique: true,
      trim: true,
      // Store with country code: +919876543210
      // Validated at the service layer, not schema layer
    },

    name: {
      type: String,
      trim: true,
      maxlength: [100, 'Name cannot exceed 100 characters'],
    },

    // Optional: used for display in academic contexts
    displayTitle: {
      type: String,
      trim: true,
      maxlength: 20, // "Dr.", "Prof.", "DNB"
    },

    // ── Medical Identity ──────────────────────────────────────────────────
    role: {
      type: String,
      enum: Object.values(USER_ROLES),
      default: USER_ROLES.INTERN,
    },

    speciality: {
      type: String,
      trim: true,
      maxlength: 100,
      // e.g. "Cardiology", "General Medicine", "Orthopaedics"
    },

    // For PG residents — which year they are in
    pgYear: {
      type: Number,
      min: 1,
      max: 6,
    },

    // Medical college or hospital affiliation
    institution: {
      type: String,
      trim: true,
      maxlength: 200,
    },

    // City — useful for future community features
    city: {
      type: String,
      trim: true,
      maxlength: 100,
    },

    // ── Profile ───────────────────────────────────────────────────────────
    avatarUrl: {
      type: String,
      default: null,
    },

    bio: {
      type: String,
      maxlength: 300,
      default: '',
    },

    // ── Authentication ────────────────────────────────────────────────────
    isVerified: {
      type: Boolean,
      default: false, // true after first OTP verification
    },

    isOnboarded: {
      type: Boolean,
      default: false, // true after completing profile setup
    },

    // Soft deactivation — admin can disable an account without deleting it
    isActive: {
      type: Boolean,
      default: true,
    },

    // ── Push Notifications ────────────────────────────────────────────────
    // Array because doctors use multiple devices
    fcmTokens: {
      type: [String],
      default: [],
      validate: {
        validator: (tokens) => tokens.length <= 5,
        message: 'Maximum 5 device tokens allowed',
      },
    },

    // ── Availability ──────────────────────────────────────────────────────
    availability: {
      type: availabilitySchema,
      default: () => ({}),
    },

    // ── Preferences ──────────────────────────────────────────────────────
    // Store only settings that affect backend behaviour
    // UI preferences (theme, font size) stay on the device
    notifications: {
      emergencyAlerts: { type: Boolean, default: true },
      mentions: { type: Boolean, default: true },
      newMessages: { type: Boolean, default: true },
      handoffs: { type: Boolean, default: true },
      // Quiet hours: no notifications between these times
      quietHoursStart: { type: String, default: null }, // "22:00"
      quietHoursEnd: { type: String, default: null },   // "07:00"
    },

    // ── Tracking ─────────────────────────────────────────────────────────
    lastSeenAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true, // Adds createdAt and updatedAt automatically
    toJSON: {
      transform: (doc, ret) => {
        // Never expose these fields in API responses
        delete ret.__v;
        return ret;
      },
    },
  }
);

// ── Indexes ─────────────────────────────────────────────────────────────────
// phone is already indexed via unique: true
// Index for searching members by institution (future: "find doctors at AIIMS")
userSchema.index({ institution: 1 });
userSchema.index({ role: 1, speciality: 1 });

// ── Instance Methods ─────────────────────────────────────────────────────────
// Methods available on a single user document

/**
 * Returns a safe public profile (no internal fields)
 * Used when sending user data to other users
 */
userSchema.methods.toPublicProfile = function () {
  return {
    _id: this._id,
    name: this.name,
    displayTitle: this.displayTitle,
    role: this.role,
    speciality: this.speciality,
    pgYear: this.pgYear,
    institution: this.institution,
    avatarUrl: this.avatarUrl,
    bio: this.bio,
    availability: this.availability,
    lastSeenAt: this.lastSeenAt,
    isOnboarded: this.isOnboarded,
    isVerified: this.isVerified,
  };
};

/**
 * Add an FCM token, removing duplicates and capping at 5
 */
userSchema.methods.addFcmToken = function (token) {
  // Remove duplicates
  this.fcmTokens = this.fcmTokens.filter((t) => t !== token);
  // Add to front (most recent first)
  this.fcmTokens.unshift(token);
  // Keep only 5
  if (this.fcmTokens.length > 5) {
    this.fcmTokens = this.fcmTokens.slice(0, 5);
  }
  return this.save();
};

const User = mongoose.model('User', userSchema);
module.exports = User;
