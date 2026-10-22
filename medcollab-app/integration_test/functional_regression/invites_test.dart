import 'dart:io';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'support/device_harness.dart';
import 'support/provider_inputs.dart';

Future<XFile> qrInput(String text) async {
  final bytes = await QrPainter(
          data: text,
          version: QrVersions.auto,
          color: Colors.black,
          emptyColor: Colors.white)
      .toImageData(400);
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/synthetic-invite.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  return XFile(file.path);
}

void main() {
  deviceMain();
  if (devicePhase != 'invites')
    throw DeviceInfrastructureError('Unknown invite phase');
  deviceCase('FR-LINK-04', (tester) async {
    await initializeDevice();
    await deviceStorage.clearAll();
    final picker = DeviceImagePicker();
    final camera = DeviceCamera();
    ImagePickerPlatform.instance = picker;
    CameraPlatform.instance = camera;
    await control('camera-permission', {'granted': false});
    await launch(tester, session: 'C', entryRoute: AppRoutes.scanInviteQr);
    final f = await fixture();
    final invites = (f['invites'] as List).cast<Map>();
    final first = invites[0];
    deps.appRouter.router.go(AppRoutes.scanInviteQr);
    await until(
        tester,
        () => find.text('Camera unavailable').evaluate().isNotEmpty,
        'denied camera input has a recoverable scanner state');
    expect((await control('camera-permission-state'))['granted'], false);
    picker.inputs.add(null);
    await tester.tap(find.text('From photo'));
    await tester.pumpAndSettle();
    expect(deps.appRouter.router.state.uri.path, AppRoutes.scanInviteQr);
    expect(
        (await control('membership',
            {'spaceId': first['spaceId'], 'label': 'C'}))['member'],
        false);
    await tester.tap(find.text('Pause live scan'));
    await tester.pump();
    await control('camera-permission', {'granted': true});
    camera.denied = false;
    camera.frame =
        (await qrInput('https://vocle.synthetic.invalid/join/${first['code']}'))
            .path;
    await tester.tap(find.text('Resume live scan'));
    await until(
        tester,
        () =>
            deps.appRouter.router.state.uri.path ==
            AppRoutes.joinInvitePath(first['code'] as String),
        'live scanner decodes the injected QR frame after permission recovery');
    await until(
        tester,
        () => find.text(first['name'] as String).evaluate().isNotEmpty,
        'preview loads from real local API');
    expect(
        (await control('membership',
            {'spaceId': first['spaceId'], 'label': 'C'}))['member'],
        false,
        reason: 'Preview must not join automatically');
    await tester.tap(find.widgetWithText(FilledButton, 'Join space'));
    await until(
        tester,
        () =>
            deps.appRouter.router.state.uri.path ==
            AppRoutes.spaceDetailPath(first['spaceId'] as String),
        'joined response opens its actual space');
    expect(
        (await control('membership',
            {'spaceId': first['spaceId'], 'label': 'C'}))['member'],
        true);

    // Raw code, full link and screenshot QR all flow through the actual page.
    for (var index = 1; index < 4; index++) {
      final invite = invites[index];
      camera.denied = true;
      deps.appRouter.router.go(AppRoutes.scanInviteQr);
      await until(tester, () => find.text('From photo').evaluate().isNotEmpty,
          'scanner remounts');
      if (index == 3) {
        picker.inputs.add(await qrInput(invite['code'] as String));
        await tester.tap(find.text('From photo'));
      } else {
        final raw = index == 1
            ? invite['code'] as String
            : 'https://vocle.synthetic.invalid/join/${invite['code']}';
        await tester.enterText(find.byType(TextField), raw);
        await tester.tap(find.text('Continue'));
      }
      await until(
          tester,
          () => find.text(invite['name'] as String).evaluate().isNotEmpty,
          'supported code reaches its preview');
      expect(
          (await control('membership',
              {'spaceId': invite['spaceId'], 'label': 'C'}))['member'],
          false);
      await tester.tap(find.widgetWithText(FilledButton, 'Join space'));
      await until(
          tester,
          () =>
              deps.appRouter.router.state.uri.path ==
              AppRoutes.spaceDetailPath(invite['spaceId'] as String),
          'explicit join opens the corresponding member space');
      expect(
          (await control('membership',
              {'spaceId': invite['spaceId'], 'label': 'C'}))['member'],
          true);
    }

    final pending = f['pendingInvite'] as Map;
    deps.appRouter.router
        .go(AppRoutes.joinInvitePath(pending['code'] as String));
    await until(
        tester,
        () => find.text(pending['name'] as String).evaluate().isNotEmpty,
        'approval space preview loads');
    await tester.tap(find.widgetWithText(FilledButton, 'Join space'));
    final state = await control(
        'await-pending', {'spaceId': pending['spaceId'], 'label': 'C'});
    expect(state['member'], false);
    expect(state['pendingCount'], 1);
    await tester.pump();
    expect(find.text('Joined ${pending['name']}'), findsNothing);
    observations.add(
        'Live/screenshot QR, raw code and full link decoded; cancel/preview do not join; native camera deny/grant controlled; accepted membership persisted.');
    observations.add(
        'Approval request persisted once without membership; current mounted pending response recorded, Q14 unresolved.');
    await cleanupDevice(tester);
    throw DeviceDecision(
        'Q14: pending approval presentation remains unresolved; safe membership and request assertions verified.');
  });
}
