/**
 * AUTH ROUTES
 *
 * POST /api/auth/request-otp   — Send OTP to phone number
 * POST /api/auth/verify-otp    — Verify OTP, return tokens
 * POST /api/auth/refresh        — Exchange refresh token for new access token
 * POST /api/auth/logout         — Invalidate FCM token on logout
 *
 * No controller files yet — controllers will be added on Day 2 (implementation day).
 * Today: route structure + middleware chain only.
 *
 * Why this order in middleware array:
 * [rateLimiter, validator, controller]
 * - Rate limit first: reject abusers before doing any work
 * - Validate second: reject bad input before hitting the DB
 * - Controller last: only clean, allowed requests reach business logic
 */

const express = require('express');
const router = express.Router();
const { otpLimiter, authLimiter } = require('../../middleware/rateLimiter');
const {
  validateRequestOtp,
  validateVerifyOtp,
  validateUpdateProfile,
  validateAvailability,
} = require('../../middleware/validate');
const { protect } = require('../../middleware/auth');

const authController = require('./auth.controller');

/**
 * @route   POST /api/auth/request-otp
 * @desc    Send a 6-digit OTP to the provided phone number
 * @access  Public
 * @body    { phone: "+919876543210" }
 *
 * Flow:
 * 1. Validate phone format
 * 2. Rate limit: max 5 requests per 15 min per IP+phone
 * 3. Generate 6-digit OTP
 * 4. Hash and store in OTP collection (with 10-min TTL)
 * 5. Send via MSG91 (or log to console in dev if OTP_BYPASS=true)
 * 6. Return { message: "OTP sent" } — never return the OTP itself
 */
router.post('/request-otp', otpLimiter, validateRequestOtp, authController.requestOtp);

/**
 * @route   POST /api/auth/verify-otp
 * @desc    Verify OTP, return access + refresh tokens
 * @access  Public
 * @body    { phone: "+919876543210", otp: "123456" }
 *
 * Flow:
 * 1. Validate phone + otp format
 * 2. Look up most recent valid OTP for this phone
 * 3. Compare hash — if mismatch, increment attempts
 * 4. If valid: find or create User, mark phone as verified
 * 5. Return { accessToken, refreshToken, user, isNewUser }
 *    - Flutter uses isNewUser to decide: go to Home or go to Profile Setup
 */
router.post('/verify-otp', authLimiter, validateVerifyOtp, authController.verifyOtp);

/**
 * @route   POST /api/auth/refresh
 * @desc    Exchange a valid refresh token for a new access token
 * @access  Public (but requires valid refresh token in body)
 * @body    { refreshToken: "..." }
 *
 * Why not use HTTP-only cookies?
 * Mobile apps can't easily use HTTP-only cookies.
 * Flutter stores the refresh token in flutter_secure_storage (encrypted).
 * This is the standard mobile auth pattern.
 */
router.post('/refresh', authLimiter, authController.refreshToken);

/**
 * @route   POST /api/auth/logout
 * @desc    Remove the device's FCM token (stops push notifications)
 * @access  Protected
 * @body    { fcmToken: "device-fcm-token" }
 *
 * Note: JWTs are stateless — we can't "invalidate" them server-side
 * without a token blacklist (Redis). For MVP, logout = remove FCM token
 * + let the JWT expire naturally (15 min).
 * The client deletes the JWT from secure storage on logout.
 */
router.post('/logout', protect, authController.logout);

module.exports = router;
