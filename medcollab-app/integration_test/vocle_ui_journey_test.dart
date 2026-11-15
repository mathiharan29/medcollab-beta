// End-to-end UI journey on a real device/emulator (REQ 13 + UI audit).
//
// Drives the real app against the LOCAL dev backend (debug/profile builds
// default to http://10.0.2.2:5000, OTP bypass 123456). Covers sign-in, every
// main tab, chats (open at latest, send), back-to-Home, tab swipe, handoffs,
// alerts, search, profile, and the same key screens in dark mode. Each step
// is timed from action to content-visible and any Flutter UI error fails it.
//
// Run (profile timings):
//   flutter drive --profile --driver=test_driver/ui_journey_driver.dart \
//     --target=integration_test/vocle_ui_journey_test.dart -d emulator-5554
//
// Requires the seeded dev users: Dr Asha Rao +919100000001 in group
// "Medicine Unit 3" with a DM to Dr Vikram Shah.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medcollab_app/app.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_nav_bar.dart';

final _timings = <String, int>{};
final _errors = <String>[];

Future<int> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 16));
    // Only what is actually on screen: swipeable tabs keep every tab page
    // alive, so off-screen pages also contain matching widgets.
    if (finder.hitTestable().evaluate().isNotEmpty) {
      return watch.elapsedMilliseconds;
    }
  }
  throw TestFailure('Timed out after ${timeout.inSeconds}s waiting for $finder');
}

/// Runs [action], waits for [until], records elapsed ms under [name].
Future<void> _step(
  WidgetTester tester,
  String name,
  Future<void> Function() action,
  Finder until, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final watch = Stopwatch()..start();
  await action();
  await _waitFor(tester, until, timeout: timeout);
  _timings[name] = watch.elapsedMilliseconds;
  // Let the screen settle a little and surface any build/layout errors.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final error = tester.takeException();
  if (error != null) _errors.add('$name: $error');
  // ignore: avoid_print
  print('STEP $name ${_timings[name]} ms');
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  final visible = f.hitTestable();
  if (visible.evaluate().isEmpty) await tester.ensureVisible(f.first);
  await tester.tap(f.hitTestable().first);
}

/// Sets a field's text through its controller (the device IME owns real
/// keyboard input in integration tests, so enterText does not reach it).
Future<void> _setText(WidgetTester tester, Finder field, String text) async {
  final widget = tester.widget<TextField>(field);
  final controller = widget.controller;
  if (controller == null) throw TestFailure('TextField without controller');
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  widget.onChanged?.call(text);
  await tester.pump();
}

/// Horizontal swipe across the header, in logical pixels.
Future<void> _swipe(WidgetTester tester, {required bool left}) async {
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  final y = size.height * 0.11; // header band, clear of inner scrollables
  final start = Offset(left ? size.width * 0.9 : size.width * 0.1, y);
  await tester.flingFrom(start, Offset((left ? -1 : 1) * size.width * 0.7, 0), 2000);
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}

Finder _text(String pattern) => find.byWidgetPredicate(
      (w) =>
          (w is Text && RegExp(pattern).hasMatch(w.data ?? '')) ||
          (w is RichText && RegExp(pattern).hasMatch(w.text.toPlainText())),
    );

Finder _navItem(String label) => find.descendant(
      of: find.byType(AppNavBar),
      matching: find.text(label),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Vocle UI journey', (tester) async {
    final launch = Stopwatch()..start();
    AppDependencies.instance.init();
    await tester.pumpWidget(const MedCollabApp());

    // ── Sign in (or resume a saved session) ────────────────────────────
    final home = _text(r'^Good (morning|afternoon|evening|night)$');
    final phone = find.text('Continue');
    await _waitFor(tester, find.byWidgetPredicate(
      (w) => w is Text && (RegExp(r'^Good ').hasMatch(w.data ?? '') || w.data == 'Continue'),
    ));
    if (phone.evaluate().isNotEmpty && home.evaluate().isEmpty) {
      _timings['launch_to_phone_screen'] = launch.elapsedMilliseconds;
      // On a device the real IME owns text input, so sign in through the
      // same AuthBloc events the phone/OTP screens dispatch.
      final auth = AppDependencies.instance.authBloc;
      await _step(tester, 'phone_to_otp',
          () async => auth.add(const AuthPhoneSubmitted('9100000001')),
          find.text('Verify & Continue'));
      await _step(tester, 'otp_to_home',
          () async => auth.add(const AuthOtpSubmitted('123456')), home);
    } else {
      _timings['launch_to_home_session_restore'] = launch.elapsedMilliseconds;
    }

    // ── Main tabs ──────────────────────────────────────────────────────
    await _step(tester, 'tab_messages', () => _tap(tester, _navItem('Messages')),
        find.text('Direct'));
    // Leave any in-hub group view so we are on the hub lists.
    if (find.text('Medicine Unit 3').evaluate().isNotEmpty &&
        find.text('Direct').evaluate().isEmpty) {
      await _tap(tester, find.byTooltip('Back'));
    }
    await _step(tester, 'tab_handoffs', () => _tap(tester, _navItem('Handoffs')),
        find.text('Pending'));
    await _step(tester, 'tab_alerts', () => _tap(tester, _navItem('Alerts')),
        find.text('All'));
    await _step(tester, 'tab_profile', () => _tap(tester, _navItem('Profile')),
        find.text('Edit profile'));
    await _step(tester, 'tab_home', () => _tap(tester, _navItem('Home')), home);

    // ── REQ 8: swipe between main tabs ──────────────────────────────────
    await _step(tester, 'swipe_home_to_messages',
        () => _swipe(tester, left: true),
        find.text('Direct'));
    await _step(tester, 'swipe_messages_to_home',
        () => _swipe(tester, left: false),
        home);

    // ── DM: open at latest, send, back to Home (REQ 2 / REQ 3) ─────────
    await _tap(tester, _navItem('Messages'));
    await _waitFor(tester, find.text('Direct'));
    await _tap(tester, find.text('Direct'));
    await _waitFor(tester, find.text('Dr Vikram Shah'));
    await _step(tester, 'open_dm',
        () => _tap(tester, find.text('Dr Vikram Shah')),
        find.byType(TextField));
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
    final msg = 'UI journey $stamp';
    await _setText(tester, find.byType(TextField).last, msg);
    await _step(tester, 'send_dm_message',
        () => _tap(tester, find.byIcon(Icons.send_rounded)),
        find.descendant(of: find.byType(ListView), matching: _text(msg)));
    await _step(tester, 'back_from_dm_to_home', () => _systemBack(tester), home);

    // ── Group channel opens at latest (REQ 2) ───────────────────────────
    await _tap(tester, _navItem('Messages'));
    await _waitFor(tester, find.text('Groups'));
    await _tap(tester, find.text('Groups'));
    await _waitFor(tester, find.text('Medicine Unit 3'));
    await _step(tester, 'open_group', () => _tap(tester, find.text('Medicine Unit 3')),
        find.text('#general'));
    await _step(tester, 'open_channel', () => _tap(tester, find.text('#general')),
        find.byType(TextField));
    // Messages load after the composer appears; wait for the list itself.
    _timings['channel_messages_visible'] = await _waitFor(
      tester,
      find.byWidgetPredicate((w) => w is ListView && w.reverse),
      timeout: const Duration(seconds: 10),
    );
    await _step(tester, 'back_from_channel_to_home', () => _systemBack(tester), home);

    // ── Handoffs detail ────────────────────────────────────────────────
    await _tap(tester, _navItem('Handoffs'));
    await _waitFor(tester, find.text('Pending'));
    await _tap(tester, find.text('Active'));
    await tester.pump(const Duration(milliseconds: 400));
    final card = _text(r'Bed \d+');
    if (card.evaluate().isNotEmpty) {
      await _step(tester, 'open_handoff_detail', () => _tap(tester, card),
          _text(r'PATIENT'));
      await _systemBack(tester);
    } else {
      _errors.add('handoffs: no active handoff card (seed data missing?)');
    }
    // REQ 3: system back from any tab lands on Home.
    if (home.hitTestable().evaluate().isEmpty) await _systemBack(tester);
    await _waitFor(tester, home);

    // ── Search ─────────────────────────────────────────────────────────
    await _tap(tester, find.byTooltip('Search').first);
    await _waitFor(tester, find.text('Search your workspace'));
    await _setText(tester, find.byType(TextField).first, 'potassium');
    await _step(tester, 'search_results', () async {}, _text('potassium'),
        timeout: const Duration(seconds: 10));
    await _systemBack(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await _systemBack(tester);
    await _waitFor(tester, home);

    // ── Profile › Edit profile ──────────────────────────────────────────
    await _tap(tester, _navItem('Profile'));
    await _waitFor(tester, find.text('Edit profile'));
    await _step(tester, 'open_edit_profile',
        () => _tap(tester, find.text('Edit profile')), find.text('Save changes'));
    await _systemBack(tester);
    await _waitFor(tester, home);

    // ── Dark mode pass (REQ 6) ──────────────────────────────────────────
    await _tap(tester, _navItem('Profile'));
    await _waitFor(tester, find.text('Appearance'));
    await _tap(tester, find.text('Appearance'));
    await _waitFor(tester, find.text('Dark'));
    await _step(tester, 'switch_to_dark', () => _tap(tester, find.text('Dark')),
        find.text('Dark'));
    await _systemBack(tester); // closes the sheet
    await tester.pump(const Duration(milliseconds: 300));
    for (final tab in ['Home', 'Messages', 'Handoffs', 'Alerts', 'Profile']) {
      await _step(tester, 'dark_tab_${tab.toLowerCase()}',
          () => _tap(tester, _navItem(tab)), _navItem(tab));
    }
    final scaffoldBg = Theme.of(tester.element(find.byType(Scaffold).last))
        .scaffoldBackgroundColor;
    expect(scaffoldBg.computeLuminance(), lessThan(0.2),
        reason: 'dark theme active');
    // Restore light so the device is left as found.
    await _tap(tester, find.text('Appearance'));
    await _waitFor(tester, find.text('Light'));
    await _tap(tester, find.text('Light'));
    await tester.pump(const Duration(milliseconds: 300));
    await _systemBack(tester);

    binding.reportData = {
      'timings_ms': _timings,
      'ui_errors': _errors,
      'over_1s': {
        for (final e in _timings.entries)
          if (e.value > 1000) e.key: e.value,
      },
    };
    expect(_errors, isEmpty, reason: 'no Flutter UI errors on any screen');
  });
}
