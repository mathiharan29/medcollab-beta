import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notifications_cubit.dart';

import 'fakes/chat_fakes.dart';

const _alert = AppNotificationModel(
  id: 'notification-synthetic-1',
  type: 'new_message',
  title: 'Synthetic channel message',
  body: 'A test-only alert',
  read: false,
  metadata: NotificationMetadata(channelId: 'channel-synthetic-1'),
);

class _FakeNotificationRepository extends NotificationRepository {
  _FakeNotificationRepository() : super(apiClient: isolatedApiClient());

  List<AppNotificationModel> server = const [];
  bool failNextRead = false;
  bool failNextUnread = false;
  int readCalls = 0;
  int unreadCalls = 0;

  int get serverUnread => server.where((alert) => !alert.read).length;

  @override
  Future<NotificationsPageResult> getNotifications({
    bool unreadOnly = false,
    String? before,
    String? type,
    int limit = 30,
  }) async => NotificationsPageResult(
        notifications: List.of(server),
        hasMore: false,
        unreadCount: serverUnread,
      );

  @override
  Future<int> getUnreadCount() async => serverUnread;

  @override
  Future<void> markAsRead(String notificationId) async {
    readCalls++;
    if (failNextRead) {
      failNextRead = false;
      throw const ServerException('Synthetic read failure');
    }
    server = [for (final alert in server) alert.id == notificationId
      ? AppNotificationModel(id: alert.id, type: alert.type, title: alert.title,
          body: alert.body, read: true, metadata: alert.metadata)
      : alert];
  }

  @override
  Future<void> markAsUnread(String notificationId) async {
    unreadCalls++;
    if (failNextUnread) {
      failNextUnread = false;
      throw const ServerException('Synthetic unread failure');
    }
    server = [for (final alert in server) alert.id == notificationId
      ? AppNotificationModel(id: alert.id, type: alert.type, title: alert.title,
          body: alert.body, read: false, metadata: alert.metadata)
      : alert];
  }
}

void main() {
  test('FR-NOT-06: socket/HTTP dedupe and badge mutations recover from errors', () async {
    final repository = _FakeNotificationRepository();
    final socket = FakeSocketClient();
    final badge = NotificationBadgeCubit(repository: repository, socketClient: socket);
    final alerts = NotificationsCubit(
      repository: repository,
      socketClient: socket,
      badgeCubit: badge,
    );
    addTearDown(() async {
      await alerts.close();
      await badge.close();
      await socket.disposeFake();
    });
    await alerts.load();
    expect(alerts.state.notifications, isEmpty);
    expect(badge.state, 0);

    repository.server = const [_alert];
    socket.emitEvent(SocketEvents.newNotification, const {
      '_id': 'notification-synthetic-1',
      'type': 'new_message',
      'title': 'Synthetic channel message',
      'body': 'A test-only alert',
      'read': false,
      'metadata': {'channelId': 'channel-synthetic-1'},
    });
    expect(alerts.state.notifications.map((n) => n.id), ['notification-synthetic-1']);
    expect(alerts.state.unreadCount, 1);
    expect(badge.state, 1);

    await alerts.load();
    expect(alerts.state.notifications.map((n) => n.id), ['notification-synthetic-1']);
    expect(alerts.state.unreadCount, 1);
    expect(badge.state, 1);

    repository.failNextRead = true;
    await alerts.markRead(alerts.state.notifications.single);
    expect(alerts.state.notifications.single.read, isFalse);
    expect(alerts.state.unreadCount, 1);
    expect(badge.state, 1);
    await alerts.markRead(alerts.state.notifications.single);
    expect(repository.readCalls, 2);
    expect(alerts.state.notifications.single.read, isTrue);
    expect(alerts.state.unreadCount, 0);
    expect(badge.state, 0);

    repository.failNextUnread = true;
    await alerts.markUnread(alerts.state.notifications.single);
    expect(alerts.state.notifications.single.read, isTrue);
    expect(alerts.state.unreadCount, 0);
    expect(badge.state, 0);
    expect(alerts.state.error, 'Synthetic unread failure');
    await alerts.markUnread(alerts.state.notifications.single);
    expect(repository.unreadCalls, 2);
    expect(alerts.state.notifications.single.read, isFalse);
    expect(alerts.state.unreadCount, 1);
    expect(badge.state, 1);
    await alerts.load();
    expect(alerts.state.error, isNull);
    expect(alerts.state.notifications.length, 1);
    expect(alerts.state.unreadCount, repository.serverUnread);
  });
}
