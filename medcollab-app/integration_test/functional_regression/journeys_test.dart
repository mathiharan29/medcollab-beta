import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'support/device_harness.dart';

void main() {
  deviceMain();
  if (devicePhase == 'chat-journey') {
    deviceCase('FR-JRN-05', (tester) async {
      await initializeDevice();
      await deviceStorage.clearAll();
      await launch(tester, session: 'A', currentChat: true);
      final f = await fixture();
      final channel = chatId(f);
      await openChat(tester, channel);
      const text = 'Synthetic device journey committed draft';
      await tester.enterText(find.byType(TextField).last, text);
      final watch = Stopwatch()..start();
      while (await deps.draftMessageService.getDraft(channel) != text &&
          watch.elapsed.inSeconds < 5) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(await deps.draftMessageService.getDraft(channel), text);
      await control('outage', {'enabled': true});
      await until(tester, () => !deps.socketClient.isConnected,
          'transport is unavailable before background');
      final cycle =
          await control('background-resume', {'recoverTransport': true});
      expect(cycle['backgroundObserved'], true);
      expect(cycle['foregroundObserved'], true);
      await until(tester, () => deps.socketClient.isConnected,
          'resume restores local transport');
      expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller
              ?.text,
          text);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await until(
          tester,
          () =>
              find.text(text).evaluate().isNotEmpty &&
              find.byIcon(Icons.send_rounded).evaluate().isNotEmpty,
          'committed draft renders');
      final committed =
          await control('await-message', {'channelId': channel, 'text': text});
      final committedId = committed['messageId'];
      expect(
          (await storedMessages(channel))
              .where((row) => row['_id'] == committedId)
              .length,
          1);
      expect(
          (await storedMessages(channel))
              .where((row) => row['content']['text'] == text)
              .length,
          1);
      final peer =
          await peerMessage(channel, 'Synthetic device journey peer reply');
      await until(
          tester,
          () => find
              .text('Synthetic device journey peer reply')
              .evaluate()
              .isNotEmpty,
          'subscribed app receives correlated peer reply');
      expect(
          (await storedMessages(channel))
              .where((row) => row['_id'] == peer['messageId'])
              .length,
          1);
      deps.appRouter.router.go(AppRoutes.messages);
      await tester.pump();
      await openChat(tester, channel);
      await until(tester, () => find.text(text).evaluate().isNotEmpty,
          'refetch reloads committed message');
      expect(find.text(text), findsOneWidget);
      expect(find.text('Synthetic device journey peer reply'), findsOneWidget);
      expect(await deps.draftMessageService.getDraft(channel), isNull);
      await logout(tester);
      await login(tester, 'A', resumeChat: true);
      await openChat(tester, channel);
      await until(tester, () => find.text(text).evaluate().isNotEmpty,
          'relogin reloads committed content');
      expect(find.text(text), findsOneWidget);
      expect(find.text('Synthetic device journey peer reply'), findsOneWidget);
      final page = await deps.messageRepository.getMessages(channel);
      expect(page.messages.where((message) => message.id == committedId).length,
          1);
      observations.add(
          'Native draft persistence, background transport outage, UI send, real peer Socket.IO reply, refetch and same-account relogin with one committed ID.');
      await cleanupDevice(tester);
    });
  } else if (devicePhase == 'handoff-seed') {
    testWidgets('Cold handoff prerequisite clears the native session',
        (tester) async {
      await initializeDevice();
      await deviceStorage.clearAll();
      expect(await deviceStorage.hasSession(), false);
      final f = await fixture();
      final state = await control('handoff-state');
      expect(state['handoff']['status'], 'submitted');
      expect(state['handoff']['toUserId'], f['B']['userId']);
      await checkpoint(
          'handoff-seed', {'loggedOut': true, 'handoffId': f['handoffId']});
    });
  } else if (devicePhase == 'handoff-cold') {
    deviceCase('FR-JRN-06', (tester) async {
      final f = await fixture();
      final checkpoints = (await control('checkpoints'))['checkpoints'] as List;
      expect(
          checkpoints.where((row) => row['phase'] == 'handoff-seed').length, 1);
      await initializeDevice(
          initialMessage: RemoteMessage(data: {
        'type': 'handoff_received',
        'spaceId': f['spaceId'],
        'handoffId': f['handoffId'],
        'title': 'Synthetic handoff',
        'body': 'Synthetic cold-start handoff'
      }));
      await control('notification-permission', {'granted': false});
      expect(await deviceStorage.hasSession(), false);
      await launch(tester, firebase: true);
      expect(deviceMessaging.initialReads, 1);
      expect(deps.authBloc.state.status, AuthStatus.unauthenticated);
      expect(deps.appRouter.router.state.uri.path, AppRoutes.phoneEntry);
      await login(tester, 'B');
      final target = AppRoutes.spaceHandoffDetailPath(
          f['spaceId'] as String, f['handoffId'] as String);
      await until(tester, () => deps.appRouter.router.state.uri.path == target,
          'cold notification survives startup and login and opens its exact handoff');
      await until(
          tester,
          () => find.text('Synthetic device patient').evaluate().isNotEmpty,
          'patient and correct assignee handoff are mounted');
      expect(deps.authBloc.state.user?.id, f['B']['userId']);
      expect(find.text('Synthetic device patient'), findsOneWidget);
      final detail =
          await deps.handoffRepository.getHandoffById(f['handoffId'] as String);
      expect(detail.toUser.id, f['B']['userId']);
      expect(detail.patients.single.clinicalAlias, 'Synthetic device patient');
      await control('listen-ack'); // Register sender listener before UI action.
      await tester.tap(find.text('Acknowledge handoff'));
      await tester.pump();
      if (find.text('Acknowledge handoff').evaluate().isNotEmpty) {
        await tester.tap(find.text('Acknowledge handoff'), warnIfMissed: false);
      }
      final stored = await control('await-ack');
      expect(stored['handoff']['status'], 'acknowledged');
      expect(stored['handoff']['toUserId'], f['B']['userId']);
      expect(stored['handoff']['patients'].single['clinicalAlias'],
          'Synthetic device patient');
      expect(stored['acknowledgeRequests'], 1);
      expect(stored['senderNotificationCount'], 1);
      expect(stored['senderEventHandoffIds'], contains(f['handoffId']));
      final sender = await control('sender-handoff');
      expect(sender['handoff']['status'], 'acknowledged');
      expect(sender['handoff']['patients'].single['clinicalAlias'],
          'Synthetic device patient');
      observations.add(
          'Host force-stop, injected cold notification, required login, exact patient/assignee, UI acknowledgement, sender event and persisted receipt.');
      await checkpoint('handoff-cold', {'correctHandoffAcknowledged': true});
      await cleanupDevice(tester);
    });
  } else {
    throw DeviceInfrastructureError(
        'Unknown device journey phase $devicePhase');
  }
}
