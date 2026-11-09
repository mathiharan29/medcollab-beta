// On-device journey: Needl (group DM) + threads, against the LOCAL backend.
//
// Dr Asha Rao drives the real app on the emulator. Dr Bala Iyer is the
// "other phone", driven through the API from inside the test, so his
// messages and thread replies must arrive live.
//
// Seed first (C:\Users\user\vocle-dev\needl-seed.mjs): Asha has accepted
// requests with Bala + Chitra; Dev was never asked.
//
// Run:
//   flutter drive --profile --driver=test_driver/ui_journey_driver.dart \
//     --target=integration_test/vocle_needl_thread_test.dart -d emulator-5554
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

const _api = 'http://10.0.2.2:5000/api';
final _timings = <String, int>{};
final _errors = <String>[];

Finder _text(String pattern) => find.byWidgetPredicate(
      (w) =>
          (w is Text && RegExp(pattern).hasMatch(w.data ?? '')) ||
          (w is RichText && RegExp(pattern).hasMatch(w.text.toPlainText())),
    );

Future<int> _waitFor(WidgetTester tester, Finder f,
    {Duration timeout = const Duration(seconds: 20)}) async {
  final w = Stopwatch()..start();
  while (w.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.hitTestable().evaluate().isNotEmpty) return w.elapsedMilliseconds;
  }
  throw TestFailure('Timed out waiting for $f');
}

Future<void> _step(WidgetTester tester, String name,
    Future<void> Function() action, Finder until,
    {Duration timeout = const Duration(seconds: 20)}) async {
  final w = Stopwatch()..start();
  await action();
  await _waitFor(tester, until, timeout: timeout);
  _timings[name] = w.elapsedMilliseconds;
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final e = tester.takeException();
  if (e != null) _errors.add('$name: $e');
  // ignore: avoid_print
  print('STEP $name ${_timings[name]} ms');
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.hitTestable().evaluate().isEmpty) await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.hitTestable().first);
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

/// The other doctor's phone, via the API.
class _Peer {
  _Peer(this.token);
  final String token;
  final dio = Dio(BaseOptions(baseUrl: _api));

  static Future<_Peer> signIn(String phone) async {
    final d = Dio(BaseOptions(baseUrl: _api));
    await d.post('/auth/request-otp', data: {'phone': phone});
    final r = await d.post('/auth/verify-otp', data: {'phone': phone, 'otp': '123456'});
    return _Peer(r.data['data']['accessToken'] as String);
  }

  Options get _auth => Options(headers: {'Authorization': 'Bearer $token'});

  Future<String> send(String channelId, String text, {String? threadOf}) async {
    final path = threadOf == null
        ? '/channels/$channelId/messages'
        : '/channels/$channelId/messages/$threadOf/reply';
    final r = await dio.post(path,
        data: {'type': 'text', 'content': {'text': text}}, options: _auth);
    return r.data['data']['message']['_id'] as String;
  }

  Future<String> rootIdOf(String channelId, String text) async {
    final r = await dio.get('/channels/$channelId/messages', options: _auth);
    final list = (r.data['data']['messages'] as List).cast<Map>();
    return list.lastWhere((m) => m['content']?['text'] == text)['_id'] as String;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Needl + threads on device', (tester) async {
    // Note: no FlutterError.onError override — the test framework reports
    // test failures through it, and overriding it hid a real failure.

    AppDependencies.instance.init();
    await tester.pumpWidget(const MedCollabApp());
    final router = AppDependencies.instance.appRouter.router;
    final auth = AppDependencies.instance.authBloc;

    // Sign in as Asha (OTP bypass on the local backend).
    await _waitFor(tester, find.text('Continue'), timeout: const Duration(seconds: 40));
    auth.add(const AuthPhoneSubmitted('9100000001'));
    await _waitFor(tester, find.text('Verify & Continue'));
    auth.add(const AuthOtpSubmitted('123456'));
    await _waitFor(tester, _text(r'^Good '), timeout: const Duration(seconds: 30));

    // Host takes a screenshot of the Home header (alerts pill alignment).
    await tester.pump(const Duration(seconds: 2));
    // ignore: avoid_print
    print('HOME_READY');
    final hold = Stopwatch()..start();
    while (hold.elapsed < const Duration(seconds: 4)) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final bala = await _Peer.signIn('+919100000002');

    // 1. Start DM → pick Bala + Chitra → Create Needl.
    await _step(tester, 'open_start_dm', () async { unawaited(router.push(AppRoutes.startDm)); },
        _text('People you chat with'));
    for (final name in ['Dr Bala Iyer', 'Dr Chitra Nair']) {
      final row = find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
      await _tap(tester, find.descendant(of: row, matching: find.byType(Checkbox)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await _step(tester, 'create_needl',
        () => _tap(tester, find.widgetWithText(TextButton, 'Create Needl')),
        find.byType(MessageComposer));
    // Bala's phone sees the new Needl in his Direct list.
    final dms = await bala.dio.get('/channels/dm', options: bala._auth);
    final needl = (dms.data['data']['channels'] as List)
        .cast<Map>()
        .firstWhere((c) => c['isNeedl'] == true, orElse: () => const {});
    expect(needl, isNotEmpty, reason: 'Needl must appear for the other member');
    final needlId = needl['_id'] as String;

    // 2. Send in the Needl.
    await _setText(tester, find.descendant(of: find.byType(MessageComposer), matching: find.byType(TextField)), 'Bed 7 K+ 6.1');
    await _step(tester, 'send_in_needl',
        () => _tap(tester, find.byIcon(Icons.send_rounded)), _text(r'^Bed 7 K\+ 6\.1$'));

    // 3. Bala answers from his phone → arrives live.
    await _step(tester, 'peer_message_live',
        () => bala.send(needlId, 'On it, coming'), _text(r'^On it, coming$'));

    // 4. Thread: long-press → Reply in thread → reply.
    await tester.longPress(_text(r'^Bed 7 K\+ 6\.1$').hitTestable().first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await _step(tester, 'open_thread',
        () => _tap(tester, find.text('Reply in thread')),
        find.widgetWithText(TextField, 'Reply in thread…'));
    await _setText(tester, find.widgetWithText(TextField, 'Reply in thread…'), 'Calcium gluconate given');
    await _step(tester, 'send_thread_reply',
        () => _tap(tester, find.byIcon(Icons.send_rounded)), _text(r'^Calcium gluconate given$'));

    // 5. Bala replies in the thread → appears live in the open thread.
    final rootId = await bala.rootIdOf(needlId, 'Bed 7 K+ 6.1');
    await _step(tester, 'peer_thread_reply_live',
        () => bala.send(needlId, 'Insulin-dextrose started', threadOf: rootId),
        _text(r'^Insulin-dextrose started$'));
    expect(_text(r'^2 replies$').evaluate().isNotEmpty || _text('2 replies').evaluate().isNotEmpty, isTrue,
        reason: 'thread header counts both replies');

    // 6. Back to the Needl: root shows "2 replies →", replies not in timeline.
    // App-bar back arrow returns to the Needl (system back goes Home, REQ 3).
    await _step(tester, 'back_to_needl', () => tester.pageBack(),
        _text(r'^2 replies →$'));
    expect(_text(r'^Calcium gluconate given$').hitTestable().evaluate(), isEmpty,
        reason: 'thread replies stay out of the main timeline');

    // 7. Rename the Needl → activity chip, header updates.
    await _tap(tester, find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await _tap(tester, find.text('Rename Needl'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await _setText(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Bed 7 team');
    await _step(tester, 'rename_needl', () => _tap(tester, find.text('Save')),
        find.byType(SystemEventChip));
    await _waitFor(tester, _text(r'^Bed 7 team$'));

    // 8. Needl with someone never asked → offer requests (no dead end).
    router.go(AppRoutes.home);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await _step(tester, 'reopen_start_dm', () async { unawaited(router.push(AppRoutes.startDm)); },
        _text('People you chat with'));
    final search = find.byType(TextField).first;
    await _setText(tester, search, 'Dev Mehta');
    await _waitFor(tester, find.text('Dr Dev Mehta'));
    final devRow = find.ancestor(of: find.text('Dr Dev Mehta'), matching: find.byType(Row)).first;
    await _tap(tester, find.descendant(of: devRow, matching: find.byType(Checkbox)));
    await _setText(tester, search, '');
    await _waitFor(tester, find.text('Dr Bala Iyer'));
    final balaRow = find.ancestor(of: find.text('Dr Bala Iyer'), matching: find.byType(Row)).first;
    await _tap(tester, find.descendant(of: balaRow, matching: find.byType(Checkbox)));
    // Selection bar updates on the next frame.
    await _waitFor(tester, find.widgetWithText(TextButton, 'Create Needl'));
    await _step(tester, 'needl_needs_request',
        () => _tap(tester, find.widgetWithText(TextButton, 'Create Needl')),
        find.text('Send message requests?'));
    await _step(tester, 'send_needl_request', () => _tap(tester, find.text('Send request')),
        _text('Requests sent'));

    // 9. Thread in a group channel too.
    final spaces = await bala.dio.get('/spaces', options: bala._auth);
    final space = (spaces.data['data']['spaces'] as List).first as Map;
    final general = (space['channels'] as List).firstWhere((c) => c['name'] == 'general') as Map;
    final gRoot = await bala.send(general['_id'] as String, 'Journal club Friday?');
    await _step(tester, 'open_group_channel',
        () async => router.go(AppRoutes.channelPath(space['_id'] as String, general['_id'] as String)),
        _text(r'^Journal club Friday\?$'));
    await bala.send(general['_id'] as String, 'I will present', threadOf: gRoot);
    await _step(tester, 'group_thread_count_live', () async {}, _text(r'^1 reply →$'));

    final report = {'timings': _timings, 'errors': _errors};
    binding.reportData = {...?binding.reportData, 'needl': report};
    // ignore: avoid_print
    print('NEEDL_REPORT $report');
    expect(_errors, isEmpty, reason: _errors.join('\n'));
  });
}
