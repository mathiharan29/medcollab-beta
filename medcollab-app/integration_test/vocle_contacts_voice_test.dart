// On-device journey for the beta feedback (11-10), with REAL device parts:
// address-book contact sync, stranger → request, microphone voice note
// (record, upload, send, play) and chat theme save.
//
// Pre-reqs (host): local backend on :5000 seeded with needl-seed.mjs; an
// address-book contact "Bala ICU" with +91 91000 00002 on the emulator;
// READ_CONTACTS / RECORD_AUDIO granted (watcher script).
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medcollab_app/app.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/voice_note.dart';

const _api = 'http://10.0.2.2:5000/api';
final _timings = <String, int>{};

Finder _text(String pattern) => find.byWidgetPredicate(
      (w) =>
          (w is Text && RegExp(pattern).hasMatch(w.data ?? '')) ||
          (w is RichText && RegExp(pattern).hasMatch(w.text.toPlainText())),
    );

Future<void> _waitFor(WidgetTester tester, Finder f,
    {Duration timeout = const Duration(seconds: 25)}) async {
  final w = Stopwatch()..start();
  while (w.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.hitTestable().evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}

Future<void> _step(WidgetTester tester, String name,
    Future<void> Function() action, Finder until,
    {Duration timeout = const Duration(seconds: 25)}) async {
  final w = Stopwatch()..start();
  await action();
  await _waitFor(tester, until, timeout: timeout);
  _timings[name] = w.elapsedMilliseconds;
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final e = tester.takeException();
  if (e != null) throw TestFailure('$name: $e');
  // ignore: avoid_print
  print('STEP $name ${_timings[name]} ms');
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.hitTestable().evaluate().isEmpty) await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.hitTestable().first);
}

Future<void> _real(WidgetTester tester, Duration d) async {
  final w = Stopwatch()..start();
  while (w.elapsed < d) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _setText(WidgetTester tester, Finder field, String text) async {
  final widget = tester.widget<TextField>(field);
  widget.controller!.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  widget.onChanged?.call(text);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('contacts, stranger request, voice note, chat theme',
      (tester) async {
    AppDependencies.instance.init();
    await tester.pumpWidget(const MedCollabApp());
    final router = AppDependencies.instance.appRouter.router;
    final auth = AppDependencies.instance.authBloc;
    await _waitFor(tester, find.text('Continue'), timeout: const Duration(seconds: 40));
    auth.add(const AuthPhoneSubmitted('9100000001'));
    await _waitFor(tester, find.text('Verify & Continue'));
    auth.add(const AuthOtpSubmitted('123456'));
    await _waitFor(tester, _text(r'^Good '), timeout: const Duration(seconds: 30));

    final d = Dio(BaseOptions(baseUrl: _api));
    await d.post('/auth/request-otp', data: {'phone': '+919100000002'});
    final login = await d.post('/auth/verify-otp',
        data: {'phone': '+919100000002', 'otp': '123456'});
    final balaAuth = Options(headers: {
      'Authorization': 'Bearer ${login.data['data']['accessToken']}',
    });

    // 1. Find contacts on Vocle (real address book read + server match).
    await _step(tester, 'open_start_dm',
        () async { unawaited(router.push(AppRoutes.startDm)); },
        find.text('Find contacts on Vocle'));
    await _step(tester, 'contact_sync',
        () => _tap(tester, find.text('Find contacts on Vocle')),
        _text(r'^In your contacts as Bala ICU$'));

    // 2. Stranger from search → chat → request offered and sent.
    await _setText(tester, find.byType(TextField).first, 'Dev Mehta');
    await _waitFor(tester, find.text('Dr Dev Mehta'));
    await _step(tester, 'stranger_chat_offers_request',
        () => _tap(tester, find.byTooltip('Start 1:1 DM')),
        _text(r'^Message request to Dr Dev Mehta$'));
    await _step(tester, 'stranger_request_sent',
        () => _tap(tester, find.text('Send request')),
        _text('Request sent'));

    // 3. Open the chat with Bala (accepted earlier) and record a voice note.
    await _setText(tester, find.byType(TextField).first, '');
    await _waitFor(tester, find.text('Dr Bala Iyer'));
    final balaRow = find.ancestor(of: find.text('Dr Bala Iyer'), matching: find.byType(Row)).first;
    await _step(tester, 'open_dm',
        () => _tap(tester, find.descendant(of: balaRow, matching: find.byTooltip('Start 1:1 DM'))),
        find.byType(MessageComposer));
    await _step(tester, 'start_recording',
        () => _tap(tester, find.byIcon(Icons.mic_rounded)),
        find.byType(VoiceRecordingBar));
    await _real(tester, const Duration(milliseconds: 2500));
    await _step(tester, 'send_voice_note',
        () => _tap(tester, find.descendant(of: find.byType(VoiceRecordingBar), matching: find.byIcon(Icons.send_rounded))),
        find.descendant(of: find.byType(VoiceNoteBubble), matching: find.byIcon(Icons.play_arrow_rounded)),
        timeout: const Duration(seconds: 30));
    expect(_text(r'^Failed to send$').evaluate(), isEmpty);

    // Bala's side: an audio message with a sane length arrived.
    final dms = await d.get('/channels/dm', options: balaAuth);
    final dm = (dms.data['data']['channels'] as List).cast<Map>().firstWhere(
        (c) => (c['members'] as List).length == 2 && c['lastMessage']?['type'] == 'audio');
    final msgs = await d.get('/channels/${dm['_id']}/messages', options: balaAuth);
    final audio = (msgs.data['data']['messages'] as List).cast<Map>().lastWhere((m) => m['type'] == 'audio');
    final dur = audio['content']['durationMs'] as int;
    expect(dur, inInclusiveRange(1500, 6000), reason: 'duration $dur ms');
    expect((audio['content']['mediaUrl'] as String).isNotEmpty, isTrue);
    // ignore: avoid_print
    print('VOICE durationMs=$dur bars=${(audio['content']['waveform'] as List?)?.length}');

    // Play it back.
    await _step(tester, 'play_voice_note',
        () => _tap(tester, find.descendant(of: find.byType(VoiceNoteBubble), matching: find.byIcon(Icons.play_arrow_rounded)).last),
        find.descendant(of: find.byType(VoiceNoteBubble), matching: find.byIcon(Icons.pause_rounded)),
        timeout: const Duration(seconds: 15));

    // 4. Chat theme: pick, this chat only, Save.
    await _tap(tester, find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await _step(tester, 'open_chat_theme',
        () => _tap(tester, find.text('Chat theme')), find.text('Save'));
    await _tap(tester, find.text('Mint'));
    await _tap(tester, find.text('This chat only'));
    await _step(tester, 'save_chat_theme',
        () => _tap(tester, find.text('Save')), _text('Theme saved for this chat'));
  });
}
