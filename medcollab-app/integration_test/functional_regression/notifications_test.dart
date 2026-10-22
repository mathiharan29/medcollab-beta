import 'dart:convert';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/notifications/fcm_service.dart';
import 'package:medcollab_app/core/notifications/grouped_message_notification.dart';
import 'package:medcollab_app/core/notifications/notification_reply_sender.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/device_harness.dart';

void main() {
  deviceMain();
  if (devicePhase == 'notification-grouping') {
    deviceCase('FR-PUSH-05', (tester) async {
      await initializeDevice();
      await deviceStorage.clearAll();
      await control('notification-permission', {'granted': true});
      deviceMessaging.granted = true;
      await launch(tester, session: 'A', firebase: true, currentChat: true);
      await GroupedMessageNotification.plugin.cancelAll();
      final f = await fixture();
      final channel = chatId(f);
      final other = f['otherChannelId'] as String;
      final first = RemoteMessage(data: {
        'type': 'message',
        'channelId': channel,
        'spaceId': f['spaceId'],
        'title': 'Synthetic peer',
        'body': 'Synthetic grouped one'
      });
      final second =
          RemoteMessage(data: {...first.data, 'body': 'Synthetic grouped two'});
      final third = RemoteMessage(data: {
        ...first.data,
        'channelId': other,
        'body': 'Synthetic other channel'
      });
      await firebaseMessagingBackgroundHandler(first);
      await firebaseMessagingBackgroundHandler(second);
      await firebaseMessagingBackgroundHandler(third);
      var notifications =
          await GroupedMessageNotification.plugin.getActiveNotifications();
      final shadeDeadline = Stopwatch()..start();
      while ((!notifications.any((entry) => entry.tag == channel) ||
              !notifications.any((entry) => entry.tag == other)) &&
          shadeDeadline.elapsed < const Duration(seconds: 10)) {
        await tester.pump(const Duration(milliseconds: 50));
        notifications = await GroupedMessageNotification.plugin.getActiveNotifications();
      }
      expect(notifications.where((n) => n.tag == channel).length, 1);
      expect(notifications.where((n) => n.tag == other).length, 1);
      expect(notifications.where((n) => n.tag == channel).single.body,
          'Synthetic grouped two');
      final prefs = await SharedPreferences.getInstance();
      final lines =
          jsonDecode(prefs.getString('vocle_notif_lines_$channel')!) as List;
      expect(lines.map((line) => line['text']).toList(),
          ['Synthetic grouped one', 'Synthetic grouped two']);
      expect(
          (jsonDecode(prefs.getString('vocle_notif_lines_$other')!) as List)
              .length,
          1);
      // This injects the provider's tap input through its public platform stream.
      FirebaseMessagingPlatform.onMessageOpenedApp.add(second);
      await until(
          tester,
          () =>
              deps.appRouter.router.state.uri.path ==
              AppRoutes.channelPath(f['spaceId'] as String, channel),
          'tap opens the exact conversation');
      await openChat(tester, channel);
      final before = await storedMessages(channel);
      const reply = 'Synthetic notification reply exactly once';
      await NotificationReplySender.send(NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'reply',
          input: reply,
          payload: jsonEncode(second.data)));
      final after = await storedMessages(channel);
      final committed =
          after.where((row) => row['content']['text'] == reply).toList();
      expect(committed.length, 1);
      expect(committed.single['senderId'], f['A']['userId']);
      expect(after.length, before.length + 1);
      final independentlyRead =
          await deps.messageRepository.getMessages(channel);
      expect(
          independentlyRead.messages
              .where((m) => m.id == committed.single['_id'])
              .length,
          1);
      observations.add(
          'Native shade has one tag per channel; grouped lines persist; injected tap routes exactly; native-token reply stores one backend message.');
      await GroupedMessageNotification.plugin.cancelAll();
      await cleanupDevice(tester);
    });
  } else if (devicePhase == 'notification-token') {
    deviceCase('FR-PUSH-06', (tester) async {
      await initializeDevice();
      await deviceStorage.clearAll();
      await control('notification-permission', {'granted': false});
      deviceMessaging.granted = false;
      deviceMessaging.token = 'synthetic-device-denied';
      await launch(tester, session: 'A', firebase: true, currentChat: true);
      await deps.fcmService.registerTokenWithBackend();
      expect(deviceMessaging.permissionStates.last, AuthorizationStatus.denied);
      final denied = await control(
          'token-state', {'label': 'A', 'token': 'synthetic-device-denied'});
      expect(denied['present'], false);
      final f = await fixture();
      await openChat(tester, chatId(f));
      expect(deps.authBloc.state.user?.id, f['A']['userId']);
      expect(find.byType(TextField), findsWidgets,
          reason: 'App remains usable while notifications are denied');
      await control('notification-permission', {'granted': true});
      deviceMessaging.granted = true;
      deviceMessaging.token = 'synthetic-device-first';
      await deps.fcmService.registerTokenWithBackend();
      expect(deviceMessaging.permissionStates.last,
          AuthorizationStatus.authorized);
      expect(
          (await control('token-state',
              {'label': 'A', 'token': 'synthetic-device-first'}))['present'],
          true);
      expect(await deps.secureStorage.getFcmToken(), 'synthetic-device-first');
      deviceMessaging.token = 'synthetic-device-refreshed';
      deviceMessaging.refresh.add(deviceMessaging.token!);
      final refreshed = await control(
          'await-token', {'label': 'A', 'token': deviceMessaging.token});
      expect(refreshed['present'], true);
      expect(
          await deps.secureStorage.getFcmToken(), 'synthetic-device-refreshed');
      await logout(tester);
      expect(
          (await control('token-state', {
            'label': 'A',
            'token': 'synthetic-device-refreshed'
          }))['present'],
          false);
      expect(deviceMessaging.tokenDeletes, greaterThanOrEqualTo(1));
      deviceMessaging.token = 'synthetic-device-relogin';
      await login(tester, 'A', resumeChat: true);
      expect(
          (await control('await-token',
              {'label': 'A', 'token': 'synthetic-device-relogin'}))['present'],
          true);
      observations.add(
          'Native permission deny/grant plus injected token inputs; denial remains usable; registration, refresh, logout removal and relogin verified in disposable DB.');
      await cleanupDevice(tester);
    });
  } else {
    throw DeviceInfrastructureError('Unknown notification phase');
  }
}
