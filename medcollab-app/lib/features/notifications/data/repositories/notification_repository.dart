import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

class NotificationRepository extends BaseRepository {
  NotificationRepository({required super.apiClient});

  Future<NotificationsPageResult> getNotifications({
    bool unreadOnly = false,
    String? before,
    String? type,
    int limit = 30,
  }) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.notifications,
        queryParameters: {
          'limit': limit,
          if (before != null) 'before': before,
          if (unreadOnly) 'unreadOnly': 'true',
          if (type != null) 'type': type,
        },
        parser: (json) => NotificationsPageResult(
          notifications: parseNestedList(
            json,
            'notifications',
            AppNotificationModel.fromJson,
          ),
          hasMore: json['hasMore'] as bool? ?? false,
          unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        ),
      ),
    );
  }

  // ── Shared "recent notifications" (REQ 13) ────────────────────────────
  // Badges and the Messages hub both need the latest notifications after
  // every event. They used to fetch 50 and 100 items separately (~80 KB per
  // event). Concurrent callers now share one request, and the result is
  // reused briefly; any read-state change invalidates it.
  static const _recentLimit = 50;
  static const _recentTtl = Duration(milliseconds: 1500);
  Future<NotificationsPageResult>? _recentInFlight;
  NotificationsPageResult? _recent;
  DateTime? _recentAt;

  Future<NotificationsPageResult> getRecentNotificationsShared() {
    final cached = _recent;
    final at = _recentAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _recentTtl) {
      return Future.value(cached);
    }
    return _recentInFlight ??= getNotifications(limit: _recentLimit)
        .then((page) {
      _recent = page;
      _recentAt = DateTime.now();
      return page;
    }).whenComplete(() => _recentInFlight = null);
  }

  void _invalidateRecent() {
    _recent = null;
    _recentAt = null;
  }

  Future<int> getUnreadCount() {
    return execute(
      () => apiClient.get(
        ApiEndpoints.unreadCount,
        parser: (json) => (json['count'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Future<void> markAsRead(String notificationId) {
    _invalidateRecent();
    return executeVoid(
      () => apiClient.put(ApiEndpoints.markNotificationRead(notificationId)),
    );
  }

  Future<void> markAsUnread(String notificationId) {
    _invalidateRecent();
    return executeVoid(
      () => apiClient.put(ApiEndpoints.markNotificationUnread(notificationId)),
    );
  }

  Future<void> markAllAsRead() {
    _invalidateRecent();
    return executeVoid(() => apiClient.put(ApiEndpoints.markAllRead));
  }

  /// Mark all unread alerts for a channel as read (when the doctor opens that chat).
  Future<int> markReadByChannel(String channelId) {
    _invalidateRecent();
    return execute(
      () => apiClient.put(
        ApiEndpoints.markNotificationsReadByChannel(channelId),
        parser: (json) => (json['unreadCount'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Future<void> deleteNotification(String notificationId) {
    _invalidateRecent();
    return executeVoid(
      () => apiClient.delete(ApiEndpoints.notificationById(notificationId)),
    );
  }
}
