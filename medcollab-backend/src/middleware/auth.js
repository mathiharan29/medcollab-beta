/**
 * AUTH MIDDLEWARE
 *
 * Protects routes that require authentication.
 * Every protected route gets this middleware before the controller.
 *
 * How it works:
 * 1. Client sends: Authorization: Bearer <jwt_token>
 * 2. We extract and verify the JWT
 * 3. We fetch the user from DB (confirms account still exists + is active)
 * 4. We attach the full user object to req.user
 * 5. Controller can then access req.user without another DB query
 *
 * Why fetch the user on every request (not just trust the JWT)?
 * JWTs are stateless. If an account is deactivated (isActive: false),
 * their JWT is still technically valid until expiry. Fetching the user
 * lets us enforce account-level bans immediately.
 *
 * For a 15-user beta this is not a performance concern.
 * At scale, add Redis caching of user objects with a short TTL (60s).
 *
 * Two exports:
 * - protect: must be logged in
 * - restrictTo: must have a specific role in a space (used by space routes)
 */

const jwt = require('jsonwebtoken');
const User = require('../features/users/user.model');
const { respond } = require('../utils/apiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../utils/logger');

/**
 * Core authentication middleware
 * Attaches req.user on success
 */
const protect = asyncHandler(async (req, res, next) => {
  // 1. Extract token from Authorization header
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return respond.unauthorized(res, 'No token provided');
  }

  const token = authHeader.split(' ')[1];

  // 2. Verify JWT signature and expiry
  let decoded;
  try {
    decoded = jwt.verify(token, process.env.JWT_SECRET);
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return respond.unauthorized(res, 'Token expired');
    }
    if (err.name === 'JsonWebTokenError') {
      return respond.unauthorized(res, 'Invalid token');
    }
    logger.error('JWT verification error', err.message);
    return respond.unauthorized(res, 'Authentication failed');
  }

  // 3. Fetch the user — confirms account still exists
  const user = await User.findById(decoded.userId).select('-fcmTokens');

  if (!user) {
    return respond.unauthorized(res, 'User no longer exists');
  }

  if (!user.isActive) {
    return respond.unauthorized(res, 'Account has been deactivated');
  }

  // 4. Attach user to request — all downstream middleware and controllers can use this
  req.user = user;

  // 5. Update lastSeenAt asynchronously — don't await, don't block the request
  User.findByIdAndUpdate(user._id, { lastSeenAt: new Date() }).exec();

  next();
});

/**
 * Middleware to ensure the user has completed onboarding (profile setup)
 * Use after `protect` on routes that need a complete profile
 */
const requireOnboarding = (req, res, next) => {
  if (!req.user.isOnboarded) {
    return respond.forbidden(
      res,
      'Please complete your profile setup before continuing'
    );
  }
  next();
};

/**
 * Socket.io authentication (used in socket/index.js)
 * Same logic as `protect` but for WebSocket handshake
 * Returns the user object or throws
 */
const authenticateSocket = async (token) => {
  if (!token) throw new Error('No token provided');

  let decoded;
  try {
    decoded = jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    throw new Error('Invalid or expired token');
  }

  const user = await User.findById(decoded.userId).select('_id name role isActive');

  if (!user || !user.isActive) {
    throw new Error('User not found or deactivated');
  }

  return user;
};

/**
 * Generate an access token (short-lived: 15 minutes)
 */
const generateAccessToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_ACCESS_EXPIRES || '15m',
  });
};

/**
 * Generate a refresh token (long-lived: 30 days)
 * Stored on the client, used to get new access tokens
 */
const generateRefreshToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_REFRESH_SECRET, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES || '30d',
  });
};

module.exports = {
  protect,
  requireOnboarding,
  authenticateSocket,
  generateAccessToken,
  generateRefreshToken,
};
