import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

void main() {
  group('Needl / group DM classification', () {
    ChannelModel dm({
      required List<UserModel> members,
      String? spaceId,
      bool isNeedl = false,
    }) {
      return ChannelModel(
        id: 'c1',
        name: 'chat',
        type: ChannelType.direct,
        spaceId: spaceId,
        members: members,
        isNeedl: isNeedl,
      );
    }

    UserModel u(String id) => UserModel(id: id, name: 'Dr $id');

    test('1:1 is not a Needl', () {
      final channel = dm(members: [u('a'), u('b')]);
      expect(channel.isGroupDm, isFalse);
    });

    test('3+ members is a Needl', () {
      final channel = dm(members: [u('a'), u('b'), u('c')]);
      expect(channel.isGroupDm, isTrue);
    });

    test('server isNeedl flag wins even if members sparsely parsed', () {
      final channel = dm(members: [u('a')], isNeedl: true);
      expect(channel.isGroupDm, isTrue);
    });

    test('space channels never count as Needl', () {
      final channel = dm(
        members: [u('a'), u('b'), u('c')],
        spaceId: 'space-1',
        isNeedl: true,
      );
      expect(channel.isGroupDm, isFalse);
    });
  });

  group('Alerts Channels filter', () {
    AppNotificationModel note({
      required String type,
      String? spaceId,
      String? channelId,
    }) {
      return AppNotificationModel(
        id: 'n1',
        type: type,
        title: 't',
        body: 'b',
        read: false,
        metadata: NotificationMetadata(
          spaceId: spaceId,
          channelId: channelId,
        ),
      );
    }

    test('Channels keeps space traffic and drops DM-only messages', () {
      final spaceMsg = note(
        type: 'new_message',
        spaceId: 's1',
        channelId: 'ch1',
      );
      final dmMsg = note(type: 'new_message', channelId: 'dm1');
      final mention = note(type: 'mention', spaceId: 's1');

      final state = NotificationsState(
        notifications: [spaceMsg, dmMsg, mention],
        filter: NotificationFilter.channels,
      );

      expect(state.visible, [spaceMsg]);
    });
  });
}
