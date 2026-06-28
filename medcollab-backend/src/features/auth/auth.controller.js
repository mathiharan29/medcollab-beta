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
  verifyWidgetAccessToken,
  normalizePhoneToE164,
} = require('../../services/msg91Widget.service');
const {
  generateAccessToken,
  generateRefreshToken,
} = require('../../middleware/auth');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const jwt = require('jsonwebtoken');
const logger = require('../../utils/logger');

const issueAuthTokensForPhone = async (phone) => {
  let user = await User.findOne({ phone });
  const isNewUser = !user;

  if (!user) {
    user = await User.create({
      phone,
      isVerified: true,
    });
    logger.info(`New user registered: ${phone}`);
  } else {
    user.isVerified = true;
    await user.save();
    logger.info(`User logged in: ${phone} (${user.name || 'no name yet'})`);
  }

  return {
    accessToken: generateAccessToken(user._id),
    refreshToken: generateRefreshToken(user._id),
    isNewUser,
    user: user.toPublicProfile(),
  };
};

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

  const auth = await issueAuthTokensForPhone(phone);

  return respond.ok(
    res,
    auth.isNewUser ? 'Account created' : 'Login successful',
    auth,
  );
});

/**
 * POST /api/auth/verify-msg91-token
 * Verify MSG91 OTP Widget access token, return MedCollab JWT pair.
 *
 * Used when the Flutter app sends OTP via MSG91 widget SDK (no DLT template).
 */
const verifyMsg91Token = asyncHandler(async (req, res) => {
  const { phone, accessToken } = req.body;

  let verified;
  try {
    verified = await verifyWidgetAccessToken(accessToken);
  } catch (err) {
    logger.warn(`MSG91 widget token verification failed: ${err.message}`);
    return respond.badRequest(res, 'Invalid or expired OTP session');
  }

  const clientPhone = normalizePhoneToE164(phone);
  if (clientPhone && clientPhone !== verified.phone) {
    return respond.badRequest(res, 'Phone number does not match verified identity');
  }

  const auth = await issueAuthTokensForPhone(verified.phone);

  return respond.ok(
    res,
    auth.isNewUser ? 'Account created' : 'Login successful',
    auth,
  );
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

module.exports = { requestOtp, verifyOtp, verifyMsg91Token, refreshToken, logout };
