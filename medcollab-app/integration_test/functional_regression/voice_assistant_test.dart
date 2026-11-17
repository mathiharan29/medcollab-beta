import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/handoffs/presentation/cubit/handoff_form_cubit.dart';
import 'package:medcollab_app/features/handoffs/presentation/pages/handoff_form_page.dart';
import 'package:medcollab_app/features/messages/presentation/pages/channel_chat_page.dart';
import 'package:medcollab_app/features/search/presentation/pages/global_search_page.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_cubit.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_launcher.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'support/device_harness.dart';

part 'voice_digital_cases.dart';

final _opener = find.byKey(const Key('open-voice-bot'));
final _panel = find.byType(VoiceBotPanel);
final _confirm = find.byKey(const Key('voicebot-confirm'));
const _speech = 'vocle/speech';
const _speechEvents = 'vocle/speech/events';
const _codec = StandardMethodCodec();

void main() {
  deviceMain();
  switch (devicePhase) {
    case 'assistant-chat':
      deviceCase('FR-AST-31', _live);
    case 'assistant-draft':
      deviceCase('FR-AST-32', _live);
    case 'assistant-negative':
      deviceCase('FR-AST-33', _live);
    case 'assistant-file':
      deviceCase('FR-AST-34', _file);
    case 'assistant-transcript':
      deviceCase('FR-AST-35', _transcript);
    case 'assistant-digital-chat':
      deviceCase('FR-AST-36', _digital);
    case 'assistant-digital-draft':
      deviceCase('FR-AST-37', _digital);
    case 'assistant-digital-negative':
      deviceCase('FR-AST-38', _digital);
    case 'assistant-digital-navigation':
      deviceCase('FR-AST-39', _digital);
    case 'assistant-digital-updates':
      deviceCase('FR-AST-40', _digital);
    default:
      throw DeviceInfrastructureError('Unknown Voice Assistant phase');
  }
}

Future<void> _launch(WidgetTester tester, {bool microphone = true}) async {
  await initializeDevice();
  await deviceStorage.clearAll();
  await launch(tester, session: 'A');
  if (microphone) await control('microphone-permission', {'granted': true});
  await until(tester, () => _opener.hitTestable().evaluate().length == 1,
      'the authenticated Home displays the Voice Assistant');
  expect(deps.authBloc.state.user?.id, _person(await fixture(), 'A'));
}

String _person(Map<String, dynamic> fixture, String label) =>
    (fixture[label] as Map)['userId'] as String;

String _route() => deps
    .appRouter.router.routerDelegate.currentConfiguration.last.matchedLocation;

VoiceBotCubit _cubit(WidgetTester tester) =>
    tester.element(_panel).read<VoiceBotCubit>();

Future<void> _returnHome(WidgetTester tester) async {
  deps.appRouter.router.go(AppRoutes.home);
  await tester.pump();
  // A failed attempt can leave the Home's modal open.
  if (_panel.hitTestable().evaluate().isNotEmpty) {
    Navigator.of(tester.element(_panel)).pop();
  }
  await until(
      tester,
      () =>
          _opener.hitTestable().evaluate().length == 1 &&
          _panel.evaluate().isEmpty,
      'return to Home with the previous speech session closed');
}

Future<void> _verifyMicrophone(String sample) async {
  final recorder = AudioRecorder();
  final captured = BytesBuilder();
  StreamSubscription<Uint8List>? subscription;
  try {
    final stream = await recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    ));
    subscription = stream.listen(captured.add);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final delivery =
        await control('assistant-audio', {'sample': sample, 'probe': true});
    _recordProbe({'microphoneProbeReplay': delivery});
    if (delivery['delivered'] != true) {
      throw DeviceInfrastructureError(
          'Virtual microphone RPC failed: ${delivery['error']}');
    }
    await recorder.stop();
    final input = ByteData.sublistView(captured.takeBytes());
    // Compare the early silence with the peak during replay. A successful
    // host RPC with a silent guest capture is still an audio delivery failure.
    int peak(int from, int to) {
      var value = 0;
      for (var offset = from; offset + 1 < to; offset += 2) {
        final sample = input.getInt16(offset, Endian.little).abs();
        if (sample > value) value = sample;
      }
      return value;
    }

    const quietBytes = 3200; // First 100 ms occurs before the RPC is sent.
    final enoughData = input.lengthInBytes >= 32000;
    final quiet = enoughData ? peak(0, quietBytes) : 0;
    final signal = enoughData ? peak(quietBytes, input.lengthInBytes) : 0;
    _recordProbe({
      'microphoneProbeBytes': input.lengthInBytes,
      'baselinePeak': quiet,
      'replayPeak': signal,
    });
    if (!enoughData || signal < 512 || signal < quiet * 3) {
      throw DeviceInfrastructureError(
          'Virtual microphone probe did not capture the replay above baseline');
    }
  } finally {
    await subscription?.cancel();
    await recorder.dispose();
  }
}

Future<void> _live(WidgetTester tester) async {
  await _launch(tester);
  final config = await control('assistant-samples');
  final samples = (config['samples'] as List).cast<Map<String, dynamic>>();
  final repetitions = config['repetitions'] as int;
  final f = await fixture();
  final caps = await deps.speechService.capabilities();
  observations.add(
      jsonEncode({'available': caps.available, 'onDevice': caps.onDevice}));
  String? probeFailure;
  try {
    await _verifyMicrophone(samples.first['id'] as String);
  } catch (error) {
    probeFailure = error.toString();
  }

  // Forward the real native method call and response unchanged, capturing only
  // the acknowledgement for startListening. Android owns the event channel.
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Map<String, Object?>? attempt;
  messenger.setMockMessageHandler(_speech, (message) async {
    final method = _codec.decodeMethodCall(message!).method;
    final current = attempt;
    if (method == 'startListening') {
      // EventChannel has already registered its inbound listener. Forward
      // each native event to that same listener after recording diagnostics.
      messenger.delegate.setMessageHandler(_speechEvents, (data) {
        if (current != null && data != null) {
          try {
            final event = _codec.decodeEnvelope(data);
            if (event is Map && event['type'] == 'final') {
              current['recognizedTranscript'] = event['text'];
            } else if (event is Map && event['type'] == 'error') {
              current['recognitionError'] = event['code'];
              current['recognitionDiagnostic'] = event['text'];
            }
          } on PlatformException catch (error) {
            current['recognitionError'] = error.code;
          }
        }
        return messenger.handlePlatformMessage(_speechEvents, data, null);
      });
    }
    final response = await messenger.delegate.send(_speech, message);
    if (method == 'startListening' && current != null) {
      try {
        if (response == null) throw MissingPluginException();
        _codec.decodeEnvelope(response);
        current['recognitionStart'] = 'acknowledged';
      } on PlatformException catch (error) {
        current['recognitionStart'] = error.code;
      } on MissingPluginException {
        current['recognitionStart'] = 'missing_plugin';
      }
    }
    return response;
  });
  var total = 0;
  var passed = 0;
  try {
    for (final sample in samples) {
      final count = sample['id'] == samples.first['id'] &&
              devicePhase != 'assistant-negative'
          ? repetitions
          : 1;
      for (var iteration = 1; iteration <= count; iteration++) {
        total++;
        final row = <String, Object?>{
          'layer': 'LIVE_AUDIO',
          'sample': sample['id'],
          'attempt': iteration,
          'intendedCommand': sample['phrase'],
          'expectedAction': sample['expectedResult'],
          'expectedTarget': sample['target'],
          'recognitionStart': 'not_started',
          'recognizedTranscript': null,
          'resolvedTarget': null,
          'actualAction': null,
          'confirmation': 'not_reached',
        };
        attempt = row;
        var category = 'audio_delivery';
        try {
          if (probeFailure != null)
            throw DeviceInfrastructureError(probeFailure);
          category = 'confirmation_state';
          await _returnHome(tester);
          final before = await control('assistant-state');
          await tester.tap(_opener);
          await until(tester, () => _panel.evaluate().length == 1,
              'Home opens the bot sheet');
          final bot = _cubit(tester);
          category = 'speech_recognition';
          await until(
              tester,
              () =>
                  row['recognitionStart'] != 'not_started' ||
                  bot.state.phase == VoiceBotPhase.error,
              'Android responds to startListening');
          expect(row['recognitionStart'], 'acknowledged');
          category = 'audio_delivery';
          _recordStart(row);
          final delivery =
              await control('assistant-audio', {'sample': sample['id']});
          row['delivery'] = delivery;
          if (delivery['delivered'] != true)
            throw DeviceInfrastructureError(
                'Audio replay failed: ${delivery['error']}');
          category = 'speech_recognition';
          await until(tester, () => bot.state.phase != VoiceBotPhase.listening,
              'Android provides a final transcript or error');
          row['recognitionFeedback'] = bot.state.message;
          // Error states can retain a partial; only a transition through
          // thinking carries text that the actual parser received.
          if (bot.state.phase == VoiceBotPhase.error &&
              !bot.state.message.contains(VoiceBotCubit.help)) {
            throw TestFailure(bot.state.message);
          }
          expect(bot.state.heard, isNotEmpty,
              reason: 'A final transcript reached the bot');
          expect(
              (row['recognizedTranscript'] as String?)?.trim(), bot.state.heard,
              reason: 'The final native speech event reached the Cubit');
          category = 'incorrect_transcript';
          _checkTranscript(sample['id'] as String, bot.state.heard);
          category = 'command_parsing';
          await until(tester, () => bot.state.phase != VoiceBotPhase.thinking,
              'interpretation completes');
          final proposal = bot.state.proposals.singleOrNull;
          row['parsedIntent'] = proposal?.runtimeType.toString();
          row['proposedAction'] = proposal?.title;
          row['recognitionFeedback'] = bot.state.message;
          expect(bot.state.usedAi, isFalse,
              reason: 'The isolated backend has no LLM');
          if (sample['id'] == 'missing-destination') {
            expect(proposal, isNull);
            expect(bot.state.phase, VoiceBotPhase.error);
            expect(bot.state.message, contains(VoiceBotCubit.help));
            expect(_route(), AppRoutes.home);
            expect(await control('assistant-state'), before);
            row['actualAction'] = 'Stayed on Home with unsupported feedback';
          } else if (sample['id'] == 'unknown') {
            expect(proposal, isA<ClarifyAction>());
            category = 'entity_resolution';
            expect((proposal as ClarifyAction).choices, isEmpty);
            expect(find.byKey(const Key('voicebot-clarify')), findsOneWidget);
            expect(_confirm, findsNothing);
            expect(_route(), AppRoutes.home);
            expect(await control('assistant-state'), before);
            row['actualAction'] = 'Stayed on Home with no target choices';
          } else {
            final label =
                sample['target'] is String ? sample['target'] as String : 'E';
            if (sample['id'] == 'ambiguous') {
              category = 'entity_resolution';
              expect(proposal, isA<ClarifyAction>());
              final choices = (proposal as ClarifyAction)
                  .choices
                  .map((target) => target.rawId)
                  .toSet();
              row['choices'] = choices.toList()..sort();
              expect(choices, {_person(f, 'D'), _person(f, 'E')});
              expect(_confirm, findsNothing);
              expect(await control('assistant-state'), before);
              final key =
                  find.byKey(Key('voicebot-choice-p:${_person(f, label)}'));
              await tester.ensureVisible(key);
              await tester.tap(key);
              await tester.pump();
            }
            final action = bot.state.proposals.single;
            final draft = sample['expectedIntent'] == 'Handoff';
            category = 'command_parsing';
            expect(
                action, draft ? isA<HandoffAction>() : isA<OpenChatAction>());
            final target = draft
                ? (action as HandoffAction).to
                : (action as OpenChatAction).to;
            category = 'entity_resolution';
            row['resolvedTarget'] = target.rawId;
            expect(target.rawId, _person(f, label));
            category = 'confirmation_state';
            expect(_route(), AppRoutes.home);
            expect(await control('assistant-state'), before);
            await _tapConfirm(tester);
            row['confirmation'] = 'tapped';
            category = draft ? 'backend_persistence' : 'navigation';
            if (draft) {
              await _assertDraft(tester, f, before, row);
            } else {
              await _assertChat(tester, f, label, before, row);
            }
          }
          row['result'] = 'PASS';
          passed++;
        } catch (error) {
          row['result'] = probeFailure == null ? 'FAIL' : 'NOT_EXECUTED';
          row['failureCategory'] = category;
          row['error'] = error.toString();
          row['actualRoute'] = _route();
        } finally {
          _recordAttempt(row);
          attempt = null;
        }
      }
    }
  } finally {
    messenger.setMockMessageHandler(_speech, null);
    await _returnHome(tester);
  }
  if (probeFailure != null) throw DeviceInfrastructureError(probeFailure);
  observations.add(jsonEncode(
      {'passed': passed, 'attempted': total, 'successRate': passed / total}));
  expect(passed, total,
      reason: 'Every audio attempt must satisfy its own assertions');
}

void _recordAttempt(Map<String, Object?> row) {
  final encoded = jsonEncode(row);
  observations.add(encoded);
  // Keep completed attempts when the driver or a later attempt fails.
  // ignore: avoid_print
  print('VOCLE_VOICE_ATTEMPT $encoded');
}

void _recordStart(Map<String, Object?> row) {
  // A disconnected emulator can prevent the final attempt record from arriving.
  // ignore: avoid_print
  print('VOCLE_VOICE_ATTEMPT_START ${jsonEncode(row)}');
}

void _recordProbe(Map<String, Object?> row) {
  final encoded = jsonEncode(row);
  observations.add(encoded);
  // ignore: avoid_print
  print('VOCLE_VOICE_MIC_PROBE $encoded');
}

void _checkTranscript(String sample, String transcript) {
  final words =
      transcript.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  final pattern = switch (sample) {
    'chat-bala' ||
    'chat-with-bala' ||
    'chat-bala-noise' =>
      r'^open (?:(?:the )?chat with (?:dr |doctor )?bala|bala chat)$',
    'chat-bela' => r'^open bela chat$',
    'chat-with-alex' => r'^open chat with (?:dr|doctor) alex$',
    'draft-priya' ||
    'draft-priya-paused' =>
      r'^(?:draft (?:a )?)?hand ?off (?:for )?bed (?:7|seven) to priya$',
    'unknown' => r'^open zelda chat$',
    'ambiguous' => r'^open asha chat$',
    'missing-destination' => r'^create (?:a )?hand ?off for priya$',
    _ => throw StateError('Unknown sample $sample'),
  };
  expect(words, matches(RegExp(pattern)),
      reason: 'Final transcript for $sample');
}

Future<void> _tapConfirm(WidgetTester tester) async {
  expect(_confirm, findsOneWidget);
  await tester.ensureVisible(_confirm);
  await tester.tap(_confirm);
  await tester.pump();
}

Future<void> _assertChat(WidgetTester tester, Map<String, dynamic> f,
    String label, Map<String, dynamic> before, Map<String, Object?> row) async {
  final expectedDm = (f['voiceDms'] as Map)[label] as String;
  final chat = find.byType(ChannelChatPage).hitTestable();
  await until(
      tester, () => chat.evaluate().isNotEmpty, 'a conversation is visible');
  final ids = tester
      .widgetList<ChannelChatPage>(chat)
      .map((page) => page.channelId)
      .toList();
  row['actualAction'] = {'visibleChatIds': ids};
  expect(ids, [expectedDm]);
  expect(_route(), AppRoutes.dmPath(expectedDm));
  expect(await control('assistant-state'),
      {...before, 'dmOpens': (before['dmOpens'] as int) + 1});
}

Future<void> _assertDraft(WidgetTester tester, Map<String, dynamic> f,
    Map<String, dynamic> before, Map<String, Object?> row,
    {String recipient = 'C', List<String> beds = const ['7']}) async {
  final editor = find.byType(HandoffFormPage).hitTestable();
  await until(tester, () => editor.evaluate().isNotEmpty,
      'draft editor opens after creation');
  final page = tester.widget<HandoffFormPage>(editor);
  final form = find.descendant(
    of: editor,
    matching: find.byType(BlocProvider<HandoffFormCubit>),
  );
  await until(tester, () => form.evaluate().length == 1, 'persisted draft populates its form');
  final content = tester.widget<BlocProvider<HandoffFormCubit>>(form).child!;
  final formState = tester.element(find.byWidget(content)).read<HandoffFormCubit>().state;
  final after = await control('assistant-state');
  final oldIds =
      (before['drafts'] as List).map((draft) => (draft as Map)['id']).toSet();
  final drafts = (after['drafts'] as List)
      .where((draft) => !oldIds.contains((draft as Map)['id']))
      .toList();
  row['actualAction'] = {'editorId': page.handoffId, 'newDrafts': drafts};
  expect(formState.assignedDoctor?.id, _person(f, recipient));
  expect(formState.patients.map((patient) => patient.bedNumber), beds);
  expect(formState.isSent, isFalse);
  expect(drafts, [
    {
      'id': page.handoffId,
      'toUserId': _person(f, recipient),
      'channelId': f['channelId'],
      'spaceId': f['spaceId'],
      'status': 'draft',
      'shiftType': 'night',
      'summary': '',
      'beds': beds,
      'aliases': [for (final bed in beds) 'Bed $bed'],
    }
  ]);
  expect(page.spaceId, f['spaceId']);
  expect(
      _route(), AppRoutes.spaceHandoffEditPath(page.spaceId, page.handoffId!));
  expect({...after, 'drafts': before['drafts']}, before,
      reason:
          'The voice draft must never submit, notify, send a message or open a DM');
}

Future<void> _file(WidgetTester tester) async {
  await _launch(tester);
  final timer = Stopwatch()..start();
  final file = File(
      '${(await getTemporaryDirectory()).path}/vocle-regression-speech.wav');
  final row = <String, Object?>{
    'layer': 'PRERECORDED_FILE',
    'sample': 'chat-bala',
    'intendedCommand': 'Open Bala chat.',
    'expectedAction': 'Open the existing Bala DM after confirmation',
  };
  var recognizerCalled = false;
  try {
    final clip = await control('assistant-file');
    final digital = clip['digitalRecognition'] as Map<String, dynamic>?;
    final String? transcript;
    if (digital != null) {
      // The host validated a real final result and its silence control from
      // Android on this emulator. The test passes the raw result to Vocle.
      row['sample'] = digital['sample'];
      row['intendedCommand'] = digital['phrase'];
      row['expectedAction'] = 'Open the existing Alex DM after confirmation';
      row['nativeRecognition'] = digital;
      row['recognitionStart'] = 'verified_android_digital_file_input';
      row['sha256'] = digital['wavSha256'];
      row['pcmSha256'] = digital['pcmSha256'];
      row['expectedIntent'] = 'OpenChat';
      row['recognitionError'] = 0;
      row['recognitionSuccess'] = true;
      row['transcriptMatched'] = true;
      recognizerCalled = true;
      transcript = digital['transcript'] as String;
    } else {
      final caps = await deps.speechService.capabilities();
      if (!caps.fileInput) {
        throw DeviceInfrastructureError('Android file recognition unavailable');
      }
      await file.writeAsBytes(base64Decode(clip['wav'] as String));
      recognizerCalled = true;
      row['recognitionStart'] = 'file_input_invoked';
      _recordStart(row);
      transcript = await deps.speechService.transcribeFile(file.path);
    }
    row['recognizedTranscript'] = transcript;
    expect(transcript, isNotNull,
        reason: 'Android must recognize the supplied digital file');
    _checkTranscript(row['sample'] as String, transcript!);
    final before = await control('assistant-state');
    unawaited(openVoiceBot(tester.element(_opener), listen: false));
    await until(tester, () => _panel.evaluate().length == 1,
        'bot opens without live capture');
    final bot = _cubit(tester);
    await bot.handleText(transcript);
    await tester.pump();
    final action = bot.state.proposals.single as OpenChatAction;
    final f = await fixture();
    row['resolvedTarget'] = action.to.rawId;
    row['expectedTarget'] = _person(f, 'B');
    row['parsedIntent'] = 'OpenChat';
    row['intentCorrect'] = true;
    row['entityCorrect'] = row['resolvedTarget'] == row['expectedTarget'];
    expect(action.to.rawId, _person(f, 'B'));
    expect(await control('assistant-state'), before);
    await _tapConfirm(tester);
    await _assertChat(tester, f, 'B', before, row);
    if (digital != null) await _digitalScreenshot(row);
    row['result'] = 'PASS';
  } catch (error) {
    row['result'] = recognizerCalled ? 'FAIL' : 'NOT_EXECUTED';
    row['error'] = error.toString();
    rethrow;
  } finally {
    row['durationMs'] = timer.elapsedMilliseconds;
    _recordAttempt(row);
    if (await file.exists()) await file.delete();
  }
}

Future<void> _transcript(WidgetTester tester) async {
  await _launch(tester, microphone: false);
  final f = await fixture();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // Replace only Android speech IO. The normal Flutter adapter, launcher,
  // directory, proposal UI, router and authenticated repositories run as-is.
  for (final channel in [_speech, _speechEvents]) {
    messenger.setMockMethodCallHandler(
        MethodChannel(channel), (_) async => null);
  }
  Future<VoiceBotState> say(String text) async {
    await tester.tap(_opener);
    await until(
        tester,
        () =>
            _panel.evaluate().length == 1 &&
            _cubit(tester).state.phase == VoiceBotPhase.listening,
        'Home accepts injected speech events');
    await messenger.handlePlatformMessage(_speechEvents,
        _codec.encodeSuccessEnvelope({'type': 'final', 'text': text}), null);
    await until(tester, () => _confirm.hitTestable().evaluate().length == 1,
        'a real confirmation card renders for the injected final');
    final state = _cubit(tester).state;
    expect(state.heard, text);
    return state;
  }

  try {
    final beforeChat = await control('assistant-state');
    final chat = (await say('Open Bala chat')).proposals.single as OpenChatAction;
    final chatRow = <String, Object?>{
      'layer': 'TRANSCRIPT_INJECTION',
      'transcript': 'Open Bala chat',
      'resolvedTarget': chat.to.rawId,
    };
    expect(chat.to.rawId, _person(f, 'B'));
    expect(await control('assistant-state'), beforeChat);
    await _tapConfirm(tester);
    await _assertChat(tester, f, 'B', beforeChat, chatRow);
    observations.add(jsonEncode(chatRow));
    await _returnHome(tester);

    final before = await control('assistant-state');
    final state = await say('Hand off bed 7 to Priya');
    final proposal = state.proposals.single as HandoffAction;
    final row = <String, Object?>{
      'layer': 'TRANSCRIPT_INJECTION',
      'transcript': state.heard,
      'resolvedTarget': proposal.to.rawId,
    };
    expect(proposal.to.rawId, _person(f, 'C'));
    expect(await control('assistant-state'), before);
    await _tapConfirm(tester);
    await _assertDraft(tester, f, before, row);
    observations.add(jsonEncode(row));
  } finally {
    for (final channel in [_speech, _speechEvents]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
  }
}
