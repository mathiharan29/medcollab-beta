// Beta round 11-18: tester's voice findings + Assistant enhancements.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/speech/speech_service.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/chat_wallpaper.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_action_executor.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_command_parser.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_help.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_cubit.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_sheet.dart';

const _bala = VoiceTarget(id: 'p:b', name: 'Dr Bala Krishnan');
const _alex = VoiceTarget(id: 'p:a', name: 'Dr Alex Moreno');
const _priya = VoiceTarget(id: 'p:p', name: 'Dr Priya Nair');
const _morgan = VoiceTarget(id: 'p:m', name: 'Dr Morgan Lee');
const _general = VoiceTarget(id: 'c:g', name: 'Cedar Ward #general', kind: 'group', spaceId: 's1');
const _dir = VoiceDirectory(people: [_bala, _alex, _priya, _morgan], chats: [_general]);

class _Speech implements SpeechService {
  StreamController<SpeechEvent> events = StreamController<SpeechEvent>();
  final spoken = <String>[];
  int listens = 0;
  @override
  Future<SpeechCapabilities> capabilities() async => const SpeechCapabilities(available: true);
  @override
  Stream<SpeechEvent> listen({String language = 'en-IN'}) {
    listens++;
    events = StreamController<SpeechEvent>();
    return events.stream;
  }

  @override
  Future<void> stopListening() async {}
  @override
  Future<void> cancelListening() async {}
  @override
  Future<String?> transcribeFile(String wavPath, {String language = 'en-IN'}) async => null;
  @override
  Future<void> speak(String text, {String language = 'en-IN'}) async => spoken.add(text);
  @override
  Future<void> stopSpeaking() async {}
}

class _Exec implements VoiceActionExecutor {
  final done = <VoiceAction>[];
  @override
  Future<String> execute(VoiceAction action) async {
    done.add(action);
    return 'Done: ${action.title}';
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  final parser = VoiceCommandParser(_dir);

  group('parser (field findings 2, 4, 6, 7)', () {
    test('handoff: extra words after the name are reported, never put in the summary', () {
      final a = parser.parse('hand off bed 12 to Alex the sky').actions.single as HandoffAction;
      expect(a.to, _alex);
      expect(a.patients.single.bed, '12');
      expect(a.summary, isEmpty);
      expect(a.unclear.single, contains('the sky'));
    });

    test('handoff: "at 12:00" is a time, not a bed — no bed guessed, flagged', () {
      final a = parser.parse('handoff at 12:00 to Alex').actions.single as HandoffAction;
      expect(a.patients, isEmpty);
      expect(a.unclear.single, contains('12:00'));
    });

    test('handoff: spoken numbers, several beds, explicit summary', () {
      final a = parser.parse('hand off beds twelve and 4 to Priya, saying stable overnight').actions.single
          as HandoffAction;
      expect(a.patients.map((p) => p.bed), ['12', '4']);
      expect(a.summary, 'Stable overnight');
      expect(a.unclear, isEmpty);
    });

    test('channel alias "General" resolves directly when unique', () {
      final a = parser.parse('open chat with General').actions.single;
      expect(a, isA<OpenChatAction>());
      expect((a as OpenChatAction).to, _general);
    });

    test('verb lost by the recogniser: "conversation with Dr Morgan" opens the chat', () {
      final a = parser.parse('conversation with Dr Morgan').actions.single as OpenChatAction;
      expect(a.to, _morgan);
    });

    test('"take me to the chat with Bala" is the same command', () {
      expect((parser.parse('take me to the chat with Bala').actions.single as OpenChatAction).to, _bala);
    });

    test('status phrasing variants map to a status only when one is named', () {
      expect((parser.parse("that's my status long rounds").actions.single as SetAvailabilityAction).status,
          'on_rounds');
      expect((parser.parse('change my status to in OT').actions.single as SetAvailabilityAction).status, 'in_ot');
      expect(parser.parse('what is my status').understood, isFalse);
    });

    test('unknown name: no suggestions (no guessing), explicit pick rebuilds the request', () {
      final q = parser.parse('tell mama that the check is complete').actions.single as ClarifyAction;
      expect(q.unmatched, isTrue);
      expect(q.choices, isEmpty);
      final rebuilt = q.rebuild!(_bala) as SendMessageAction;
      expect(rebuilt.to, _bala);
      expect(rebuilt.text, 'The check is complete');
    });

    test('"show my conversation with Bala" (background-style speech) proposes nothing', () {
      final r = parser.parse('Show my conversation with Bala');
      expect(r.actions.whereType<OpenChatAction>(), isEmpty);
    });
  });

  group('cubit', () {
    late _Speech speech;
    late _Exec exec;
    setUp(() {
      speech = _Speech();
      exec = _Exec();
    });

    VoiceBotCubit make({
      Future<MicAccess> Function()? mic,
      Duration timeout = const Duration(seconds: 30),
      Future<List<VoiceAction>> Function(String, List<VoiceTurn>)? ai,
      List<List<String>>? hints,
    }) =>
        VoiceBotCubit(
          speech: speech,
          executor: exec,
          loadDirectory: () async => _dir,
          ensureMic: mic,
          noResultTimeout: timeout,
          aiAvailable: () async => ai != null,
          interpretInConversation: ai,
          biasRecognizer: hints == null ? null : (h) => hints.add(h),
          clock: () => DateTime(2026, 11, 18, 14, 5),
        );

    test('microphone denied: clear message, nothing listens', () async {
      final c = make(mic: () async => MicAccess.denied);
      await c.startListening();
      expect(c.state.phase, VoiceBotPhase.error);
      expect(c.state.mic, MicAccess.denied);
      expect(c.state.message, contains('microphone'));
      expect(speech.listens, 0);
      await c.close();
    });

    test('microphone blocked: points to Settings', () async {
      final c = make(mic: () async => MicAccess.blocked);
      await c.startListening();
      expect(c.state.mic, MicAccess.blocked);
      expect(c.state.message, contains('Settings'));
      await c.close();
    });

    test('granted: listens and biases the recogniser towards colleague names', () async {
      final hints = <List<String>>[];
      final c = make(mic: () async => MicAccess.granted, hints: hints);
      await c.startListening();
      await _settle();
      expect(speech.listens, 1);
      expect(hints.single, containsAll(['Bala Krishnan', 'Alex Moreno']));
      await c.close();
    });

    test('stalled recogniser: visible timeout, and a late result is ignored (finding 8)', () async {
      final c = make(timeout: const Duration(milliseconds: 40));
      await c.startListening();
      final stale = speech.events;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.state.phase, VoiceBotPhase.error);
      expect(c.state.message, contains('Nothing was done'));
      stale.add(const SpeechFinal('open chat with Bala'));
      await _settle();
      expect(c.state.proposals, isEmpty);
      expect(exec.done, isEmpty);
      await c.close();
    });

    test('recogniser alternative: a hypothesis that names a colleague is used, and said so (finding 4)', () async {
      final c = make();
      await c.startListening();
      speech.events.add(const SpeechFinal('open chat with Dr mama', alternatives: ['open chat with Dr Bala']));
      await _settle();
      expect((c.state.proposals.single as OpenChatAction).to, _bala);
      expect(c.state.notes.single, contains('closer match'));
      expect(exec.done, isEmpty, reason: 'still needs the doctor’s tap');
      await c.close();
    });

    test('low recogniser confidence is flagged on the card', () async {
      final c = make();
      await c.startListening();
      speech.events.add(const SpeechFinal('open chat with Bala', confidence: 0.3));
      await _settle();
      expect(c.state.notes.single, contains('misheard'));
      await c.close();
    });

    test('built-in answers work without the AI (general questions)', () async {
      final c = make();
      await c.handleText('what time is it');
      expect(c.state.phase, VoiceBotPhase.done);
      expect(c.state.message, 'It is 2:05 PM.');
      await c.handleText('what can you do');
      expect(c.state.message, contains('draft a handoff'));
      expect(c.state.turns.where((t) => t.fromUser).map((t) => t.text), ['what time is it', 'what can you do']);
      await c.close();
    });

    test('without AI, a general question gets an honest answer, not a wrong action', () async {
      final c = make();
      await c.handleText('what is the normal potassium range');
      expect(c.state.phase, VoiceBotPhase.error);
      expect(c.state.message, contains("isn't switched on"));
      expect(c.state.proposals, isEmpty);
      await c.close();
    });

    test('AI gets the conversation so far; replies show as answers (context)', () async {
      final seen = <List<VoiceTurn>>[];
      final c = make(ai: (text, history) async {
        seen.add(history);
        if (text.contains('potassium')) return const [ReplyAction('Typically 3.5–5.0 mmol/L; check your lab range.')];
        return const [SendMessageAction(to: _bala, text: 'Potassium is 3.5–5.0')];
      });
      await c.handleText('what is the normal potassium range');
      expect(c.state.phase, VoiceBotPhase.done);
      expect(c.state.message, contains('3.5–5.0'));
      await c.handleText('send that to Bala');
      expect(seen.last.map((t) => t.text), contains('Typically 3.5–5.0 mmol/L; check your lab range.'));
      expect(c.state.proposals.single, isA<SendMessageAction>());
      expect(exec.done, isEmpty);
      await c.close();
    });

    test('picking someone for an unknown name keeps the message (no guess)', () async {
      final c = make();
      await c.handleText('tell mama that the check is complete');
      final q = c.state.proposals.single as ClarifyAction;
      c.choose(q, _bala);
      final s = c.state.proposals.single as SendMessageAction;
      expect(s.to, _bala);
      expect(s.text, 'The check is complete');
      await c.close();
    });
  });

  group('panel', () {
    testWidgets('handoff card spells out recipient, beds, summary and what was not used', (tester) async {
      final c = VoiceBotCubit(speech: _Speech(), executor: _Exec(), loadDirectory: () async => _dir);
      addTearDown(c.close);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BlocProvider.value(value: c, child: const VoiceBotPanel())),
      ));
      await c.handleText('hand off bed 12 to Alex the sky');
      await tester.pumpAndSettle();
      expect(find.text('Dr Alex Moreno'), findsWidgets);
      expect(find.descendant(of: find.byKey(const Key('voicebot-handoff-beds')), matching: find.text('12')),
          findsOneWidget);
      expect(find.text('None — add in the draft'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('voicebot-note')), matching: find.textContaining('the sky')),
          findsOneWidget);
    });
  });

  group('built-in help', () {
    test('greeting, date, how-to', () {
      final now = DateTime(2026, 11, 18, 9, 0);
      expect(VoiceHelp.answer('hello', now: now), startsWith('Hello'));
      expect(VoiceHelp.answer("what's the date", now: now), 'Today is Wednesday, 18 November 2026.');
      expect(VoiceHelp.answer('how do I create a handoff', now: now), contains('Hand off bed'));
      expect(VoiceHelp.answer('dose of amoxicillin', now: now), isNull);
    });
  });

  group('chat themes (enhancement 4)', () {
    test('three curated themes; removed theme ids fall back to Clinical', () {
      expect(ChatWallpaper.values.map((w) => w.label), ['Clinical', 'Scrubs', 'Plain']);
      expect(ChatWallpaper.fromId('mint'), ChatWallpaper.clinical);
      expect(ChatWallpaper.fromId('doodle'), ChatWallpaper.clinical);
      for (final w in ChatWallpaper.values) {
        expect(w.bubbleDark, isNot(const Color(0xFF005C4B)), reason: 'no messenger green');
      }
    });
  });
}
