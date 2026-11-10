// On-device check: Profile › Appearance › Dark really darkens every main
// screen. Prints SHOT_<name> and holds the frame so a host script can
// screencap it. Pre-reqs: local backend on :5000 seeded with needl-seed.mjs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medcollab_app/app.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';

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

Future<void> _real(WidgetTester tester, Duration d) async {
  final w = Stopwatch()..start();
  while (w.elapsed < d) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _real(tester, const Duration(milliseconds: 800));
  // ignore: avoid_print
  print('SHOT_$name');
  await _real(tester, const Duration(seconds: 4));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.hitTestable().evaluate().isEmpty) await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.hitTestable().first);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Appearance › Dark darkens the app', (tester) async {
    AppDependencies.instance.init();
    await tester.pumpWidget(const MedCollabApp());
    final router = AppDependencies.instance.appRouter.router;
    final auth = AppDependencies.instance.authBloc;
    await _waitFor(tester, find.text('Continue'),
        timeout: const Duration(seconds: 40));
    auth.add(const AuthPhoneSubmitted('9100000001'));
    await _waitFor(tester, find.text('Verify & Continue'));
    auth.add(const AuthOtpSubmitted('123456'));
    await _waitFor(tester, _text(r'^Good '),
        timeout: const Duration(seconds: 30));

    router.go(AppRoutes.profile);
    await _waitFor(tester, find.text('Appearance'));
    await _tap(tester, find.text('Appearance'));
    await _waitFor(tester, find.text('Dark'));
    await _shot(tester, 'sheet_before');
    await _tap(tester, find.text('Dark'));
    await _real(tester, const Duration(seconds: 1));
    await _shot(tester, 'sheet_after');
    expect(AppColors.isDark, isTrue);
    // The open sheet itself must be dark now (it was stuck white).
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    final sheetBg = sheet.backgroundColor ??
        Theme.of(tester.element(find.text('Color theme')))
            .bottomSheetTheme
            .backgroundColor;
    expect(sheetBg!.computeLuminance() < 0.2, isTrue,
        reason: 'Appearance sheet stayed light: $sheetBg');
    Navigator.of(tester.element(find.text('Color theme'))).pop();
    await _real(tester, const Duration(milliseconds: 600));
    await _shot(tester, 'profile');

    router.go(AppRoutes.home);
    await _shot(tester, 'home');
    router.go(AppRoutes.messages);
    await _shot(tester, 'messages');
    await _waitFor(tester, _text(r'Bala'));
    await _tap(tester, _text(r'Bala').first);
    await _shot(tester, 'chat');
    router.go(AppRoutes.notifications);
    await _shot(tester, 'alerts');
    router.go(AppRoutes.handoffs);
    await _shot(tester, 'handoffs');
    router.go(AppRoutes.spacesList);
    await _shot(tester, 'needls');

    // Restore Light so later journeys start from the default.
    router.go(AppRoutes.profile);
    await _waitFor(tester, find.text('Appearance'));
    await _tap(tester, find.text('Appearance'));
    await _waitFor(tester, find.text('Light'));
    await _tap(tester, find.text('Light'));
    await _real(tester, const Duration(seconds: 1));
    expect(AppColors.isDark, isFalse);
    // ignore: avoid_print
    print('DARK_TOUR_DONE');
  });
}
