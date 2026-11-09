// OTP auto-read on device: the host sends a real SMS to the emulator and taps
// Android's "Allow" (SMS User Consent); the app must fill the code and sign in
// without anyone typing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medcollab_app/app.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';

Future<void> _waitFor(WidgetTester tester, Finder f, Duration timeout) async {
  final w = Stopwatch()..start();
  while (w.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OTP is read from the SMS after Allow', (tester) async {
    AppDependencies.instance.init();
    await tester.pumpWidget(const MedCollabApp());
    await _waitFor(tester, find.text('Continue'), const Duration(seconds: 40));
    AppDependencies.instance.authBloc.add(const AuthPhoneSubmitted('9100000001'));
    await _waitFor(tester, find.text('Verify & Continue'), const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 1));
    // ignore: avoid_print
    print('OTP_SCREEN_READY');
    // No typing: the code must arrive from the SMS.
    await _waitFor(
      tester,
      find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('Good ')),
      const Duration(seconds: 90),
    );
    // ignore: avoid_print
    print('OTP_AUTOFILL_SIGNED_IN');
  });
}
