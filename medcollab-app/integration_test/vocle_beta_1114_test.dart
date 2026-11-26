// On-device verification of the beta 11-14 round (issues 1–12) against a
// LOCAL backend seeded with medcollab-backend/tests/device/seed-1114.mjs.
// The host watcher (scripts/device-shots.ps1) turns `SHOT_x` lines into
// screenshots and performs `DO_*` shade/network actions.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medcollab_app/app.dart';
import 'package:medcollab_app/core/chat/chat_transcript_cache.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/notifications/grouped_message_notification.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/composer_parts.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_cubit.dart';

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
  // Diagnose: what is on screen, and does the target exist off-screen?
  final texts = <String>[
    for (final e in find.byType(RichText).evaluate())
      (e.widget as RichText).text.toPlainText(),
  ].where((t) => t.trim().isNotEmpty).take(40).join(' | ');
  // ignore: avoid_print
  print('WAITFOR_DIAG exists=${f.evaluate().length} '
      'path=${AppDependencies.instance.appRouter.router.state.uri.path} texts=$texts');
  throw TestFailure('Timed out waiting for $f');
}

Future<void> _waitGone(WidgetTester tester, Finder f,
    {Duration timeout = const Duration(seconds: 15)}) async {
  final w = Stopwatch()..start();
  while (w.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.hitTestable().evaluate().isEmpty) return;
  }
  throw TestFailure('Still visible: $f');
}

Future<void> _real(WidgetTester tester, Duration d) async {
  final w = Stopwatch()..start();
  while (w.elapsed < d) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

bool _surfaceIsImage = false;

/// Exact-frame screenshot, delivered to the driver (test_driver/…).
Future<void> _shot(WidgetTester tester, String name) async {
  await _real(tester, const Duration(milliseconds: 700));
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  // Android captures from an image surface; switch to it only for the
  // capture so the rest of the run (incl. Issue 2 timings) renders normally.
  if (!_surfaceIsImage) {
    await binding.convertFlutterSurfaceToImage(); // registers the teardown
    _surfaceIsImage = true;
  } else {
    await _itChannel.invokeMethod<void>('convertFlutterSurfaceToImage');
  }
  await _real(tester, const Duration(milliseconds: 300));
  await binding.takeScreenshot(name);
  await _itChannel.invokeMethod<void>('revertFlutterImage'); // no-op if reverted
  await _real(tester, const Duration(milliseconds: 200));
  _log('CAPTURED $name');
}

const _itChannel = MethodChannel('plugins.flutter.io/integration_test');

void _log(String s) {
  // ignore: avoid_print
  print(s);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.hitTestable().evaluate().isEmpty) await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.hitTestable().first);
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await _real(tester, const Duration(milliseconds: 700));
}

String _path() =>
    AppDependencies.instance.appRouter.router.state.uri.path;

Future<void> _type(WidgetTester tester, String text) async {
  final field = find.byKey(const Key('composer-field'));
  final tf = tester.widget<TextField>(field.first);
  tf.controller!.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  tf.onChanged?.call(text);
  await tester.pump();
}

/// 2 s 16 kHz WAV with a soft tone (a real, playable clip).
List<int> _wav() {
  const rate = 16000, n = rate * 2;
  final b = BytesBuilder();
  void u32(int v) => b.add([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]);
  void u16(int v) => b.add([v & 255, (v >> 8) & 255]);
  b.add('RIFF'.codeUnits);
  u32(36 + n * 2);
  b.add('WAVEfmt '.codeUnits);
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  b.add('data'.codeUnits);
  u32(n * 2);
  for (var i = 0; i < n; i++) {
    final s = (math.sin(2 * math.pi * 440 * i / rate) * 5000).round() & 0xffff;
    u16(s);
  }
  return b.toBytes();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('beta 11-14: issues 1–12 on device', (tester) async {
    final d = Dio(BaseOptions(baseUrl: _api));
    Future<Options> login(String phone) async {
      await d.post('/auth/request-otp', data: {'phone': phone});
      final r = await d.post('/auth/verify-otp', data: {'phone': phone, 'otp': '123456'});
      return Options(headers: {'Authorization': 'Bearer ${r.data['data']['accessToken']}'});
    }

    final meeraH = await login('+919100000001');
    final arjun = await login('+919100000002');
    final bala = await login('+919100000003');
    final asha1 = await login('+919100000005');
    final asha2 = await login('+919100000006');
    String idOf(Response r) => r.data['data']['user']['_id'] as String;
    final asha1Id = idOf(await d.get('/users/me', options: asha1));
    final meeraId = idOf(await d.get('/users/me', options: meeraH));

    final spaces = (await d.get('/spaces', options: meeraH)).data['data']['spaces'] as List;
    final ward = spaces.firstWhere((s) => s['name'] == 'Ward 5');
    final general = (ward['channels'] as List).firstWhere((c) => c['name'] == 'general')['_id'] as String;
    final dms = (await d.get('/channels/dm', options: meeraH)).data['data']['channels'] as List;
    String dmWith(String name) => dms.firstWhere((c) =>
        (c['members'] as List).length == 2 &&
        (c['members'] as List).any((m) => m['name'] == name))['_id'] as String;
    final dmArjun = dmWith('Arjun Rao');
    final dmBala = dmWith('Bala Krishnan');
    final needl1 = dms.firstWhere((c) => (c['members'] as List).length == 3)['_id'] as String;
    final msgs = (await d.get('/channels/$general/messages', options: meeraH)).data['data']['messages'] as List;
    final oldRoot = msgs.firstWhere((m) => (m['content']?['text'] ?? '').toString().startsWith('Old plan'))['_id'];
    final handoffs = (await d.get('/handoffs', queryParameters: {'type': 'received'}, options: meeraH)).data['data']['handoffs'] as List;
    final handoffId = handoffs.first['_id'] as String;

    // ── Sign in as Dr Meera ──────────────────────────────────────────────
    AppDependencies.instance.init();
    await tester.pumpWidget(const MedCollabApp());
    final router = AppDependencies.instance.appRouter.router;
    final auth = AppDependencies.instance.authBloc;
    await _waitFor(tester, find.text('Continue'), timeout: const Duration(seconds: 40));
    auth.add(const AuthPhoneSubmitted('9100000001'));
    await _waitFor(tester, find.text('Verify & Continue'));
    auth.add(const AuthOtpSubmitted('123456'));
    await _waitFor(tester, _text(r'^Good '), timeout: const Duration(seconds: 30));
    await _real(tester, const Duration(seconds: 2));
    await _shot(tester, '01_home_light');
    const part = String.fromEnvironment('PART', defaultValue: 'all');
    if (part != 'voice') {

    // ── Issue 1: theme switch — sizes identical, neutral dark ────────────
    // Start from Light whatever an earlier run left saved.
    await tester.element(find.byType(Scaffold).first).read<ThemeModeCubit>().setMode(ThemeMode.light);
    await _real(tester, const Duration(seconds: 1));
    router.go(AppRoutes.profile);
    await _waitFor(tester, find.text('Appearance'));
    await _tap(tester, find.text('Appearance'));
    await _waitFor(tester, find.text('System default'));
    // Only the sheet's rows: the Profile page behind it also says "Dark".
    Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);
    final darkLabel = inSheet(find.text('Dark'));
    final tile = find.ancestor(of: darkLabel, matching: find.byType(ListTile));
    String dims(Size s) => '${s.width.toStringAsFixed(1)}x${s.height.toStringAsFixed(1)}';
    final before = tester.getSize(tile.first);
    final titleBefore = tester.getSize(darkLabel.first);
    // A row whose checkmark does not change: its label must be identical.
    final steady = inSheet(find.text('System default'));
    final steadyBefore = tester.getSize(steady.first);
    await _shot(tester, '02_appearance_light');
    await _tap(tester, darkLabel);
    await tester.pump(); // first frame after the switch
    final after = tester.getSize(tile.first);
    final titleAfter = tester.getSize(darkLabel.first);
    final steadyAfter = tester.getSize(steady.first);
    _log('STEP issue1_measure row ${dims(before)} -> ${dims(after)}; '
        'label ${dims(titleBefore)} -> ${dims(titleAfter)}; steady ${dims(steadyBefore)} -> ${dims(steadyAfter)}; '
        'theme=${Theme.of(tester.element(darkLabel.first)).brightness}');
    expect(Theme.of(tester.element(darkLabel.first)).brightness, Brightness.dark);
    expect(dims(after), dims(before), reason: 'Appearance rows keep their size');
    // Width of the Dark label shrinks only because its ✓ appears; the
    // font size (line height) must not change.
    expect(titleAfter.height, titleBefore.height, reason: 'font size unchanged');
    expect(dims(steadyAfter), dims(steadyBefore), reason: 'unchanged row keeps exact text size');    _log('STEP issue1_sizes_equal $before');
    await _shot(tester, '03_appearance_dark');
    Navigator.of(tester.element(darkLabel.first)).pop();
    await _real(tester, const Duration(milliseconds: 600));
    router.go(AppRoutes.home);
    await _shot(tester, '04_home_dark');
    router.go(AppRoutes.messages);
    await _real(tester, const Duration(seconds: 1));
    await _shot(tester, '05_messages_dark');
    unawaited(router.push(AppRoutes.dmPath(dmArjun)));
    await _waitFor(tester, find.byType(MessageComposer));
    await _shot(tester, '06_chat_dark');
    await _back(tester);
    final themeCubit = tester.element(find.byType(Scaffold).first).read<ThemeModeCubit>();
    await themeCubit.setMode(ThemeMode.light);
    await _real(tester, const Duration(seconds: 1));
    _log('STEP issue1_theme_done');

    // ── Issue 2: speed (emulator network delay set by the host) ──────────
    _log('DO_NET_SLOW');
    await _real(tester, const Duration(seconds: 3));
    Future<int> timeOpen(String path, Finder until) async {
      final sw = Stopwatch()..start();
      unawaited(router.push(path));
      await _waitFor(tester, until);
      final ms = sw.elapsedMilliseconds;
      await _back(tester);
      return ms;
    }

    router.go(AppRoutes.messages);
    final hub = Stopwatch()..start();
    await _waitFor(tester, find.text('Direct'));
    _log('TIMING messages_tab ${hub.elapsedMilliseconds}');
    await _real(tester, const Duration(seconds: 3));
    final deps = AppDependencies.instance;
    final myDms = await deps.channelRepository.getMyDMs();
    final myChannels = (await deps.spaceRepository.getMySpaces()).expand((s) => s.channels).toList();
    int median(List<int> v) => (List.of(v)..sort())[v.length ~/ 2];
    Future<void> compare(String name, String path, Finder until) async {
      final cold = <int>[], warm = <int>[];
      for (var round = 0; round < 3; round++) {
        ChatTranscriptCache.clearAll(); // before: every first open waited
        cold.add(await timeOpen(path, until));
        ChatTranscriptCache.clearAll(); // after: the hub prefetches the list
        await deps.chatPrefetcher.warm([...myDms, ...myChannels], max: 12);
        warm.add(await timeOpen(path, until));
      }
      _log('TIMING open_$name cold=${median(cold)} prefetched=${median(warm)} '
          'raw_cold=$cold raw_prefetched=$warm');
    }

    await timeOpen(AppRoutes.dmPath(dmArjun), _text(r'^Bed 14 update')); // warm-up
    await compare('dm', AppRoutes.dmPath(dmArjun), _text(r'^Bed 14 update'));
    await compare('needl', AppRoutes.dmPath(needl1), _text(r'^Needl: ICU bed free'));
    await compare('group', AppRoutes.channelPath(ward['_id'], general), _text(r'^Evening handover moved'));
    _log('DO_NET_FAST');
    await _real(tester, const Duration(seconds: 2));

    // ── Issue 3: back = one level up ─────────────────────────────────────
    router.go(AppRoutes.messages);
    await _real(tester, const Duration(milliseconds: 800));
    unawaited(router.push(AppRoutes.dmPath(dmArjun)));
    await _waitFor(tester, find.byType(MessageComposer));
    await _back(tester);
    expect(_path(), AppRoutes.messages, reason: 'chat → Messages');
    await _shot(tester, '07_back_chat_to_messages');
    await _back(tester);
    expect(_path(), AppRoutes.home, reason: 'Messages → Home');
    router.go(AppRoutes.profile);
    await _waitFor(tester, find.text('Notification settings'));
    await _tap(tester, find.text('Notification settings'));
    await _real(tester, const Duration(seconds: 1));
    expect(_path(), AppRoutes.notificationSettings);
    await _back(tester);
    expect(_path(), AppRoutes.profile, reason: 'settings page → Profile');
    await _shot(tester, '08_back_settings_to_profile');
    await _back(tester);
    expect(_path(), AppRoutes.home);
    router.go(AppRoutes.dmPath(dmBala)); // like a notification tap: nothing below
    await _waitFor(tester, find.byType(MessageComposer));
    await _back(tester);
    expect(_path(), AppRoutes.messages, reason: 'notification-opened chat → Messages');
    await _back(tester);
    expect(_path(), AppRoutes.home);
    _log('STEP issue3_back_ok');

    // ── Issue 4: composer layout ─────────────────────────────────────────
    unawaited(router.push(AppRoutes.dmPath(dmArjun)));
    await _waitFor(tester, find.byType(MessageComposer));
    final rects = [
      for (final e in find.byType(ComposerIconButton).evaluate())
        tester.getRect(find.byWidget(e.widget)),
      tester.getRect(find.byKey(const Key('composer-action'))),
    ];
    for (final r in rects) {
      expect(r.size, const Size(48, 48));
      expect(r.bottom, closeTo(rects.first.bottom, 0.5));
    }
    expect(find.text('Message'), findsWidgets);
    await _shot(tester, '09_composer_empty');
    await _type(tester, 'BP 90/60 — starting fluids');
    await _real(tester, const Duration(milliseconds: 400));
    await _shot(tester, '10_composer_typing');
    await _type(tester, '');
    await _back(tester);
    _log('STEP issue4_composer_ok');

    // ── Issue 9: @mention suggestions tell people apart ──────────────────
    unawaited(router.push(AppRoutes.channelPath(ward['_id'], general)));
    await _waitFor(tester, find.byType(MessageComposer));
    await _real(tester, const Duration(seconds: 1));
    await _type(tester, 'Please see @ash');
    await _waitFor(tester, find.byKey(const Key('mention-suggestions')));
    expect(find.textContaining('Cardiology'), findsOneWidget);
    expect(find.textContaining('Nephrology'), findsOneWidget);
    await _shot(tester, '11_mention_panel');
    await d.put('/notifications/read-all', options: asha1);
    await d.put('/notifications/read-all', options: asha2);
    await _tap(tester, find.byKey(Key('mention-row-$asha1Id')));
    await _real(tester, const Duration(milliseconds: 300));
    await _tap(tester, find.byKey(const Key('composer-action')));
    FocusManager.instance.primaryFocus?.unfocus();
    await _real(tester, const Duration(seconds: 2));
    int mentionsOf(Response r) => ((r.data['data']['notifications'] as List)
        .where((n) => (n['type'] ?? '').toString().contains('mention') && n['read'] == false)).length;
    expect(mentionsOf(await d.get('/notifications', options: asha1)), 1, reason: 'picked Asha notified');
    expect(mentionsOf(await d.get('/notifications', options: asha2)), 0, reason: 'namesake not notified');
    _log('STEP issue9_mention_ok');

    // ── Issue 10: delete for me → group preview falls back ───────────────
    // A colleague posts the newest message; Meera deletes it for herself.
    const latestText = 'Evening handover moved to 7.30 pm';
    await d.post('/channels/$general/messages',
        data: {'type': 'text', 'content': {'text': latestText}}, options: arjun);
    final evening = _text('^${RegExp.escape(latestText)}\$');
    await _waitFor(tester, evening);
    await tester.longPress(evening.hitTestable().first);
    await _waitFor(tester, find.text('Delete'));
    await _tap(tester, find.text('Delete'));
    await _waitFor(tester, find.text('Delete for me'));
    expect(find.text('Delete for everyone'), findsNothing, reason: "someone else's message");
    await _tap(tester, find.text('Delete for me'));
    await _waitGone(tester, evening);
    await _back(tester); // back to where the chat was opened from (Home)
    router.go(AppRoutes.messages);
    await _real(tester, const Duration(seconds: 2));
    final groupsTab = find.text('Groups');
    await _waitFor(tester, groupsTab);
    await _tap(tester, groupsTab);
    await _real(tester, const Duration(seconds: 2));
    expect(find.textContaining(latestText).hitTestable(), findsNothing, reason: 'Meera preview');
    expect(find.textContaining('Please see').hitTestable(), findsWidgets,
        reason: 'falls back to the previous visible message');
    await _shot(tester, '12_groups_after_delete_for_me');
    final arjunSpaces = (await d.get('/spaces', options: arjun)).data['data']['spaces'] as List;
    final arjunGeneral = ((arjunSpaces.firstWhere((s) => s['name'] == 'Ward 5'))['channels'] as List)
        .firstWhere((c) => c['_id'] == general);
    _log('STEP issue10 arjun_preview=${arjunGeneral['lastMessage']['text']}');
    expect(arjunGeneral['lastMessage']['text'], latestText,
        reason: 'colleagues still see the original message');
    _log('STEP issue10_ok');

    // ── Issue 11: clear chat → preview and old thread stay hidden ────────
    unawaited(router.push(AppRoutes.channelPath(ward['_id'], general)));
    await _waitFor(tester, find.byType(MessageComposer));
    await _tap(tester, find.byIcon(Icons.more_vert));
    await _waitFor(tester, find.text('Clear chat'));
    await _tap(tester, find.text('Clear chat'));
    await _waitFor(tester, find.text('Clear this chat?'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Clear chat'));
    await _waitFor(tester, find.text('Chat cleared'));
    await _back(tester);
    await _real(tester, const Duration(seconds: 2));
    for (final old in ['Bed 12 for review', 'Old plan', 'Please see']) {
      expect(find.textContaining(old).hitTestable(), findsNothing, reason: '$old in preview');
    }
    await _shot(tester, '13_groups_after_clear');
    unawaited(router.push(AppRoutes.threadPath(ward['_id'], general, oldRoot as String)));
    await _waitFor(tester, find.byKey(const Key('thread-unavailable')));
    expect(find.textContaining('discharge bed 9'), findsNothing);
    await _shot(tester, '14_old_thread_hidden');
    await _back(tester);
    await _back(tester);
    _log('STEP issue11_ok');

    // ── Issue 6: alert count follows reading ─────────────────────────────
    router.go(AppRoutes.home);
    await d.put('/notifications/read-all', options: meeraH);
    await _real(tester, const Duration(seconds: 2));
    final nav = AppDependencies.instance.navBadgesCubit;
    final base = nav.state.alertsCount;
    for (final t in ['ABG: pH 7.31', 'Lactate 3.2', 'Please call back']) {
      await d.post('/channels/$dmBala/messages', data: {'type': 'text', 'content': {'text': t}}, options: bala);
    }
    final w0 = Stopwatch()..start();
    while (nav.state.alertsCount < base + 1 && w0.elapsed.inSeconds < 15) {
      await _real(tester, const Duration(milliseconds: 200));
    }
    await _real(tester, const Duration(seconds: 1));
    final raised = nav.state.alertsCount;
    _log('STEP issue6 base=$base raised=$raised');
    expect(raised, greaterThan(base));
    await _shot(tester, '15_alerts_badge_raised');
    unawaited(router.push(AppRoutes.dmPath(dmBala)));
    await _waitFor(tester, _text(r'^Please call back'));
    await d.post('/channels/$dmBala/messages', data: {'type': 'text', 'content': {'text': 'While you read'}}, options: bala);
    await _waitFor(tester, _text(r'^While you read'));
    await _real(tester, const Duration(seconds: 2));
    final serverUnread = (await d.get('/notifications/unread-count', options: meeraH)).data['data']['count'];
    expect(nav.state.alertsCount, serverUnread, reason: 'badge == server');
    // Everything else was read beforehand (via the API), so after reading
    // Bala's chat nothing is left: badge and server both 0.
    expect(serverUnread, 0, reason: 'reading the chat cleared its alerts on the server');
    await _back(tester);
    await _real(tester, const Duration(seconds: 1));
    expect(nav.state.alertsCount, 0, reason: 'badge stays at the server count');
    await _shot(tester, '16_alerts_badge_after_read');
    _log('STEP issue6_ok badge=${nav.state.alertsCount} server=$serverUnread');

    // ── Issue 8: Needl add reflects right away (adder + others) ──────────
    unawaited(router.push(AppRoutes.dmPath(needl1)));
    await _waitFor(tester, find.byType(MessageComposer));
    await _tap(tester, find.byIcon(Icons.more_vert));
    await _waitFor(tester, find.text('Add people'));
    await _tap(tester, find.text('Add people'));
    await _waitFor(tester, find.text('Add people to Needl'));
    await _waitFor(tester, find.text('Dr Chitra Nair'));
    await _tap(tester, find.text('Dr Chitra Nair'));
    await _tap(tester, find.text('Add to Needl'));
    await _waitFor(tester, _text(r'^4 people'));
    final needl2 = _path().split('/').last;
    expect(needl2, isNot(needl1), reason: 'adder is moved into the new Needl at once');
    await _shot(tester, '17_needl_after_add');
    _log('STEP issue8_adder_ok');
    // Another member adds someone while Meera is looking at this Needl.
    await d.post('/channels/$needl2/expand', data: {'userIds': [asha1Id], 'history': 'all'}, options: arjun);
    await _waitFor(tester, find.textContaining('Open new Needl'));
    await _shot(tester, '18_needl_continued_line');
    await _tap(tester, find.textContaining('Open new Needl'));
    await _waitFor(tester, _text(r'^5 people'));
    await _shot(tester, '19_needl_opened_new');
    await _back(tester);
    _log('STEP issue8_live_ok');

    // ── Issue 5: handoff voice notes ─────────────────────────────────────
    unawaited(router.push(AppRoutes.spaceHandoffDetailPath(ward['_id'], handoffId)));
    await _waitFor(tester, find.text('VOICE HANDOVER'), timeout: const Duration(seconds: 30));
    await _shot(tester, '20_handoff_detail_voice');
    await _tap(tester, find.descendant(
        of: find.byKey(Key('voice-handoff-shift-$handoffId')), matching: find.byIcon(Icons.play_arrow_rounded)));
    await _waitFor(tester, find.byIcon(Icons.pause_rounded));
    await _shot(tester, '21_handoff_voice_playing');
    await _real(tester, const Duration(seconds: 4));
    await _back(tester);
    // Record one on a new draft (real emulator microphone).
    unawaited(router.push(AppRoutes.spaceHandoffCreatePath(ward['_id'])));
    await _waitFor(tester, find.byKey(const Key('shift-voice-note')), timeout: const Duration(seconds: 30));
    await tester.ensureVisible(find.byKey(const Key('handoff-voice-record')));
    await _tap(tester, find.byKey(const Key('handoff-voice-record')));
    await _waitFor(tester, find.byKey(const Key('handoff-voice-recording')), timeout: const Duration(seconds: 20));
    await _real(tester, const Duration(seconds: 3));
    await _shot(tester, '22_handoff_recording');
    await _tap(tester, find.descendant(
        of: find.byKey(const Key('handoff-voice-recording')), matching: find.byKey(const Key('composer-action'))));
    await _waitFor(tester, find.byKey(const Key('handoff-voice-player')), timeout: const Duration(seconds: 30));
    await _shot(tester, '23_handoff_recorded');
    _log('STEP issue5_record_ok');
    // Back on a form with a new voice note asks before discarding it.
    unawaited(tester.binding.handlePopRoute());
    await _waitFor(tester, find.text('Discard changes?'));
    await _shot(tester, '23b_handoff_discard_prompt');
    await _tap(tester, find.text('Discard'));
    await _real(tester, const Duration(seconds: 1));
    _log('STEP issue5_discard_prompt_ok');

    } // end of issues 1–12

    // ── Issue 13: Needl Voice ────────────────────────────────────────────
    final caps = await AppDependencies.instance.speechService.capabilities();
    _log('STEP issue13_speech available=${caps.available} onDevice=${caps.onDevice} '
        'fileInput=${caps.fileInput} tts=${caps.tts}');
    router.go(AppRoutes.messages);
    await _real(tester, const Duration(seconds: 1));
    unawaited(router.push(AppRoutes.dmPath(dmArjun)));
    await _waitFor(tester, find.byKey(const Key('open-needl-voice')));
    await _tap(tester, find.byKey(const Key('open-needl-voice')));
    await _waitFor(tester, find.byKey(const Key('needl-voice-talk')), timeout: const Duration(seconds: 20));
    await _real(tester, const Duration(seconds: 2));
    await _shot(tester, '40_needl_voice_open');
    // Hold to talk for ~3 s with the emulator microphone.
    final talk = tester.getCenter(find.byKey(const Key('needl-voice-talk')));
    final hold = await tester.startGesture(talk);
    await _real(tester, const Duration(milliseconds: 900));
    await _waitFor(tester, find.byKey(const Key('needl-voice-timer')), timeout: const Duration(seconds: 10));
    await _real(tester, const Duration(seconds: 3));
    await _shot(tester, '41_needl_voice_recording');
    await hold.up();
    await _real(tester, const Duration(seconds: 2));
    Future<List> arjunDm() async =>
        (await d.get('/channels/$dmArjun/messages', options: arjun)).data['data']['messages'] as List;
    Map? mine;
    final w2 = Stopwatch()..start();
    while (mine == null && w2.elapsed.inSeconds < 30) {
      await _real(tester, const Duration(seconds: 1));
      final voice = (await d.get('/channels/$dmArjun/messages',
              queryParameters: {'mode': 'voice'}, options: arjun))
          .data['data']['messages'] as List;
      mine = voice.cast<Map>().where((m) => m['type'] == 'audio' &&
          m['content']?['voiceMode'] == true).lastOrNull;
    }
    expect(mine, isNotNull, reason: 'the clip reached Arjun as a voice message');
    _log('STEP issue13_sent transcriptStatus=${mine!['content']['transcriptStatus']}');
    // Arjun answers with a clip + transcript: arrives live and auto-plays.
    final fd = FormData.fromMap({
      'context': 'message',
      'file': MultipartFile.fromBytes(_wav(), filename: 'reply.wav', contentType: DioMediaType('audio', 'wav')),
    });
    final up = await d.post('/media/upload', data: fd, options: arjun);
    final reply = await d.post('/channels/$dmArjun/messages', options: arjun, data: {
      'type': 'audio',
      'content': {'mediaUrl': up.data['data']['url'], 'mimeType': 'audio/wav', 'durationMs': 2000,
          'waveform': [20, 60, 90, 40, 70], 'transcriptStatus': 'pending', 'voiceMode': true},
    });
    final replyId = reply.data['data']['message']['_id'] as String;
    await d.patch('/channels/$dmArjun/messages/$replyId/transcript', options: arjun,
        data: {'status': 'done', 'transcript': 'Bed seven potassium is 3.1, starting replacement'});
    final card = find.byKey(Key('needl-voice-clip-$replyId'));
    await _waitFor(tester, card);
    await _real(tester, const Duration(milliseconds: 600));
    await _shot(tester, '42_needl_voice_incoming_autoplay');
    await tester.longPress(card);
    await _waitFor(tester, find.byKey(const Key('needl-voice-transcript')));
    expect(find.textContaining('potassium is 3.1'), findsOneWidget);
    await _shot(tester, '43_needl_voice_transcript');
    Navigator.of(tester.element(find.byKey(const Key('needl-voice-transcript')))).pop();
    await _real(tester, const Duration(milliseconds: 600));
    await _back(tester);
    await _back(tester);
    _log('STEP issue13_ok');

    // ── Issue 14: Voice bot (typed request; same pipeline as speech) ─────
    router.go(AppRoutes.home);
    await _waitFor(tester, find.byKey(const Key('open-voice-bot')));
    await _tap(tester, find.byKey(const Key('open-voice-bot')));
    await _waitFor(tester, find.byKey(const Key('voicebot-typed')));
    await _real(tester, const Duration(seconds: 2)); // live mic attempt settles
    await _shot(tester, '50_voicebot_open');
    Future<void> ask(String text) async {
      final f = find.byKey(const Key('voicebot-typed'));
      // As with the composer: enterText does not reach real fields under
      // this binding, so type through the field's controller.
      tester.widget<TextField>(f).controller!.value = TextEditingValue(
          text: text, selection: TextSelection.collapsed(offset: text.length));
      await _real(tester, const Duration(milliseconds: 300));
      await _tap(tester, find.byTooltip('Send request'));
      await _real(tester, const Duration(seconds: 2));
      final s = tester.element(f).read<VoiceBotCubit>().state;
      _log('STEP issue14_state "$text" phase=${s.phase.name} heard="${s.heard}" '
          'message="${s.message}" proposals=${s.proposals.length} ai=${s.usedAi}');
    }
    await ask('tell Arjun bed 7 is stable, BP 120/80');
    await _waitFor(tester, find.byKey(const Key('voicebot-confirm')), timeout: const Duration(seconds: 20));
    await _shot(tester, '51_voicebot_confirm_card');
    final before14 = (await arjunDm()).length;
    await _tap(tester, find.byKey(const Key('voicebot-confirm')));
    await _waitFor(tester, find.textContaining('Sent to'));
    final after14 = await arjunDm();
    expect(after14.length, before14 + 1);
    expect(after14.last['content']['text'], 'Bed 7 is stable, BP 120/80');
    await _shot(tester, '52_voicebot_sent');
    await ask("I'm in OT");
    await _waitFor(tester, find.byKey(const Key('voicebot-confirm')));
    await _tap(tester, find.byKey(const Key('voicebot-confirm')));
    await _waitFor(tester, find.textContaining('Status set'));
    final me = (await d.get('/users/me', options: meeraH)).data['data']['user'];
    expect(me['availability']['status'], 'in_ot');
    await _shot(tester, '53_voicebot_status');
    Navigator.of(tester.element(find.byKey(const Key('voicebot-typed')))).pop();
    await _real(tester, const Duration(seconds: 1));
    _log('STEP issue14_ok');

    // ── Issue 7: reply from the notification shade ───────────────────────
    router.go(AppRoutes.home);
    await GroupedMessageNotification.show(
      title: 'Dr Bala Krishnan',
      body: 'Can you see bed 7 now?',
      data: {'type': 'new_message', 'channelId': dmBala},
    );
    final replyText = 'Coming in 5 min ${DateTime.now().millisecondsSinceEpoch % 10000}';
    _log('DO_SHADE_REPLY:$replyText');
    var delivered = false;
    final w1 = Stopwatch()..start();
    // The host's UI automation of the shade alone takes up to ~60 s.
    while (!delivered && w1.elapsed.inSeconds < 150) {
      await _real(tester, const Duration(seconds: 1));
      final m = (await d.get('/channels/$dmBala/messages', options: bala)).data['data']['messages'] as List;
      delivered = m.any((x) => x['content']?['text'] == replyText &&
          (x['senderId'] is Map ? x['senderId']['_id'] : x['senderId']) == meeraId);
    }
    expect(delivered, isTrue, reason: 'reply from the shade reached the chat');
    _log('STEP issue7_reply_delivered ${w1.elapsedMilliseconds}ms');
    await _real(tester, const Duration(seconds: 4)); // host captures the shade

    _log('BETA1114_DONE');
  }, timeout: const Timeout(Duration(minutes: 40)));
}
