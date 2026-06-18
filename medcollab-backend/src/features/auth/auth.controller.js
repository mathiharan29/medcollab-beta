/**
 * AUTH CONTROLLER
 *
 * Handles all authentication operations.
 * Thin layer: validates, calls services, returns responses.
 * Business logic lives in otp.service.js and middleware/auth.js.
 */

const User = require('../users/user.model');
const otpService = require('../../services/otp.service');
const {
  generateAccessToken,
  generateRefreshToken,
} = require('../../middleware/auth');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const jwt = require('jsonwebtoken');
const logger = require('../../utils/logger');

/**
 * POST /api/auth/request-otp
 * Send a 6-digit OTP to the provided phone number
 */
const requestOtp = asyncHandler(async (req, res) => {
  const { phone } = req.body;

  await otpService.sendOtp(phone);

  // Never reveal whether the phone is already registered
  // (prevents user enumeration — an attacker can't probe which phones are in the system)
  return respond.ok(res, 'OTP sent successfully. Valid for 10 minutes.', {
    phone,
    expiresInMinutes: parseInt(process.env.OTP_EXPIRY_MINUTES) || 10,
  });
});

/**
 * POST /api/auth/verify-otp
 * Verify OTP, return tokens + user object
 *
 * Response includes isNewUser so Flutter knows whether to show:
 * - Profile setup screen (new user)
 * - Home screen (returning user)
 */
const verifyOtp = asyncHandler(async (req, res) => {
  const { phone, otp } = req.body;

  // Verify the OTP against the hashed record
  const result = await otpService.verifyOtp(phone, otp);

  if (!result.valid) {
    return respond.badRequest(res, result.reason || 'Invalid or expired OTP');
  }

  // Find or create the user
  let user = await User.findOne({ phone });
  const isNewUser = !user;

  if (!user) {
    user = await User.create({
      phone,
      isVerified: true,
      // Name, role, speciality etc. filled in during onboarding
    });
    logger.info(`New user registered: ${phone}`);
  } else {
    user.isVerified = true;
    await user.save();
    logger.info(`User logged in: ${phone} (${user.name || 'no name yet'})`);
  }

  // Generate token pair
  const accessToken = generateAccessToken(user._id);
  const refreshToken = generateRefreshToken(user._id);

  return respond.ok(res, isNewUser ? 'Account created' : 'Login successful', {
    accessToken,
    refreshToken,
    isNewUser,
    user: user.toPublicProfile(),
  });
});

/**
 * POST /api/auth/refresh
 * Exchange a valid refresh token for a new access token
 *
 * Refresh tokens are long-lived (30 days).
 * Access tokens are short-lived (15 min).
 * The client stores both securely (flutter_secure_storage).
 * When the access token expires, the client calls this endpoint silently.
 */
const refreshToken = asyncHandler(async (req, res) => {
  const { refreshToken: token } = req.body;

  if (!token) {
    return respond.unauthorized(res, 'Refresh token required');
  }

  let decoded;
  try {
    decoded = jwt.verify(token, process.env.JWT_REFRESH_SECRET);
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return respond.unauthorized(res, 'Session expired. Please log in again.');
    }
    return respond.unauthorized(res, 'Invalid refresh token');
  }

  // Confirm user still exists and is active
  const user = await User.findById(decoded.userId).select('_id isActive');
  if (!user || !user.isActive) {
    return respond.unauthorized(res, 'Account not found or deactivated');
  }

  const newAccessToken = generateAccessToken(user._id);

  return respond.ok(res, 'Token refreshed', { accessToken: newAccessToken });
});

/**
 * POST /api/auth/logout
 * Remove the device's FCM token — stops push notifications to this device
 */
const logout = asyncHandler(async (req, res) => {
  const { fcmToken } = req.body;

  if (fcmToken) {
    // Remove this specific device token
    await User.findByIdAndUpdate(req.user._id, {
      $pull: { fcmTokens: fcmToken },
    });
  }

  return respond.ok(res, 'Logged out successfully');
});

module.exports = { requestOtp, verifyOtp, refreshToken, logout };
