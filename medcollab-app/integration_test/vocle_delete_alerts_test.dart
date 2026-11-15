// On-device journey (beta feedback 11-10): grouped Alerts, delete for
// everyone / for me, clear chat — each checked against the server.
// Pre-reqs: local backend on :5000 seeded with needl-seed.mjs.
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

Future<void> _waitGone(WidgetTester tester, Finder f,
    {Duration timeout = const Duration(seconds: 15)}) async {
  final w = Stopwatch()..start();
  while (w.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.evaluate().isEmpty) return;
  }
  throw TestFailure('Still visible: $f');
}

Future<void> _real(WidgetTester tester, Duration d) async {
  final w = Stopwatch()..start();
  while (w.elapsed < d) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _real(tester, const Duration(milliseconds: 600));
  // ignore: avoid_print
  print('SHOT_$name');
  await _real(tester, const Duration(seconds: 3));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.hitTestable().evaluate().isEmpty) await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.hitTestable().first);
}

void _step(String s) {
  // ignore: avoid_print
  print('STEP $s');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('grouped alerts, delete for me/everyone, clear chat',
      (tester) async {
    final d = Dio(BaseOptions(baseUrl: _api));
    Future<Options> login(String phone) async {
      await d.post('/auth/request-otp', data: {'phone': phone});
      final r = await d.post('/auth/verify-otp', data: {'phone': phone, 'otp': '123456'});
      return Options(headers: {'Authorization': 'Bearer ${r.data['data']['accessToken']}'});
    }

    // Unique per run: earlier runs leave messages in the same chat.
    final tag = (DateTime.now().millisecondsSinceEpoch % 100000).toString();
    final bed = 'Bed 4 BP 90/60 #$tag', fluids = 'Started fluids #$tag',
        review = 'Please review #$tag', wrong = 'Wrong patient #$tag',
        after = 'After clear #$tag';
    final bala = await login('+919100000002');
    final asha = await login('+919100000001');
    final ashaId = (await d.get('/users/me', options: asha)).data['data']['user']['_id'] as String;
    final dm = (await d.post('/channels/dm', data: {'userId': ashaId}, options: bala))
        .data['data']['channel']['_id'] as String;
    Future<List<String>> balaSees() async =>
        ((await d.get('/channels/$dm/messages', options: bala)).data['data']['messages'] as List)
            .map((m) => (m['content']?['text'] ?? '').toString())
            .toList();

    // Start clean: Asha's alerts read, then Bala sends a burst of 3.
    await d.put('/notifications/read-all', options: asha);
    for (final t in [bed, fluids, review]) {
      await d.post('/channels/$dm/messages', data: {'type': 'text', 'content': {'text': t}}, options: bala);
    }
    await Future<void>.delayed(const Duration(seconds: 1));

    AppDependencies.instance.init();
    await tester.pumpWidget(const MedCollabApp());
    final router = AppDependencies.instance.appRouter.router;
    final auth = AppDependencies.instance.authBloc;
    await _waitFor(tester, find.text('Continue'), timeout: const Duration(seconds: 40));
    auth.add(const AuthPhoneSubmitted('9100000001'));
    await _waitFor(tester, find.text('Verify & Continue'));
    auth.add(const AuthOtpSubmitted('123456'));
    await _waitFor(tester, _text(r'^Good '), timeout: const Duration(seconds: 30));

    // 1. Alerts: Bala's 3 messages are ONE row with a "3" badge.
    router.go(AppRoutes.notifications);
    await _waitFor(tester, _text(r'^3 new messages'));
    // Visible rows only (other shell tabs stay alive off-screen).
    expect(find.text(review).hitTestable().evaluate().length, 1);
    expect(find.text(fluids).hitTestable().evaluate(), isEmpty,
        reason: 'older messages of the same chat must not be separate rows');
    final badge = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('alert-group-count')), matching: find.byType(Text)));
    expect(badge.data, '3');
    await _shot(tester, 'alerts_grouped');
    _step('alerts_grouped');

    // Opening the row opens the chat and clears all 3.
    await _tap(tester, find.text(review));
    await _waitFor(tester, find.byType(MessageComposer));
    final unread = (await d.get('/notifications/unread-count', options: asha)).data['data']['count'];
    expect(unread, 0);
    _step('alerts_group_opened_and_read');

    // 2. Delete for everyone (own message) → gone here AND on the server.
    final field = find.descendant(of: find.byType(MessageComposer), matching: find.byType(TextField));
    final composerField = tester.widget<TextField>(field.first);
    composerField.controller!.value = TextEditingValue(
      text: wrong,
      selection: TextSelection.collapsed(offset: wrong.length),
    );
    composerField.onChanged?.call(wrong);
    await _waitFor(tester, find.byIcon(Icons.send_rounded));
    await _tap(tester, find.byIcon(Icons.send_rounded));
    await _waitFor(tester, find.text(wrong));
    await _real(tester, const Duration(seconds: 1));
    expect((await balaSees()).contains(wrong), isTrue);
    await tester.longPress(find.text(wrong).hitTestable().first);
    await _waitFor(tester, find.text('Delete'));
    await _tap(tester, find.text('Delete'));
    await _waitFor(tester, find.text('Delete for everyone'));
    await _shot(tester, 'delete_dialog_mine');
    await _tap(tester, find.text('Delete for everyone'));
    await _waitGone(tester, find.text(wrong));
    await _real(tester, const Duration(milliseconds: 500));
    expect((await balaSees()).contains(wrong), isFalse,
        reason: 'deleted for everyone must be gone for the other doctor too');
    _step('delete_for_everyone');

    // 3. Someone else's message: only "Delete for me".
    await tester.longPress(find.text(fluids).hitTestable().first);
    await _waitFor(tester, find.text('Delete'));
    await _tap(tester, find.text('Delete'));
    await _waitFor(tester, find.text('Delete for me'));
    expect(find.text('Delete for everyone'), findsNothing);
    await _shot(tester, 'delete_dialog_theirs');
    await _tap(tester, find.text('Delete for me'));
    await _waitGone(tester, find.text(fluids));
    expect((await balaSees()).contains(fluids), isTrue,
        reason: 'delete for me must not remove it for the sender');
    _step('delete_for_me');

    // 4. Live: Bala deletes one of his for everyone → disappears here.
    final balaMsgs = (await d.get('/channels/$dm/messages', options: bala)).data['data']['messages'] as List;
    final reviewMsg = balaMsgs.firstWhere((m) => m['content']?['text'] == review);
    await d.delete('/channels/$dm/messages/${reviewMsg['_id']}', queryParameters: {'scope': 'everyone'}, options: bala);
    await _waitGone(tester, find.text(review));
    _step('live_delete_from_other_doctor');

    // 5. Clear chat (for me only).
    await _tap(tester, find.byIcon(Icons.more_vert));
    await _waitFor(tester, find.text('Clear chat'));
    await _tap(tester, find.text('Clear chat'));
    await _waitFor(tester, find.text('Clear this chat?'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Clear chat'));
    await _waitGone(tester, find.text(bed));
    await _waitFor(tester, find.text('Chat cleared'));
    await _shot(tester, 'chat_cleared');
    expect((await balaSees()).contains(bed), isTrue,
        reason: 'clear chat is personal');
    _step('clear_chat');

    // New messages still arrive after clearing.
    await d.post('/channels/$dm/messages', data: {'type': 'text', 'content': {'text': after}}, options: bala);
    await _waitFor(tester, find.text(after));
    _step('new_message_after_clear');

    // Reopen: history stays cleared (server-side, not just local).
    router.go(AppRoutes.messages);
    await _real(tester, const Duration(seconds: 1));
    unawaited(router.push(AppRoutes.dmPath(dm)));
    await _waitFor(tester, find.text(after));
    expect(find.text(bed).evaluate(), isEmpty);
    _step('reopen_stays_cleared');
    // ignore: avoid_print
    print('DELETE_TOUR_DONE');
  });
}
