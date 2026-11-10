import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';
import 'package:medcollab_app/features/notifications/presentation/utils/alert_grouping.dart';

AppNotificationModel n(String id, String type, {String? channel, bool read = false, String title = 'Dr Bala', int min = 0}) =>
    AppNotificationModel(
      id: id, type: type, title: title, body: 'body $id', read: read,
      createdAt: DateTime.utc(2026, 11, 10, 9, 59 - min),
      metadata: NotificationMetadata(channelId: channel),
    );

void main() {
  test('same chat collapses into one row; newest first; counts unread', () {
    final groups = groupAlerts([
      n('3', 'new_message', channel: 'dm-bala', min: 0),
      n('2', 'new_message', channel: 'dm-bala', min: 1),
      n('x', 'new_message', channel: 'dm-chitra', title: 'Dr Chitra', min: 2),
      n('1', 'thread_reply', channel: 'dm-bala', min: 3, read: true),
    ]);
    expect(groups.length, 2);
    expect(groups.first.latest.id, '3');
    expect(groups.first.count, 3);
    expect(groups.first.unreadCount, 2);
    expect(groups.first.isGrouped, isTrue);
    expect(groups.last.latest.id, 'x');
    expect(groups.last.isGrouped, isFalse);
  });

  test('mentions, handoffs, invites and emergencies are never collapsed', () {
    final groups = groupAlerts([
      n('m1', 'mention', channel: 'c'),
      n('m2', 'mention', channel: 'c'),
      n('h1', 'handoff_received', channel: 'c'),
      n('e1', 'emergency_alert', channel: 'c', title: 'EMERGENCY'),
      n('e2', 'emergency_alert', channel: 'c', title: 'EMERGENCY'),
      n('i1', 'space_invite'),
      n('msg1', 'new_message', channel: 'c'),
      n('msg2', 'new_message', channel: 'c'),
    ]);
    expect(groups.map((g) => g.count), [1, 1, 1, 1, 1, 1, 2]);
  });

  test('alerts without a chat stay individual', () {
    final groups = groupAlerts([n('a', 'new_message'), n('b', 'new_message')]);
    expect(groups.length, 2);
  });
}
