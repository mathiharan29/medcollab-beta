// On-device verification of beta round 11-18 (tester findings + Assistant,
// design, speed, Needl Voice separation) against a LOCAL backend seeded with
// medcollab-backend/tests/device/seed-1114.mjs. Host side:
// scripts/device-watch.ps1 -NoMicGrant -Done BETA1118_DONE.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medcollab_app/app.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/chat_wallpaper.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_cubit.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_sheet.dart';

const _api = 'http://10.0.2.2:5000/api';

Finder _text(String pattern) => find.byWidgetPredicate(
      (w) =>
          (w is Text && RegExp(pattern).hasMatch(w.data ?? '')) ||
          (w is RichText && RegExp(pattern).hasMatch(w.text.toPlainText())),
    );

void _log(String s) {
  // ignore: avoid_print
  print(s);
}

Future<void> _real(WidgetTester tester, Duration d) async {
  final w = Stopwatch()..start();
  while (w.elapsed < d) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _waitFor(WidgetTester tester, Finder f, {Duration timeout = const Duration(seconds: 25)}) async {
  final w = Stopwatch()..start();
  while (w.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 16));
    if (f.hitTestable().evaluate().isNotEmpty) return;
  }
  final texts = <String>[
    for (final e in find.byType(RichText).evaluate()) (e.widget as RichText).text.toPlainText(),
  ].where((t) => t.trim().isNotEmpty).take(40).join(' | ');
  _log('WAITFOR_DIAG exists=${f.evaluate().length} path=${_path()} texts=$texts');
  throw TestFailure('Timed out waiting for $f');
}

Future<void> _until(WidgetTester tester, bool Function() ok, String what,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final w = Stopwatch()..start();
  while (w.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 50));
    if (ok()) return;
  }
  throw TestFailure('Timed out: $what');
}

const _itChannel = MethodChannel('plugins.flutter.io/integration_test');
bool _surfaceIsImage = false;

Future<void> _shot(WidgetTester tester, String name) async {
  await _real(tester, const Duration(milliseconds: 700));
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  if (!_surfaceIsImage) {
    await binding.convertFlutterSurfaceToImage();
    _surfaceIsImage = true;
  } else {
    await _itChannel.invokeMethod<void>('convertFlutterSurfaceToImage');
  }
  await _real(tester, const Duration(milliseconds: 300));
  await binding.takeScreenshot(name);
  await _itChannel.invokeMethod<void>('revertFlutterImage');
  await _real(tester, const Duration(milliseconds: 200));
  _log('CAPTURED $name');
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.hitTestable().evaluate().isEmpty) await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.hitTestable().first);
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await _real(tester, const Duration(milliseconds: 600));
}

String _path() => AppDependencies.instance.appRouter.router.state.uri.path;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('beta 11-18 on device', (tester) async {
    final d = Dio(BaseOptions(baseUrl: _api));
    Future<Options> login(String phone) async {
      await d.post('/auth/request-otp', data: {'phone': phone});
      final r = await d.post('/auth/verify-otp', data: {'phone': phone, 'otp': '123456'});
      return Options(headers: {'Authorization': 'Bearer ${r.data['data']['accessToken']}'});
    }

    final meeraH = await login('+919100000001');
    final arjunH = await login('+919100000002');
    final balaH = await login('+919100000003');
    final dms = (await d.get('/channels/dm', options: meeraH)).data['data']['channels'] as List;
    String dmWith(String name) => dms.firstWhere((c) =>
        (c['members'] as List).length == 2 &&
        (c['members'] as List).any((m) => m['name'] == name))['_id'] as String;
    final dmArjun = dmWith('Arjun Rao');
    final dmBala = dmWith('Bala Krishnan');
    final needl = dms.firstWhere((c) => (c['members'] as List).length == 3)['_id'] as String;
    final spaces = (await d.get('/spaces', options: meeraH)).data['data']['spaces'] as List;
    final general = ((spaces.firstWhere((s) => s['name'] == 'Ward 5')['channels'] as List)
        .firstWhere((c) => c['name'] == 'general'))['_id'] as String;

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
    await tester.element(find.byType(Scaffold).first).read<ThemeModeCubit>().setMode(ThemeMode.light);
    await _real(tester, const Duration(seconds: 2));

    // ── E1: assistant is a bottom-right overlay ─────────────────────────
    final fab = find.byKey(const Key('open-voice-bot'));
    await _waitFor(tester, fab);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final c = tester.getCenter(fab);
    _log('STEP e1_fab_home x=${c.dx.round()}/${screen.width.round()} y=${c.dy.round()}/${screen.height.round()}');
    expect(c.dx, greaterThan(screen.width * 0.75));
    expect(c.dy, greaterThan(screen.height * 0.7));
    await _shot(tester, '60_home_assistant_fab');
    router.go(AppRoutes.messages);
    await _real(tester, const Duration(seconds: 2));
    await _waitFor(tester, fab);
    final fabRect = tester.getRect(fab);
    final pageFab = find.byType(FloatingActionButton).hitTestable();
    if (pageFab.evaluate().isNotEmpty) {
      final other = tester.getRect(pageFab.first);
      _log('STEP e1_fab_messages assistant=$fabRect pageFab=$other');
      expect(fabRect.overlaps(other), isFalse, reason: 'assistant sits above the page\'s own button');
    }
    await _shot(tester, '61_messages_assistant_fab');

    // ── E1: microphone permission is asked, not a glitch ─────────────────
    await _tap(tester, fab);
    await _waitFor(tester, find.byKey(const Key('voicebot-typed')));
    VoiceBotCubit bot() => tester.element(find.byKey(const Key('voicebot-typed'))).read<VoiceBotCubit>();
    _log('DO_ALLOW_MIC');
    await _until(tester, () => bot().state.mic == MicAccess.granted, 'microphone granted through the prompt',
        timeout: const Duration(seconds: 40));
    await _real(tester, const Duration(milliseconds: 800));
    _log('STEP e1_mic_granted phase=${bot().state.phase.name} message="${bot().state.message}"');
    await _shot(tester, '62_assistant_listening_after_allow');
    await bot().cancel();
    await _real(tester, const Duration(milliseconds: 500));

    Future<VoiceBotState> ask(String text) async {
      await bot().handleText(text);
      await _real(tester, const Duration(milliseconds: 900));
      final s = bot().state;
      _log('STEP ask "$text" phase=${s.phase.name} message="${s.message}" '
          'proposals=${s.proposals.map((p) => p.runtimeType).toList()} notes=${s.notes}');
      return s;
    }

    // General question (built-in answer; AI half if the server has a key).
    final llm = await AppDependencies.instance.assistantRepository.llmAvailable();
    _log('STEP e6_ai_configured=$llm');
    var s = await ask('what time is it');
    expect(s.phase, VoiceBotPhase.done);
    expect(s.message, startsWith('It is '));
    s = await ask('what can you do');
    expect(s.message, contains('handoff'));
    await _shot(tester, '63_assistant_answers');

    // F2: handoff fields spelled out; misheard words flagged, not used.
    s = await ask('hand off bed 12 to Arjun the sky');
    final h = s.proposals.single as HandoffAction;
    expect(h.patients.single.bed, '12');
    expect(h.summary, isEmpty);
    expect(h.unclear.single, contains('the sky'));
    await _waitFor(tester, find.byKey(const Key('voicebot-handoff-beds')));
    await _shot(tester, '64_assistant_handoff_fields');
    bot().dismiss(h);
    await _real(tester, const Duration(milliseconds: 400));

    // F4: unknown name → explicit pick, never a near-sounding guess.
    s = await ask('open chat with Dr mama');
    expect((s.proposals.single as ClarifyAction).unmatched, isTrue);
    await _waitFor(tester, find.byKey(const Key('voicebot-pick')));
    await _shot(tester, '65_assistant_unknown_name');
    await _tap(tester, find.byKey(const Key('voicebot-pick')));
    await _waitFor(tester, find.byKey(const Key('voicebot-pick-search')));
    await _shot(tester, '66_assistant_pick_colleague');
    await _tap(tester, find.text('Dr Arjun Rao').last);
    await _real(tester, const Duration(milliseconds: 800));
    expect((bot().state.proposals.single as OpenChatAction).to.name, 'Dr Arjun Rao');
    bot().dismiss(bot().state.proposals.single);
    await _real(tester, const Duration(milliseconds: 400));

    // F1 / FR-AST-25: two fast taps on Send → exactly one stored message.
    Future<List> balaDm() async =>
        (await d.get('/channels/$dmBala/messages', options: balaH)).data['data']['messages'] as List;
    final before = (await balaDm()).length;
    s = await ask('tell Bala that the check is complete');
    await _waitFor(tester, find.byKey(const Key('voicebot-confirm')));
    final send = find.byKey(const Key('voicebot-confirm'));
    await tester.tap(send);
    await tester.tap(send, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(send, warnIfMissed: false);
    await _waitFor(tester, find.textContaining('Sent to'));
    await _real(tester, const Duration(seconds: 2));
    final after = await balaDm();
    _log('STEP f1_double_tap before=$before after=${after.length}');
    expect(after.length, before + 1, reason: 'one confirmed proposal → one stored message');
    expect(after.last['content']['text'], 'The check is complete');
    await _shot(tester, '67_assistant_sent_once');

    // F6: "General" resolves to the only #general.
    s = await ask('open chat with General');
    expect((s.proposals.single as OpenChatAction).to.id, 'c:$general');
    await _shot(tester, '68_assistant_general');
    await _tap(tester, find.byKey(const Key('voicebot-confirm')));
    await _until(tester, () => _path().contains(general), 'opened #general');
    await _real(tester, const Duration(seconds: 1));
    _log('STEP f6_general_open path=${_path()}');
    expect(find.byType(VoiceBotPanel), findsNothing, reason: 'assistant closes when it opens a chat');
    await _back(tester);

    // ── E2: Vocle's own clinical chat look ───────────────────────────────
    router.go(AppRoutes.messages);
    await _real(tester, const Duration(seconds: 1));
    unawaited(router.push(AppRoutes.dmPath(dmArjun)));
    await _waitFor(tester, find.byKey(const Key('composer-field')));
    await _real(tester, const Duration(seconds: 2));
    // Beta 11-26: Needl Voice is opened from the chat header again.
    expect(find.byKey(const Key('open-needl-voice')), findsOneWidget);
    await _shot(tester, '71_chat_clinical_light');
    await tester.element(find.byType(Scaffold).first).read<ThemeModeCubit>().setMode(ThemeMode.dark);
    await _real(tester, const Duration(seconds: 2));
    await _shot(tester, '72_chat_clinical_dark');
    await tester.element(find.byType(Scaffold).first).read<ThemeModeCubit>().setMode(ThemeMode.light);
    await _real(tester, const Duration(seconds: 1));
    await _back(tester);

    // E4: curated chat themes (Profile → Chat theme).
    router.go(AppRoutes.profile);
    await _real(tester, const Duration(seconds: 1));
    // The Profile row exists; open the page it opens (the row sits below the
    // fold behind other tabs' scroll views, which makes scrolling flaky).
    expect(find.text('Chat theme', skipOffstage: false), findsWidgets);
    unawaited(ChatWallpaperPage.open(tester.element(find.text('Chat theme', skipOffstage: false).first)));
    await _waitFor(tester, find.text('Scrubs'));
    expect(find.text('Mint'), findsNothing);
    expect(fab.hitTestable(), findsNothing, reason: 'sub-pages cover the assistant button');
    expect(find.text('Blush'), findsNothing);
    await _shot(tester, '73_chat_themes');
    await _back(tester);

    // ── E5: Needl Voice, opened from the chat, stored apart from it ───────
    router.go(AppRoutes.messages);
    await _real(tester, const Duration(seconds: 1));
    unawaited(router.push(AppRoutes.dmPath(dmArjun)));
    await _waitFor(tester, find.byKey(const Key('open-needl-voice')));
    await _tap(tester, find.byKey(const Key('open-needl-voice')));
    await _waitFor(tester, find.byKey(const Key('needl-voice-talk')), timeout: const Duration(seconds: 20));
    Future<List<Map>> voiceClips() async =>
        ((await d.get('/channels/$dmArjun/messages', queryParameters: {'mode': 'voice'}, options: arjunH))
                .data['data']['messages'] as List)
            .cast<Map>();
    final known = {for (final m in await voiceClips()) m['_id']};
    final talk = tester.getCenter(find.byKey(const Key('needl-voice-talk')));
    final hold = await tester.startGesture(talk);
    await _real(tester, const Duration(milliseconds: 900));
    await _waitFor(tester, find.byKey(const Key('needl-voice-timer')), timeout: const Duration(seconds: 10));
    await _real(tester, const Duration(seconds: 3));
    await hold.up();
    Map? clip;
    final w = Stopwatch()..start();
    while (clip == null && w.elapsed.inSeconds < 30) {
      await _real(tester, const Duration(seconds: 1));
      clip = (await voiceClips())
          .where((m) => m['content']?['voiceMode'] == true && !known.contains(m['_id']))
          .lastOrNull;
    }
    expect(clip, isNotNull, reason: 'clip stored in the voice space');
    final chat = (await d.get('/channels/$dmArjun/messages', options: arjunH)).data['data']['messages'] as List;
    expect(chat.any((m) => m['_id'] == clip!['_id']), isFalse, reason: 'not in the text chat');
    _log('STEP e5_separate clip=${clip!['_id']} inChat=false');
    await _shot(tester, '75_needl_voice_clip_sent');
    await _back(tester);
    await _waitFor(tester, find.byKey(const Key('composer-field')));
    await _real(tester, const Duration(seconds: 2));
    await _shot(tester, '77_text_chat_without_voice_clip');
    await _back(tester);

    // ── F (FR-NDL-53): Needl members panel fits ──────────────────────────
    unawaited(router.push(AppRoutes.dmPath(needl)));
    await _waitFor(tester, find.byKey(const Key('composer-field')));
    await _waitFor(tester, find.text('3 people · Tap for list'));
    await _tap(tester, find.text('3 people · Tap for list'));
    await _waitFor(tester, find.text('People in this Needl'));
    await _shot(tester, '78_needl_members');
    await _back(tester);
    await _back(tester);

    // ── E3: page speed ───────────────────────────────────────────────────
    Future<int> timePush(String route, Finder ready) async {
      router.go(AppRoutes.messages);
      await _real(tester, const Duration(milliseconds: 800));
      final sw = Stopwatch()..start();
      unawaited(router.push(route));
      await _until(tester, () {
        if (ready.hitTestable().evaluate().isEmpty) return false;
        final r = ModalRoute.of(ready.evaluate().first);
        return r?.animation?.status == AnimationStatus.completed;
      }, 'route $route settled');
      return sw.elapsedMilliseconds;
    }

    final times = <String, List<int>>{};
    for (var i = 0; i < 3; i++) {
      (times['dm'] ??= []).add(await timePush(AppRoutes.dmPath(dmArjun), find.byKey(const Key('composer-field'))));
      (times['needl'] ??= []).add(await timePush(AppRoutes.dmPath(needl), find.byKey(const Key('composer-field'))));
      (times['search'] ??= []).add(await timePush(AppRoutes.search, find.byType(TextField)));
    }
    for (final e in times.entries) {
      final v = [...e.value]..sort();
      _log('TIMING page_${e.key} median=${v[1]}ms runs=${e.value}');
    }
    final tabs = <int>[];
    for (final t in [AppRoutes.home, AppRoutes.messages, AppRoutes.handoffs, AppRoutes.notifications, AppRoutes.profile]) {
      final sw = Stopwatch()..start();
      router.go(t);
      await _until(tester, () => _path() == t, 'tab $t');
      await tester.pump();
      tabs.add(sw.elapsedMilliseconds);
    }
    _log('TIMING tabs ms=$tabs');

    _log('BETA1118_DONE');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
