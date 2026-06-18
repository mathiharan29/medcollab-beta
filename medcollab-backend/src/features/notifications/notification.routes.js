/**
 * NOTIFICATION ROUTES
 *
 * GET    /api/notifications              — Get my notification inbox (paginated)
 * GET    /api/notifications/unread-count — Get count of unread notifications
 * PUT    /api/notifications/:id/read     — Mark a single notification as read
 * PUT    /api/notifications/read-all     — Mark all notifications as read
 * DELETE /api/notifications/:id          — Delete a single notification
 *
 * These routes power the in-app notification bell / inbox.
 * FCM push notifications are handled server-side by the notification service
 * and are not exposed through these routes.
 */

const express = require('express');
const router = express.Router();

const { protect, requireOnboarding } = require('../../middleware/auth');
const { validateMongoId, validatePagination } = require('../../middleware/validate');

// Placeholder controller
const notificationController = require('./notification.controller');

router.use(protect, requireOnboarding);

/**
 * @route   GET /api/notifications
 * @desc    Get paginated notification inbox for the authenticated user
 * @access  Protected
 * @query   { limit: 20, before: "<notificationId>", unreadOnly: false }
 *
 * Returns notifications sorted by createdAt descending (newest first).
 * Each notification includes deep-link metadata so Flutter knows
 * which screen to navigate to when tapped.
 *
 * Example notification object:
 * {
 *   _id: "...",
 *   type: "mention",
 *   title: "New mention",
 *   body: "Dr. Priya mentioned you in #emergency",
 *   read: false,
 *   priority: "urgent",
 *   actorName: "Dr. Priya",
 *   actorAvatarUrl: "...",
 *   metadata: {
 *     spaceId: "...",
 *     channelId: "...",
 *     messageId: "..."
 *   },
 *   createdAt: "..."
 * }
 */
router.get('/', validatePagination, notificationController.getNotifications);

/**
 * @route   GET /api/notifications/unread-count
 * @desc    Get the count of unread notifications
 * @access  Protected
 *
 * Returns: { count: 5 }
 * Used to show the badge number on the notification bell icon.
 * Called on app resume / foreground event.
 *
 * NOTE: This route must be defined BEFORE /:id to prevent
 * "unread-count" being matched as a MongoDB ObjectId.
 */
router.get('/unread-count', notificationController.getUnreadCount);

/**
 * @route   PUT /api/notifications/read-all
 * @desc    Mark all of the user's notifications as read
 * @access  Protected
 *
 * Returns: { modifiedCount: 5 }
 * Called when user taps "Mark all as read" in the notification inbox.
 *
 * NOTE: Must also be before /:id route.
 */
router.put('/read-all', notificationController.markAllAsRead);

/**
 * @route   PUT /api/notifications/:id/read
 * @desc    Mark a single notification as read
 * @access  Protected + Must own the notification
 *
 * Called when user taps on a notification to navigate to the content.
 * The Flutter app calls this after navigating so the notification
 * updates from unread → read in real time.
 */
router.put('/:id/read', validateMongoId('id'), notificationController.markAsRead);

/**
 * @route   DELETE /api/notifications/:id
 * @desc    Delete a single notification from the inbox
 * @access  Protected + Must own the notification
 */
router.delete('/:id', validateMongoId('id'), notificationController.deleteNotification);

module.exports = router;
