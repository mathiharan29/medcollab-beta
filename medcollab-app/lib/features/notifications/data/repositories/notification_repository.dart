import 'package:flutter/foundation.dart';
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

  /// Bumped before AND after every read-state change (mark read / unread /
  /// all / by chat / delete). A fetch whose epoch changed while it was in
  /// flight may predate the change and must not be shown or cached — it
  /// used to put the old count back on the Alerts badge after reading a
  /// chat (beta 11-14, issue 6).
  int _readEpoch = 0;
  int get readEpoch => _readEpoch;

  Future<NotificationsPageResult> getRecentNotificationsShared() {
    final cached = _recent;
    final at = _recentAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _recentTtl) {
      return Future.value(cached);
    }
    final pending = _recentInFlight;
    if (pending != null) return pending;
    final epoch = _readEpoch;
    final future = getNotifications(limit: _recentLimit).then((page) {
      if (epoch == _readEpoch) {
        _recent = page;
        _recentAt = DateTime.now();
      }
      return page;
    });
    _recentInFlight = future;
    future.whenComplete(() {
      if (identical(_recentInFlight, future)) _recentInFlight = null;
    }).ignore();
    return future;
  }

  void _invalidateRecent() {
    _readEpoch++;
    _recent = null;
    _recentAt = null;
    // Never hand a request started before this change to a later caller.
    _recentInFlight = null;
  }

  /// The server's alerts changed (a `new_notification` arrived). The shared
  /// list cached a moment ago — or still in flight — predates it: a burst
  /// of messages within its 1.5 s reuse window left the Alerts badge on the
  /// old count until the next event (issue 6, found on device).
  void serverChanged() => _invalidateRecent();

  Future<T> _readChange<T>(Future<T> Function() write) {
    _invalidateRecent();
    return write().whenComplete(_invalidateRecent);
  }

  Future<int> getUnreadCount() {
    return execute(
      () => apiClient.get(
        ApiEndpoints.unreadCount,
        parser: (json) => (json['count'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Future<void> markAsRead(String notificationId) => _readChange(
        () => executeVoid(
          () => apiClient.put(ApiEndpoints.markNotificationRead(notificationId)),
        ),
      );

  Future<void> markAsUnread(String notificationId) => _readChange(
        () => executeVoid(
          () =>
              apiClient.put(ApiEndpoints.markNotificationUnread(notificationId)),
        ),
      );

  Future<void> markAllAsRead() => _readChange(
        () => executeVoid(() => apiClient.put(ApiEndpoints.markAllRead)),
      );

  /// Mark all unread alerts for a channel as read (when the doctor opens that
  /// chat). Returns the server's unread count after the change.
  Future<int> markReadByChannel(String channelId) =>
      _readChange(() => putReadByChannel(channelId));

  /// The HTTP call behind [markReadByChannel] (overridden in tests).
  @protected
  Future<int> putReadByChannel(String channelId) => execute(
        () => apiClient.put(
          ApiEndpoints.markNotificationsReadByChannel(channelId),
          parser: (json) => (json['unreadCount'] as num?)?.toInt() ?? 0,
        ),
      );

  Future<void> deleteNotification(String notificationId) => _readChange(
        () => executeVoid(
          () => apiClient.delete(ApiEndpoints.notificationById(notificationId)),
        ),
      );
}
