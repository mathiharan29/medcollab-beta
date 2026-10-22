import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'support/device_harness.dart';

void main() {
  deviceMain();
  if (devicePhase == 'resume') {
    deviceCase('FR-NAV-04', (tester) async {
      await initializeDevice();
      await deviceStorage.clearAll();
      await launch(tester, session: 'A', currentChat: true);
      final f = await fixture();
      final channel = chatId(f);
      await openChat(tester, channel);
      final trace = LifecycleTrace();
      WidgetsBinding.instance.addObserver(trace);
      addTearDown(() => WidgetsBinding.instance.removeObserver(trace));
      const draft = 'Synthetic resume draft';
      await tester.enterText(find.byType(TextField).last, draft);
      // Observe persistence rather than assuming the debounce has fired.
      final watch = Stopwatch()..start();
      while (await deps.draftMessageService.getDraft(channel) != draft &&
          watch.elapsed.inSeconds < 5) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(await deps.draftMessageService.getDraft(channel), draft);
      await control('outage', {'enabled': true});
      await until(tester, () => !deps.socketClient.isConnected,
          'local transport interruption reaches the app');
      final cycle =
          await control('background-resume', {'recoverTransport': true});
      expect(cycle['backgroundObserved'], true);
      expect(cycle['stoppedObserved'], true);
      expect(cycle['foregroundObserved'], true);
      observations.add('Observed native lifecycle: ${trace.states.map((state) => state.name).join(', ')}');
      await until(
          tester,
          () =>
              trace.states.contains(AppLifecycleState.paused) &&
              trace.states.last == AppLifecycleState.resumed,
          'native pause and resume are delivered');
      await until(tester, () => deps.socketClient.isConnected,
          'resume restores the real Socket.IO connection');
      expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller
              ?.text,
          draft);
      final reply =
          await peerMessage(channel, 'Synthetic resume peer response');
      await until(
          tester,
          () =>
              find.text('Synthetic resume peer response').evaluate().isNotEmpty,
          'current chat receives the independently created peer message');
      final rows = await storedMessages(channel);
      expect(rows.where((row) => row['_id'] == reply['messageId']).length, 1);
      expect(await deps.draftMessageService.getDraft(channel), draft);
      observations.add(
          'Native paused/resumed; transport recovered; exact peer ID persisted and displayed; draft retained.');
      await cleanupDevice(tester);
    });
  } else if (devicePhase == 'session-seed') {
    testWidgets('Native session seed prerequisite', (tester) async {
      await initializeDevice();
      await deviceStorage.clearAll();
      await nativeStorageProbe();
      await installSession('A');
      expect(await deviceStorage.hasSession(), true);
      expect(await deviceStorage.getUserId(),
          (await fixture())['A']['userId']);
      await checkpoint('session-seed', {'nativeSessionWritten': true});
    });
  } else if (devicePhase == 'session-restore') {
    testWidgets('Native session restore and failed API logout prerequisite',
        (tester) async {
      await initializeDevice();
      // No token/prefs writes before launch: these must come from the old process.
      expect(await deviceStorage.hasSession(), true);
      final f = await fixture();
      expect(await deviceStorage.getUserId(), f['A']['userId']);
      await launch(tester);
      expect(deps.authBloc.state.status, AuthStatus.authenticated);
      expect(deps.authBloc.state.user?.id, f['A']['userId']);
      expect(deps.appRouter.router.state.uri.path, AppRoutes.home);
      await control('logout-failure', {'enabled': true});
      await logout(tester);
      expect(deps.appRouter.router.state.uri.path, AppRoutes.phoneEntry);
      final fault = await control('logout-failure', {'enabled': false});
      expect(fault['injectedRequests'], greaterThanOrEqualTo(1));
      await checkpoint('session-restore', {
        'sessionRestoredFromPriorProcess': true,
        'failedApiLogoutRemovedNativeSession': true,
        'logoutFaultObserved': true
      });
      await cleanupDevice(tester);
    });
  } else if (devicePhase == 'session-empty') {
    deviceCase('FR-NAV-05', (tester) async {
      await initializeDevice();
      final f = await control('checkpoints');
      final phases = (f['checkpoints'] as List).cast<Map>();
      expect(phases.map((row) => row['phase']),
          containsAll(['session-seed', 'session-restore']));
      expect(phases.map((row) => row['processId']).toSet().length, 2);
      expect(phases.map((row) => row['processId']), isNot(contains(pid)));
      expect(await deviceStorage.hasSession(), false);
      expect(await deviceStorage.getAccessToken(), isNull);
      expect(await deviceStorage.getRefreshToken(), isNull);
      expect(await deviceStorage.getUserId(), isNull);
      await launch(tester);
      expect(deps.authBloc.state.status, AuthStatus.unauthenticated);
      expect(deps.appRouter.router.state.uri.path, AppRoutes.phoneEntry);
      await checkpoint(
          'session-empty', {'loggedOutRelaunchHasNoNativeSession': true});
      observations.add(
          'Two host force-stops; native encrypted session restored, cleared after API 503, and absent on next launch.');
      await cleanupDevice(tester);
    });
  } else {
    throw DeviceInfrastructureError('Unknown lifecycle phase $devicePhase');
  }
}
