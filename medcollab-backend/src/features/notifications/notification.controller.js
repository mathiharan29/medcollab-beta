/**
 * NOTIFICATION CONTROLLER
 */

const Notification = require('./notification.model');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { PAGINATION } = require('../../constants');

/**
 * GET /api/notifications
 * Paginated notification inbox — newest first
 */
const getNotifications = asyncHandler(async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || PAGINATION.DEFAULT_LIMIT, 100);
  const before = req.query.before;
  const unreadOnly = req.query.unreadOnly === 'true';

  const query = { userId: req.user._id };
  if (before) query._id = { $lt: before };
  if (unreadOnly) query.read = false;

  const notifications = await Notification.find(query)
    .sort({ _id: -1 })
    .limit(limit + 1)
    .lean();

  const hasMore = notifications.length > limit;
  if (hasMore) notifications.pop();

  const unreadCount = await Notification.getUnreadCount(req.user._id);

  return respond.ok(res, 'Notifications fetched', {
    notifications,
    hasMore,
    unreadCount,
  });
});

/**
 * GET /api/notifications/unread-count
 * Badge count for the notification bell
 */
const getUnreadCount = asyncHandler(async (req, res) => {
  const count = await Notification.getUnreadCount(req.user._id);
  return respond.ok(res, 'Unread count fetched', { count });
});

/**
 * PUT /api/notifications/:id/read
 * Mark a single notification as read
 */
const markAsRead = asyncHandler(async (req, res) => {
  const notification = await Notification.findOne({
    _id: req.params.id,
    userId: req.user._id,   // Ownership check
  });

  if (!notification) return respond.notFound(res, 'Notification not found');

  await notification.markRead();
  return respond.ok(res, 'Notification marked as read');
});

/**
 * PUT /api/notifications/read-all
 * Mark all notifications as read
 */
const markAllAsRead = asyncHandler(async (req, res) => {
  const result = await Notification.markAllRead(req.user._id);
  return respond.ok(res, 'All notifications marked as read', {
    modifiedCount: result.modifiedCount,
  });
});

/**
 * DELETE /api/notifications/:id
 * Delete a single notification
 */
const deleteNotification = asyncHandler(async (req, res) => {
  const result = await Notification.deleteOne({
    _id: req.params.id,
    userId: req.user._id,   // Ownership check
  });

  if (result.deletedCount === 0) {
    return respond.notFound(res, 'Notification not found');
  }

  return respond.ok(res, 'Notification deleted');
});

module.exports = {
  getNotifications, getUnreadCount,
  markAsRead, markAllAsRead, deleteNotification,
};
