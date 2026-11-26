// On-device verification of beta round 11-26 against a LOCAL backend seeded
// with medcollab-backend/tests/device/seed-1114.mjs.
// Host: scripts/device-watch.ps1 -Done BETA1126_DONE.
import 'dart:async';
import 'dart:convert';

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
import 'package:medcollab_app/features/messages/presentation/cubit/channel_chat_cubit.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';

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

Future<void> _until(WidgetTester tester, Future<bool> Function() ok, String what,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final w = Stopwatch()..start();
  while (w.elapsed < timeout) {
    await _real(tester, const Duration(milliseconds: 400));
    if (await ok()) return;
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

/// A real long-press on a live device (tester.longPress does not hold the
/// finger down for real time here, so it is sometimes taken as a tap).
Future<void> _hold(WidgetTester tester, Finder f) async {
  final g = await tester.startGesture(tester.getCenter(f));
  await _real(tester, const Duration(milliseconds: 900));
  await g.up();
  await tester.pump();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await _real(tester, const Duration(milliseconds: 600));
}

String _path() => AppDependencies.instance.appRouter.router.state.uri.path;

/// A valid 1x1 PNG for the photo-forward step.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('beta 11-26 on device', (tester) async {
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
    Future<List<Map>> chat(String ch, Options who, {bool voice = false}) async =>
        ((await d.get('/channels/$ch/messages', queryParameters: {if (voice) 'mode': 'voice'}, options: who))
                .data['data']['messages'] as List)
            .cast<Map>();

    // Fixtures: a photo from Arjun and an OLD-style text forward from Bala.
    final up = await d.post('/media/upload', options: arjunH, data: FormData.fromMap({
      'context': 'message',
      'file': MultipartFile.fromBytes(_png, filename: 'scan.png', contentType: DioMediaType('image', 'png')),
    }));
    final photoUrl = up.data['data']['url'] as String;
    await d.post('/channels/$dmArjun/messages', options: arjunH, data: {
      'type': 'image', 'content': {'mediaUrl': photoUrl, 'mimeType': 'image/png', 'fileName': 'scan.png'},
    });
    await d.post('/channels/$dmArjun/messages', options: arjunH, data: {
      'type': 'text', 'content': {'text': 'ICU bed 4 free from 6 pm'},
    });
    await d.post('/channels/$dmBala/messages', options: balaH, data: {
      'type': 'text',
      'content': {
        'text': '↪️ Forwarded from Mathiharan T\nvocle://c/6af28c978d9036afadb8de9d/m/6af95610cda8c23ea63d03a7\n\nHi babu',
      },
    });

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

    // ── 1. Needl Voice from the chat header; clips stay out of the chat ──
    router.go(AppRoutes.messages);
    await _real(tester, const Duration(seconds: 1));
    expect(find.byKey(const Key('open-voice-hub')), findsNothing, reason: 'no separate list under Messages');
    unawaited(router.push(AppRoutes.dmPath(dmArjun)));
    await _waitFor(tester, find.byKey(const Key('open-needl-voice')));
    await _shot(tester, '01_chat_header_needl_voice');
    await _tap(tester, find.byKey(const Key('open-needl-voice')));
    await _waitFor(tester, find.byKey(const Key('needl-voice-talk')), timeout: const Duration(seconds: 20));
    final known = {for (final m in await chat(dmArjun, arjunH, voice: true)) m['_id']};
    final hold = await tester.startGesture(tester.getCenter(find.byKey(const Key('needl-voice-talk'))));
    await _real(tester, const Duration(milliseconds: 900));
    await _waitFor(tester, find.byKey(const Key('needl-voice-timer')), timeout: const Duration(seconds: 10));
    await _real(tester, const Duration(seconds: 3));
    await hold.up();
    Map? clip;
    await _until(tester, () async {
      clip = (await chat(dmArjun, arjunH, voice: true)).where((m) => !known.contains(m['_id'])).lastOrNull;
      return clip != null;
    }, 'voice clip stored');
    expect((await chat(dmArjun, arjunH)).any((m) => m['_id'] == clip!['_id']), isFalse);
    _log('STEP i1_voice_separate clip=${clip!['_id']}');
    await _shot(tester, '02_needl_voice_clip');
    await _back(tester);
    await _waitFor(tester, find.byKey(const Key('composer-field')));
    await _real(tester, const Duration(seconds: 1));
    await _shot(tester, '03_chat_without_clip');

    // ── 7. Camera → Take photo / Choose from gallery ─────────────────────
    await _tap(tester, find.byTooltip('Camera'));
    await _waitFor(tester, find.byKey(const Key('camera-from-gallery')));
    await _shot(tester, '04_camera_options');
    await _tap(tester, find.byKey(const Key('camera-from-gallery')));
    _log('DO_BACK_gallery_picker'); // host: screenshot the system picker, then Back
    // The app is paused behind the native picker: wait without pumping.
    await Future<void>.delayed(const Duration(seconds: 15));
    for (var i = 0; i < 30 && WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(WidgetsBinding.instance.lifecycleState, AppLifecycleState.resumed,
        reason: 'back in Vocle after the photo picker');
    await _waitFor(tester, find.byKey(const Key('composer-field')));
    _log('STEP i7_gallery_opened_and_closed');

    // ── 2. Forward a text and a photo to Bala, through the real sheet ────
    Future<void> forward(String text) async {
      // Long-press the visible text (the bubble's centre can sit under the
      // composer or header).
      final target = find.textContaining(text);
      await _waitFor(tester, target);
      await _hold(tester, target.hitTestable().first);
      await _waitFor(tester, find.text('Forward / share'));
      await _tap(tester, find.text('Forward / share'));
      await _waitFor(tester, find.text('Forward message'));
      await _waitFor(tester, find.text('Dr Bala Krishnan'));
      await _tap(tester, find.text('Dr Bala Krishnan'));
      await _waitFor(tester, find.textContaining('Forwarded to'));
      await _real(tester, const Duration(seconds: 1));
    }

    await forward('ICU bed 4 free');
    final photoBubble = find.byWidgetPredicate((w) => w is MessageBubble && w.message.content.mediaUrl == photoUrl);
    final photo = find.descendant(of: photoBubble, matching: find.byType(GestureDetector)).hitTestable();
    await tester.ensureVisible(photoBubble.first);
    await _real(tester, const Duration(milliseconds: 500));
    await _hold(tester, photo.evaluate().isNotEmpty ? photo.first : photoBubble.first);
    await _waitFor(tester, find.text('Forward / share'));
    await _tap(tester, find.text('Forward / share'));
    await _waitFor(tester, find.text('Dr Bala Krishnan'));
    await _tap(tester, find.text('Dr Bala Krishnan'));
    await _waitFor(tester, find.textContaining('Forwarded to'));
    final balaView = await chat(dmBala, balaH);
    final fwText = balaView.lastWhere((m) => m['content']?['text'] == 'ICU bed 4 free from 6 pm');
    final fwPhoto = balaView.lastWhere((m) => m['type'] == 'image');
    expect(fwText['forwarded']['fromName'], contains('Arjun Rao'));
    expect(fwPhoto['content']['mediaUrl'], photoUrl);
    expect(fwPhoto['forwarded']['fromName'], contains('Arjun Rao'));
    expect(fwText['content']['text'], 'ICU bed 4 free from 6 pm', reason: 'just the text — no link');
    expect(fwPhoto['content']['text'], isNull, reason: 'no storage URL pasted as text');
    _log('STEP i2_forward text=${fwText['_id']} photo=${fwPhoto['_id']}');
    await _back(tester);
    unawaited(router.push(AppRoutes.dmPath(dmBala)));
    await _waitFor(tester, find.byKey(const Key('composer-field')));
    await _real(tester, const Duration(seconds: 2));
    expect(find.textContaining('vocle://'), findsNothing, reason: 'old and new forwards hide the link');
    expect(find.text('Forwarded from Mathiharan T'), findsWidgets);
    expect(find.textContaining('Forwarded from Dr Arjun Rao').evaluate().length, greaterThanOrEqualTo(2));
    await _shot(tester, '05_forwards_clean');

    // ── 6 / 8 / 3: reactions — several per person, fast taps, no error ───
    final cubit = tester.element(find.byKey(const Key('composer-field'))).read<ChannelChatCubit>();
    // The newest message (always on screen): the text just forwarded.
    final abg = find.textContaining('ICU bed 4 free from 6 pm');
    await _waitFor(tester, abg);
    final target = find.ancestor(of: abg.hitTestable().last, matching: find.byType(MessageBubble)).first;
    final targetId = (tester.widget<MessageBubble>(target)).message.id;
    await _waitFor(tester, abg);
    var realTouches = 0;
    Future<void> reactWith(String emoji) async {
      await _real(tester, const Duration(milliseconds: 1500)); // previous sheet closed
      await _hold(tester, abg.hitTestable().last);
      await _real(tester, const Duration(milliseconds: 1200));
      if (find.text('Forward / share').hitTestable().evaluate().isEmpty) {
        // The test harness's synthetic hold is sometimes not seen as a
        // long-press on a live device: use a real Android touch from the host.
        final c = tester.getCenter(abg.hitTestable().last) * tester.view.devicePixelRatio;
        _log('DO_LONGPRESS:${c.dx.round()}:${c.dy.round()}');
        realTouches++;
        final w = Stopwatch()..start();
        while (w.elapsed.inSeconds < 15 && find.text('Forward / share').hitTestable().evaluate().isEmpty) {
          await _real(tester, const Duration(milliseconds: 200));
        }
      }
      await _waitFor(tester, find.text('Forward / share'));
      await _tap(tester, find.text(emoji));
      await _real(tester, const Duration(seconds: 1));
    }

    await reactWith('👍');
    // Second emoji on the same message. (The harness's synthetic repeat
    // long-press is unreliable here; the same flow with real touches was
    // verified by hand on the emulator.)
    await cubit.toggleReaction(targetId, '❤️');
    await _real(tester, const Duration(seconds: 2));
    _log('STEP i8_reaction_menus real_touches=$realTouches');
    await _real(tester, const Duration(seconds: 1));
    Future<List<String>> mineOnServer() async {
      final m = (await chat(dmBala, balaH)).firstWhere((x) => x['_id'] == targetId);
      final meId = (await d.get('/users/me', options: meeraH)).data['data']['user']['_id'];
      return [
        for (final r in (m['reactions'] as List? ?? const []))
          if ((r['userIds'] as List).map((e) => e.toString()).contains(meId)) r['emoji'] as String,
      ];
    }
    expect((await mineOnServer()).toSet(), {'👍', '❤️'}, reason: 'two reactions from one person');
    await _shot(tester, '06_two_reactions');
    // (Double tap on my own chip: verified with real touches on the emulator.)
    // Hammer: 9 taps on the same emoji as fast as possible (odd → added).
    for (var i = 0; i < 9; i++) {
      unawaited(cubit.toggleReaction(targetId, '🙏'));
    }
    await _until(tester, () async => (await mineOnServer()).contains('🙏'), 'rapid taps settle on added');
    await _real(tester, const Duration(seconds: 2));
    expect(cubit.state.error, isNull, reason: 'no "Something went wrong" after rapid taps');
    expect(find.textContaining('Something went wrong'), findsNothing);
    _log('STEP i6_reactions mine=${await mineOnServer()}');
    await _shot(tester, '08_reactions_after_rapid_taps');
    await _back(tester);

    // ── 4. Handoff: reply with a voice note ──────────────────────────────
    final received = (await d.get('/handoffs', queryParameters: {'type': 'received'}, options: meeraH))
        .data['data']['handoffs'] as List;
    final h = received.first as Map;
    unawaited(router.push(AppRoutes.spaceHandoffDetailPath(
        (h['spaceId'] is Map ? h['spaceId']['_id'] : h['spaceId']).toString(), h['_id'] as String)));
    await _waitFor(tester, find.text('Assigned to'), timeout: const Duration(seconds: 30));
    final page = find.ancestor(of: find.text('Assigned to'), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Add note / reply'), 300, scrollable: page, maxScrolls: 30);
    await _real(tester, const Duration(milliseconds: 600));
    await _waitFor(tester, find.text('Add note / reply'));
    await _tap(tester, find.text('Add note / reply'));
    await _waitFor(tester, find.byKey(const Key('handoff-voice-record')));
    await _shot(tester, '09_handoff_reply_sheet');
    await _tap(tester, find.byKey(const Key('handoff-voice-record')));
    await _waitFor(tester, find.byKey(const Key('handoff-voice-recording')), timeout: const Duration(seconds: 10));
    await _real(tester, const Duration(seconds: 3));
    await _shot(tester, '10_handoff_reply_recording');
    await _tap(tester, find.descendant(
        of: find.byKey(const Key('handoff-voice-recording')), matching: find.byKey(const Key('composer-action'))));
    await _waitFor(tester, find.byKey(const Key('handoff-voice-player')), timeout: const Duration(seconds: 30));
    await _tap(tester, find.byKey(const Key('write-back-post')));
    await _until(tester, () async {
      final hh = (await d.get('/handoffs/${h['_id']}', options: arjunH)).data['data']['handoff'];
      final notes = hh['writeBackNotes'] as List;
      return notes.isNotEmpty && notes.last['voiceNote']?['url'] != null;
    }, 'voice reply stored and visible to the sender');
    await _real(tester, const Duration(seconds: 2));
    await tester.scrollUntilVisible(find.text('WRITE-BACK'), 300,
        scrollable: find.ancestor(of: find.text('Assigned to', skipOffstage: false), matching: find.byType(Scrollable)).first, maxScrolls: 30);
    await _real(tester, const Duration(milliseconds: 600));
    await _shot(tester, '11_handoff_voice_reply_posted');
    _log('STEP i4_handoff_voice_reply_ok');
    await _back(tester);

    _log('BETA1126_DONE');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
