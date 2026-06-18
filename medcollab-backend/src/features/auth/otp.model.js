/**
 * OTP MODEL
 *
 * Why a separate collection for OTPs (not on the User model)?
 *
 * OTPs are temporary and high-churn. A doctor might request 10 OTPs
 * (retries, expired codes) before a successful login. Storing this history
 * on the User document would make it grow unboundedly.
 *
 * A separate collection lets us:
 * 1. Set a MongoDB TTL index — documents auto-delete after expiry (no cron needed)
 * 2. Track OTP request patterns for rate limiting and abuse detection
 * 3. Keep the User model clean
 *
 * Security design:
 * - We store a HASH of the OTP, not the raw code (same principle as passwords)
 * - Even if someone dumps the database, they can't see actual OTP codes
 * - The OTP is hashed with bcrypt before storage
 * - Verified OTPs are deleted immediately (not just marked used)
 */

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const otpSchema = new mongoose.Schema({
  phone: {
    type: String,
    required: true,
    index: true,
  },

  // Stored as a bcrypt hash — never the raw 6-digit code
  otpHash: {
    type: String,
    required: true,
  },

  // How many times this OTP was attempted (prevent brute force)
  attempts: {
    type: Number,
    default: 0,
    max: 3, // After 3 wrong attempts, this OTP is dead
  },

  isUsed: {
    type: Boolean,
    default: false,
  },

  // TTL: MongoDB automatically deletes this document after expiry
  // The index below makes this work
  expiresAt: {
    type: Date,
    required: true,
    default: () => {
      const minutes = parseInt(process.env.OTP_EXPIRY_MINUTES || '10');
      return new Date(Date.now() + minutes * 60 * 1000);
    },
  },

  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// ── TTL Index ─────────────────────────────────────────────────────────────────
// MongoDB will automatically delete OTP documents after `expiresAt`
// This is more reliable than any cron job
otpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

// Compound index for the verify operation: find by phone + not used + not expired
otpSchema.index({ phone: 1, isUsed: 1, expiresAt: 1 });

// ── Static Methods ────────────────────────────────────────────────────────────

/**
 * Create a new OTP for a phone number
 * Invalidates any previous OTPs for this number first
 */
otpSchema.statics.createOtp = async function (phone, otpCode) {
  // Invalidate previous OTPs for this phone
  await this.updateMany({ phone, isUsed: false }, { isUsed: true });

  // Hash the OTP before storing
  const salt = await bcrypt.genSalt(10);
  const otpHash = await bcrypt.hash(otpCode, salt);

  return this.create({ phone, otpHash });
};

/**
 * Verify an OTP code for a phone number
 * Returns: { valid: boolean, reason?: string }
 */
otpSchema.statics.verifyOtp = async function (phone, otpCode) {
  const otp = await this.findOne({
    phone,
    isUsed: false,
    expiresAt: { $gt: new Date() },
    attempts: { $lt: 3 },
  }).sort({ createdAt: -1 }); // Most recent OTP first

  if (!otp) {
    return { valid: false, reason: 'OTP expired or not found' };
  }

  // Increment attempt counter before checking
  otp.attempts += 1;
  await otp.save();

  const isMatch = await bcrypt.compare(otpCode, otp.otpHash);

  if (!isMatch) {
    if (otp.attempts >= 3) {
      return { valid: false, reason: 'Too many incorrect attempts' };
    }
    return { valid: false, reason: 'Incorrect OTP' };
  }

  // Valid — mark as used and delete it
  await this.deleteOne({ _id: otp._id });
  return { valid: true };
};

const OTP = mongoose.model('OTP', otpSchema);
module.exports = OTP;
