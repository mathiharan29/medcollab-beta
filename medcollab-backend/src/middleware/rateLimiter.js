/**
 * RATE LIMITER
 *
 * Prevents abuse of sensitive endpoints.
 * Critical for OTP endpoints — without rate limiting, anyone could:
 * - Spam a doctor's phone with OTP messages (costs money + harassment)
 * - Brute-force OTP codes (6 digits = 1,000,000 combinations)
 *
 * We define multiple limiters with different strictness levels:
 *
 * 1. globalLimiter  — applied to ALL routes (100 req/15min per IP)
 * 2. otpLimiter    — applied to /auth/request-otp (5 req/15min per IP)
 * 3. authLimiter   — applied to all auth routes (20 req/15min per IP)
 *
 * For beta (15 users): these limits are generous.
 * Tighten them before opening to the public.
 *
 * Note: express-rate-limit uses in-memory storage by default.
 * This is fine for a single-server deployment (Railway beta).
 * When we scale to multiple servers, switch to rate-limit-redis.
 */

const rateLimit = require('express-rate-limit');
const { ipKeyGenerator } = require('express-rate-limit');
const { respond } = require('../utils/apiResponse');

// Helper: shared rate limit response handler
const rateLimitHandler = (req, res) => {
  respond.tooManyRequests(
    res,
    'Too many requests from this IP. Please wait and try again.'
  );
};

/**
 * Global limiter — applied to all API routes
 * 100 requests per 15 minutes per IP
 */
const globalLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  standardHeaders: true,  // Return rate limit info in RateLimit-* headers
  legacyHeaders: false,
  handler: rateLimitHandler,
  skip: (req) => {
    // Skip rate limiting in test environments
    return process.env.NODE_ENV === 'test';
  },
});

/**
 * OTP limiter — strictest
 * 5 OTP requests per 15 minutes per IP
 * Prevents SMS bombing
 */
const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.OTP_RATE_LIMIT_MAX) || 5,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    respond.tooManyRequests(
      res,
      'Too many OTP requests. Please wait 15 minutes before trying again.'
    );
  },
  keyGenerator: (req) => {
    // Rate limit by both IP and phone number
    // Prevents one IP cycling through different numbers
    const phone = req.body?.phone || 'unknown';
    return `${ipKeyGenerator(req)}-${phone}`;
  },
});

/**
 * Auth limiter — for login/refresh routes
 * 20 requests per 15 minutes per IP
 */
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  handler: rateLimitHandler,
});

/**
 * Media upload limiter
 * 30 uploads per hour per user
 * Prevents storage abuse
 */
const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    respond.tooManyRequests(res, 'Upload limit reached. Try again in an hour.');
  },
  keyGenerator: (req) => {
    // Rate limit by user ID (not IP) for authenticated upload endpoint
    return req.user?._id?.toString() || ipKeyGenerator(req);
  },
});

module.exports = {
  globalLimiter,
  otpLimiter,
  authLimiter,
  uploadLimiter,
};
