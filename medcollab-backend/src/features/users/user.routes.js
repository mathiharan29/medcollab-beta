/**
 * USER ROUTES
 *
 * GET    /api/users/me                — Get my own profile
 * PUT    /api/users/me                — Update my profile (name, speciality, etc.)
 * PUT    /api/users/me/availability   — Update my availability status
 * PUT    /api/users/me/fcm-token      — Register a new device FCM token
 * GET    /api/users/:id               — Get another user's public profile
 * GET    /api/users/search            — Search users by name/institution
 */

const express = require('express');
const router = express.Router();
const { protect, requireOnboarding } = require('../../middleware/auth');
const {
  validateUpdateProfile,
  validateAvailability,
  validateMongoId,
} = require('../../middleware/validate');
const { body } = require('express-validator');
const { handleValidationErrors } = require('../../middleware/validate');

// Placeholder controller
const userController = require('./user.controller');

// All user routes require authentication
router.use(protect);

/**
 * @route   GET /api/users/me
 * @desc    Get the authenticated user's full profile
 * @access  Protected
 *
 * Returns the full user object including:
 * - Profile info
 * - Notification preferences
 * - Availability status
 *
 * Called on app startup to hydrate the local user state in Flutter.
 */
router.get('/me', userController.getMe);

/**
 * @route   PUT /api/users/me
 * @desc    Update profile fields
 * @access  Protected
 * @body    { name, role, speciality, pgYear, institution, city, bio, displayTitle }
 *
 * After successful update, if isOnboarded was false and name+role are now set,
 * the controller sets isOnboarded = true.
 * Flutter polls this field to know when to navigate from setup → home.
 */
router.put('/me', validateUpdateProfile, userController.updateMe);

/**
 * @route   PUT /api/users/me/availability
 * @desc    Update availability status (On Call, In OT, Off Duty, etc.)
 * @access  Protected
 * @body    { status: "on_call", until: "2024-07-15T08:00:00Z", note: "In CICU" }
 *
 * After update: emit `presence_update` socket event to all spaces this user is in
 * so teammates see the status change in real time.
 */
router.put('/me/availability', validateAvailability, userController.updateAvailability);

/**
 * @route   PUT /api/users/me/fcm-token
 * @desc    Register or update device FCM token for push notifications
 * @access  Protected
 * @body    { token: "fcm-device-token-string" }
 *
 * Called by Flutter:
 * - On first app launch (after login)
 * - When FCM issues a new token (token refresh)
 */
router.put(
  '/me/fcm-token',
  [
    body('token').notEmpty().withMessage('FCM token is required'),
    handleValidationErrors,
  ],
  userController.registerFcmToken
);

/**
 * @route   GET /api/users/search
 * @desc    Search users to start a DM or mention someone
 * @access  Protected
 * @query   { q: "search term", spaceId: "optional — limit to space members" }
 *
 * Used by:
 * - DM creation flow (search for a colleague)
 * - @mention autocomplete in message composer
 *
 * NOTE: Must be defined BEFORE /:id route to prevent "search" being treated as a MongoDB ID
 */
router.get('/search', requireOnboarding, userController.searchUsers);

/**
 * @route   GET /api/users/:id
 * @desc    Get a user's public profile
 * @access  Protected
 * @returns { name, role, speciality, institution, availability, bio, avatarUrl }
 *
 * Used when:
 * - Tapping on a user's name in a channel
 * - Viewing member list in a space
 * - Selecting handoff recipient
 */
router.get('/:id', validateMongoId('id'), userController.getUserById);

module.exports = router;
