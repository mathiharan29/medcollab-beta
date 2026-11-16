// Issue 14 (beta 11-14): hybrid voice bot flow — speech → parser / AI →
// confirm → execute. Nothing runs without confirmation.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/speech/speech_service.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_action_executor.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_cubit.dart';

const _bala = VoiceTarget(id: 'p:b', name: 'Dr Bala Krishnan');
const _asha1 =
    VoiceTarget(id: 'p:1', name: 'Dr Asha Rao', speciality: 'Cardiology');
const _asha2 =
    VoiceTarget(id: 'p:2', name: 'Dr Asha Rao', speciality: 'Nephrology');

class _Speech implements SpeechService {
  final events = StreamController<SpeechEvent>();
  final spoken = <String>[];
  @override
  Future<SpeechCapabilities> capabilities() async =>
      const SpeechCapabilities(available: true);
  @override
  Stream<SpeechEvent> listen({String language = 'en-IN'}) => events.stream;
  @override
  Future<void> stopListening() async {}
  int cancels = 0;
  @override
  Future<void> cancelListening() async => cancels++;
  @override
  Future<String?> transcribeFile(String wavPath,
          {String language = 'en-IN'}) async =>
      null;
  @override
  Future<void> speak(String text, {String language = 'en-IN'}) async =>
      spoken.add(text);
  @override
  Future<void> stopSpeaking() async {}
}

class _Exec implements VoiceActionExecutor {
  final done = <VoiceAction>[];
  Future<String>? result;
  @override
  Future<String> execute(VoiceAction action) async {
    done.add(action);
    if (result != null) return result!;
    return 'Done: ${action.title}';
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Speech speech;
  late _Exec exec;
  var aiCalls = 0;
  VoiceBotCubit make({bool ai = false}) => VoiceBotCubit(
        speech: speech,
        executor: exec,
        loadDirectory: () async =>
            const VoiceDirectory(people: [_bala, _asha1, _asha2]),
        aiAvailable: () async => ai,
        interpretWithAi: (t) async {
          aiCalls++;
          return [
            const SendMessageAction(to: _bala, text: 'Summary sent by AI')
          ];
        },
      );

  setUp(() {
    speech = _Speech();
    exec = _Exec();
    aiCalls = 0;
  });

  test('FR-AST-03 spoken command → confirm card → nothing runs until confirmed',
      () async {
    final c = make();
    await c.startListening();
    speech.events.add(const SpeechPartial('tell Bala'));
    await _settle();
    expect(c.state.heard, 'tell Bala');
    speech.events.add(const SpeechFinal('tell Bala bed 7 is stable'));
    await _settle();
    expect(c.state.phase, VoiceBotPhase.confirm);
    final card = c.state.proposals.single as SendMessageAction;
    expect(card.text, 'Bed 7 is stable');
    expect(exec.done, isEmpty, reason: 'never executes without a tap');
    expect(speech.spoken.single, contains('Send to Dr Bala Krishnan'));

    c.editText(card, 'Bed 7 is stable, BP 120/80');
    await c.confirm(c.state.proposals.single);
    expect((exec.done.single as SendMessageAction).text,
        'Bed 7 is stable, BP 120/80');
    expect(c.state.phase, VoiceBotPhase.done);
    await c.close();
  });

  test('FR-AST-04 ambiguous name → choose one → proposal for that person only',
      () async {
    final c = make();
    await c.handleText('tell Asha the echo is ready');
    final q = c.state.proposals.single as ClarifyAction;
    expect(q.choices, hasLength(2));
    c.choose(q, _asha2);
    final a = c.state.proposals.single as SendMessageAction;
    expect(a.to.id, 'p:2');
    await c.close();
  });

  test('FR-AST-05 AI half is used only when the local parser cannot understand',
      () async {
    final c = make(ai: true);
    await c.handleText('tell Bala bed 7 is stable');
    expect(aiCalls, 0, reason: 'handled privately on the phone');
    expect(c.state.usedAi, isFalse);

    await c
        .handleText('summarise what Bala said about bed 9 and send it to him');
    expect(aiCalls, 1);
    expect(c.state.usedAi, isTrue);
    expect(c.state.proposals.single, isA<SendMessageAction>());
    await c.close();
  });

  test('FR-AST-06 no AI configured → helpful hint, never a guess', () async {
    final c = make();
    await c.handleText('summarise the ward round');
    expect(c.state.phase, VoiceBotPhase.error);
    expect(c.state.message, contains('Try:'));
    expect(exec.done, isEmpty);
    await c.close();
  });

  test('FR-AST-07 speech errors become clear messages', () async {
    final c = make();
    await c.startListening();
    speech.events.add(const SpeechError('no_permission', 'x'));
    await _settle();
    expect(c.state.message, contains('microphone'));
    await c.close();
  });

  test(
      'FR-AST-08 typing while the mic is open ends listening; a late error cannot replace the card',
      () async {
    final c = make();
    await c.startListening();
    await c.handleText('tell Bala bed 7 is stable');
    expect(c.state.phase, VoiceBotPhase.confirm);
    await _settle();
    expect(speech.cancels, greaterThan(0), reason: 'recognizer left running');
    // The recognizer being torn down reports an error afterwards.
    speech.events.add(const SpeechError('error', 'error 5'));
    await _settle();
    expect(c.state.phase, VoiceBotPhase.confirm);
    expect(c.state.proposals.single, isA<SendMessageAction>());
    await c.close();
  });

  test('FR-AST-09 missing speech pack has its own message', () async {
    final c = make();
    await c.startListening();
    speech.events.add(const SpeechError('language', 'x'));
    await _settle();
    expect(c.state.message, contains('speech pack'));
    await c.close();
  });

  test('FR-AST-10 cancel a proposal', () async {
    final c = make();
    await c.handleText('mark all alerts as read');
    c.dismiss(c.state.proposals.single);
    expect(c.state.proposals, isEmpty);
    expect(exec.done, isEmpty);
    await c.close();
  });
  test(
      'FR-AST-22 configured provider failure leaves no proposal and local commands recover',
      () async {
    final c = VoiceBotCubit(
      speech: speech,
      executor: exec,
      loadDirectory: () async => const VoiceDirectory(people: [_bala]),
      aiAvailable: () async => true,
      interpretWithAi: (_) async =>
          throw StateError('synthetic provider outage'),
    );
    addTearDown(c.close);

    await c.handleText('summarise the ward round');
    expect(c.state.phase, VoiceBotPhase.error);
    expect(c.state.proposals, isEmpty);
    expect(c.state.message, contains('Try:'));
    expect(exec.done, isEmpty);

    await c.handleText('hand off bed 7 to Bala');
    expect(c.state.phase, VoiceBotPhase.confirm);
    final action = c.state.proposals.single as HandoffAction;
    expect(action.to.id, _bala.id);
    expect(action.patients.single.bed, '7');
    expect(exec.done, isEmpty);
    c.dismiss(action);
    expect(c.state.phase, VoiceBotPhase.idle);
    expect(exec.done, isEmpty);
  });
  testWidgets(
      'FR-AST-25 repeated taps while Send is pending do not duplicate a write',
      (tester) async {
    final pending = Completer<String>();
    exec.result = pending.future;
    final c = make();
    addTearDown(c.close);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(value: c, child: const VoiceBotPanel()),
      ),
    ));
    await c.handleText('tell Bala the check is complete');
    await tester.pumpAndSettle();
    final send = find.byKey(const Key('voicebot-confirm'));
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pump();
    expect(c.state.phase, VoiceBotPhase.working);
    expect(exec.done, hasLength(1));
    await tester.tap(send, warnIfMissed: false);
    await tester.pump();
    pending.complete('Sent to Bala.');
    await tester.pumpAndSettle();
    expect(c.state.phase, VoiceBotPhase.done);
    expect(exec.done, hasLength(1),
        reason: 'One proposal can produce only one write');
  });
}
