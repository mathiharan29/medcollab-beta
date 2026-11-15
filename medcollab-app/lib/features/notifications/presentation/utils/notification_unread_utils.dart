import 'package:medcollab_app/core/chat/active_chat_tracker.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';

/// The chat on screen is being read: its alerts count as read on this phone
/// even while the server-side clear is still on its way (otherwise the
/// badge / Alerts list briefly showed them unread again — issue 6).
NotificationsPageResult viewingChatAsRead(NotificationsPageResult page) {
  final viewing = ActiveChatTracker.instance;
  var cleared = 0;
  final rows = [
    for (final n in page.notifications)
      if (!n.read && viewing.isViewing(n.metadata.channelId))
        () {
          cleared++;
          return AppNotificationModel(
            id: n.id,
            type: n.type,
            title: n.title,
            body: n.body,
            read: true,
            createdAt: n.createdAt,
            actorName: n.actorName,
            metadata: n.metadata,
          );
        }()
      else
        n,
  ];
  if (cleared == 0) return page;
  return NotificationsPageResult(
    notifications: rows,
    hasMore: page.hasMore,
    unreadCount: (page.unreadCount - cleared).clamp(0, 1 << 30),
  );
}

/// Derive chat unread indicators from the in-app notification inbox.
Map<String, int> unreadCountsByChannel(
  Iterable<AppNotificationModel> notifications,
) {
  final counts = <String, int>{};
  for (final n in notifications) {
    if (n.read) continue;
    if (!_isChatCategory(n.category)) continue;
    final channelId = n.metadata.channelId;
    if (channelId == null || channelId.isEmpty) continue;
    counts[channelId] = (counts[channelId] ?? 0) + 1;
  }
  return counts;
}

bool hasUnreadChatNotifications(
  Iterable<AppNotificationModel> notifications,
) {
  for (final n in notifications) {
    if (!n.read && _isChatCategory(n.category)) return true;
  }
  return false;
}

bool _isChatCategory(AppNotificationCategory category) {
  return category == AppNotificationCategory.message ||
      category == AppNotificationCategory.reply ||
      category == AppNotificationCategory.mention;
}
