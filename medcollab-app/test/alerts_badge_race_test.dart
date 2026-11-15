// Issue 6 (beta 11-14): Alerts count did not drop after reading a chat.
// Causes covered here:
//  - a badge refresh in flight when the chat was read finished afterwards
//    and put the old count back (and the shared fetch was reused/cached);
//  - an alert for the chat on screen was counted +1 while being cleared;
//  - alerts were auto-read while the app sat in the background.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/chat/active_chat_tracker.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:medcollab_app/features/shell/presentation/cubit/nav_badges_cubit.dart';

import 'functional_regression/fakes/chat_fakes.dart';

AppNotificationModel _alert(String id, String channel, {bool read = false}) =>
    AppNotificationModel(
      id: id,
      type: 'new_message',
      title: 'Dr Bala',
      body: 'msg $id',
      read: read,
      metadata: NotificationMetadata(channelId: channel),
    );

/// Server whose list reads its state when the request STARTS and can be
/// held open, like a slow network request.
class _Server extends NotificationRepository {
  _Server() : super(apiClient: isolatedApiClient());

  List<AppNotificationModel> rows = [];
  Completer<void>? hold;
  int listCalls = 0;

  int get unread => rows.where((r) => !r.read).length;

  @override
  Future<NotificationsPageResult> getNotifications({
    bool unreadOnly = false,
    String? before,
    String? type,
    int limit = 30,
  }) async {
    listCalls++;
    final snapshot = List.of(rows);
    final h = hold;
    if (h != null) await h.future;
    return NotificationsPageResult(
      notifications: snapshot,
      hasMore: false,
      unreadCount: snapshot.where((r) => !r.read).length,
    );
  }

  @override
  Future<int> getUnreadCount() async => unread;

  Completer<void>? readHold;

  @override
  Future<int> putReadByChannel(String channelId) async {
    final h = readHold;
    if (h != null) await h.future;
    rows = [
      for (final r in rows)
        r.metadata.channelId == channelId ? _alert(r.id, channelId, read: true) : r,
    ];
    return unread;
  }
}

class _Handoffs extends HandoffRepository {
  _Handoffs() : super(apiClient: isolatedApiClient());
  @override
  Future<List<HandoffModel>> getMyHandoffs({
    String? spaceId,
    String type = 'all',
    HandoffStatus? status,
  }) async =>
      const [];
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Server server;
  late FakeSocketClient socket;
  late NotificationBadgeCubit badge;
  late NavBadgesCubit nav;

  setUp(() {
    server = _Server()
      ..rows = [_alert('1', 'c1'), _alert('2', 'c1'), _alert('3', 'c2')];
    socket = FakeSocketClient();
    badge = NotificationBadgeCubit(repository: server, socketClient: socket);
    nav = NavBadgesCubit(
      notificationRepository: server,
      handoffRepository: _Handoffs(),
      notificationBadgeCubit: badge,
      socketClient: socket,
    );
    ActiveChatTracker.instance.leave(ActiveChatTracker.instance.channelId ?? '');
    ActiveChatTracker.instance.setForeground(true);
  });

  tearDown(() async {
    await nav.close();
    await badge.close();
  });

  test('a refresh in flight while a chat is read never restores the old count',
      () async {
    nav.setUserId('me');
    await _settle();
    expect(nav.state.alertsCount, 3);

    // A new alert arrives (drops the short-lived shared cache, as any
    // realtime event does) → refresh starts and hangs (server says 3).
    await server.markReadByChannel('unrelated');
    server.hold = Completer<void>();
    final pending = nav.refresh();
    await _settle();

    // Doctor opens chat c1 meanwhile: server now has 1 unread.
    final after = await server.markReadByChannel('c1');
    badge.setCount(after);
    await _settle();
    expect(nav.state.alertsCount, 1);

    // The old request finally answers "3". It must be discarded.
    final h = server.hold!;
    server.hold = null;
    h.complete();
    await pending;
    await _settle();
    expect(nav.state.alertsCount, 1, reason: 'stale in-flight count won');
    expect(badge.state, 1);
  });

  test('new alerts arriving right after a refresh are counted (found on device)',
      () async {
    nav.setUserId('me');
    await _settle();
    expect(nav.state.alertsCount, 3);
    // Within the shared list's 1.5 s reuse window, 3 new messages arrive.
    server.rows = [
      ...server.rows,
      _alert('n1', 'c9'),
      _alert('n2', 'c9'),
      _alert('n3', 'c9'),
    ];
    for (final id in ['n1', 'n2', 'n3']) {
      socket.emitEvent(SocketEvents.newNotification, {
        '_id': id,
        'metadata': {'channelId': 'c9'},
      });
    }
    await _settle();
    await _settle();
    expect(nav.state.alertsCount, 6, reason: 'was stuck at the cached 3');
  });

  test('the shared list is not reused across a read (no 1.5 s stale cache)',
      () async {
    server.hold = Completer<void>();
    final early = server.getRecentNotificationsShared();
    await server.markReadByChannel('c1');
    final h = server.hold!;
    server.hold = null;
    h.complete();
    expect((await early).unreadCount, 3, reason: 'the early request itself');
    final fresh = await server.getRecentNotificationsShared();
    expect(fresh.unreadCount, 1, reason: 'later callers get post-read data');
  });

  test('alert for the chat on screen is not counted; badge drops to server count',
      () async {
    nav.setUserId('me');
    await _settle();
    final list = NotificationsCubit(
      repository: server,
      socketClient: socket,
      badgeCubit: badge,
    );
    await _settle();
    expect(list.state.unreadCount, 3);

    final seen = <int>[];
    final sub = badge.stream.listen(seen.add);
    ActiveChatTracker.instance.enter('c2');
    server.rows = [...server.rows, _alert('4', 'c2')];
    // Hold the server-side clear so we can look at the screen meanwhile.
    server.readHold = Completer<void>();
    socket.emitEvent(SocketEvents.newNotification, {
      '_id': '4',
      'type': 'new_message',
      'title': 'Dr Bala',
      'body': 'msg 4',
      'read': false,
      'metadata': {'channelId': 'c2'},
    });
    await _settle();
    // While the clear is still on its way: shown as read, never counted.
    final row = list.state.notifications.firstWhere((n) => n.id == '4');
    expect(row.read, isTrue, reason: 'read as it arrived');
    expect(seen.where((c) => c > 3), isEmpty,
        reason: 'badge must never count the chat being read: $seen');

    server.readHold!.complete();
    server.readHold = null;
    await _settle();
    expect(badge.state, 2, reason: 'c2 cleared on server: 2 left in c1');
    expect(nav.state.alertsCount, 2);
    await sub.cancel();
    await list.close();
  });

  test('backgrounded chat does not swallow alerts; resume clears them', () async {
    final entered = <String>[];
    ActiveChatTracker.instance.onEnter = entered.add;
    ActiveChatTracker.instance.enter('c1');
    ActiveChatTracker.instance.setForeground(false);
    expect(ActiveChatTracker.instance.isViewing('c1'), isFalse);

    socket.emitEvent(SocketEvents.newNotification, {
      '_id': '9',
      'metadata': {'channelId': 'c1'},
    });
    await _settle();
    expect(server.unread, 3, reason: 'nothing marked read while away');

    ActiveChatTracker.instance.setForeground(true);
    expect(ActiveChatTracker.instance.isViewing('c1'), isTrue);
    expect(entered, ['c1', 'c1']);
    badge.markChatRead('c1');
    await _settle();
    expect(badge.state, 1);
    ActiveChatTracker.instance.onEnter = null;
  });
}
