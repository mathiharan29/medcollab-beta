import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/voice_note.dart';

import 'support/device_harness.dart';

const _talk = Key('needl-voice-talk');
const _timer = Key('needl-voice-timer');

Future<TestGesture> _hold(WidgetTester tester) async {
  final talk = find.byKey(_talk);
  await until(tester, () => talk.hitTestable().evaluate().isNotEmpty,
      'hold-to-talk is available');
  final gesture = await tester.startGesture(tester.getCenter(talk));
  await tester.pump(const Duration(milliseconds: 700));
  return gesture;
}

void main() {
  deviceMain();
  if (devicePhase == 'voice-handoff') {
    deviceCase('FR-HOF-24', _handoffCase);
    return;
  }
  if (devicePhase != 'voice-dm') {
    throw DeviceInfrastructureError('Unknown voice phase');
  }
  deviceCase('FR-VCE-14', (tester) async {
    await initializeDevice();
    await deviceStorage.clearAll();
    final dm = (await fixture())['voiceDmId'] as String;
    await control('microphone-permission', {'granted': false});
    // Needl Voice is a separate space (beta 11-18): entered from its own
    // list (Messages → Needl Voice), never from the text chat.
    await launch(tester, session: 'A', entryRoute: AppRoutes.voiceHub);
    final opener = find.byKey(Key('voice-hub-chat-$dm'));
    await until(tester, () => opener.hitTestable().evaluate().isNotEmpty,
        'the Needl Voice list offers the DM');
    await tester.tap(opener);
    final before = await control('media-counts', {'channelId': dm});

    final denied = await _hold(tester);
    await until(
        tester,
        () => find
            .text('Allow microphone access to talk in Needl Voice')
            .evaluate()
            .isNotEmpty,
        'denied OS permission is reported on the voice screen');
    await denied.up();
    expect(find.byKey(_timer), findsNothing);

    await control('microphone-permission', {'granted': true});
    final cancelled = await _hold(tester);
    await until(tester, () => find.byKey(_timer).evaluate().isNotEmpty,
        'granted OS permission starts native capture');
    await cancelled.moveBy(const Offset(-145, 0));
    await tester.pump();
    expect(find.text('Release to cancel'), findsOneWidget);
    await cancelled.up();
    await until(tester, () => find.byKey(_timer).evaluate().isEmpty,
        'slide-to-cancel ends the recording');
    expect(await control('media-counts', {'channelId': dm}), before,
        reason: 'Denied and discarded recordings cause no upload or send');

    final recording = await _hold(tester);
    await until(tester, () => find.byKey(_timer).evaluate().isNotEmpty,
        'the next recording can start after discard');
    final duration = Stopwatch()..start();
    await until(tester, () => duration.elapsedMilliseconds >= 1700,
        'record longer than the minimum duration');
    await recording.up();

    final received =
        (await control('voice-dm-received'))['message'] as Map<String, dynamic>;
    final id = received['_id'] as String;
    final content = received['content'] as Map<String, dynamic>;
    expect(content['voiceMode'], isTrue);
    expect(content['mimeType'], 'audio/wav');
    expect(content['durationMs'], greaterThanOrEqualTo(1000));
    expect(content['mediaUrl'], isNotEmpty);
    expect(content['transcriptStatus'], anyOf('done', 'unavailable'));
    if (content['transcriptStatus'] == 'done') {
      expect(content['transcript'], isNotEmpty);
    }
    final counts = await control('media-counts', {'channelId': dm});
    expect(counts['uploadRequests'], (before['uploadRequests'] as int) + 1);
    expect(counts['messageCount'], (before['messageCount'] as int) + 1);

    deps.appRouter.router.pop();
    await until(
        tester,
        () => find.byType(VoiceNoteBubble).evaluate().any(
            (element) => (element.widget as VoiceNoteBubble).messageId == id),
        'the same clip is visible on return to the DM');
    await tester.tap(opener);
    final clip = find.byKey(Key('needl-voice-clip-$id'));
    await until(tester, () => clip.hitTestable().evaluate().isNotEmpty,
        'reopening voice history loads the persisted clip');
    final play = find.descendant(
        of: clip, matching: find.byIcon(Icons.play_arrow_rounded));
    await tester.tap(play);
    await until(
        tester,
        () =>
            VoiceNotePlayback.instance.isPlaying &&
            VoiceNotePlayback.instance.position > Duration.zero,
        'the native player plays the recorded WAV and advances');
    deps.appRouter.router.pop();
    await until(tester, () => !VoiceNotePlayback.instance.isPlaying,
        'leaving Needl Voice stops the player');
    observations.add(
        'Captured one native DM clip; recipient history and replay verified.');
  });
}

Future<void> _handoffCase(WidgetTester tester) async {
  await initializeDevice();
  await deviceStorage.clearAll();
  final f = await fixture();
  final space = f['spaceId'] as String;
  final id = f['handoffId'] as String;
  await control('microphone-permission', {'granted': true});
  await launch(tester,
      session: 'A', entryRoute: AppRoutes.spaceHandoffDetailPath(space, id));
  final edit = find.text('Edit');
  await until(tester, () => edit.hitTestable().evaluate().isNotEmpty,
      'sender can edit the submitted handoff');
  await tester.tap(edit);

  Future<void> record(Finder field) async {
    final start = find.descendant(
      of: field,
      matching: find.byKey(const Key('handoff-voice-record')),
    );
    await until(tester, () => start.evaluate().isNotEmpty, 'voice field loads');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    final stop = find.descendant(
      of: field,
      matching: find.byKey(const Key('composer-action')),
    );
    await until(tester, () => stop.hitTestable().evaluate().isNotEmpty,
        'handoff recorder starts');
    final duration = Stopwatch()..start();
    await until(tester, () => duration.elapsedMilliseconds >= 1700,
        'record longer than the minimum handoff clip');
    await tester.tap(stop);
    final preview = find.descendant(
      of: field,
      matching: find.byKey(const Key('handoff-voice-player')),
    );
    await until(tester, () => preview.evaluate().isNotEmpty,
        'native clip uploads and the field displays a player',
        limit: const Duration(seconds: 45));
  }

  await record(find.byKey(const Key('shift-voice-note')));
  final editPatient = find.byTooltip('Edit patient');
  await tester.ensureVisible(editPatient);
  await tester.tap(editPatient);
  await tester.pumpAndSettle();
  await record(find.byKey(const Key('patient-voice-note')));
  final savePatient = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(savePatient);
  await tester.tap(savePatient);
  await tester.pumpAndSettle();
  final save = find.descendant(
    of: find.byType(AppBar),
    matching: find.widgetWithText(TextButton, 'Save'),
  );
  await until(
      tester,
      () => save.hitTestable().evaluate().length == 1 &&
          tester.widget<TextButton>(save).onPressed != null,
      'the submitted handoff can be saved after both uploads');
  await tester.tap(save);
  await until(tester, () => edit.hitTestable().evaluate().isNotEmpty,
      'saving returns to the handoff detail',
      limit: const Duration(seconds: 45));
  final delivery = await control('handoff-voice-received');
  final shift = delivery['shift'] as Map<String, dynamic>;
  final patient = delivery['patient'] as Map<String, dynamic>;
  expect(shift['url'], isNot(patient['url']));
  expect(shift['recordedBy'], (f['A'] as Map)['userId']);
  expect(patient['recordedBy'], shift['recordedBy']);

  await logout(tester);
  await login(tester, 'B');
  deps.appRouter.router.go(AppRoutes.spaceHandoffDetailPath(space, id));
  for (final url in [shift['url'], patient['url']]) {
    final player = find.byWidgetPredicate(
      (w) => w is VoiceNoteBubble && w.url == url,
    );
    await until(tester, () => player.evaluate().isNotEmpty,
        'receiver detail contains the exact saved voice clip');
    await tester.ensureVisible(player);
    await tester.pumpAndSettle();
    final play = find.descendant(
      of: player,
      matching: find.byIcon(Icons.play_arrow_rounded),
    );
    await tester.tap(play);
    final playback = VoiceNotePlayback.instance;
    final playingId = tester.widget<VoiceNoteBubble>(player).messageId;
    await until(
        tester,
        () =>
            playback.currentId == playingId &&
            playback.isPlaying &&
            playback.position > Duration.zero,
        'the receiver can play the attached audio');
  }
  await VoiceNotePlayback.instance.stopAll();
  observations.add(
      'Receiver loaded and played distinct native shift and patient recordings.');
}
