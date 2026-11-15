// Screen tour: opens EVERY screen of the app on a real device/emulator in
// light, dark and large-text (1.3x) variants, against the LOCAL dev backend.
//
// For each screen it records:
//   * first-content time (route change → no loading spinner on screen),
//   * any Flutter error (RenderFlex overflow, build/layout exceptions),
//   * a screenshot (build/tour/<variant>_<screen>.png) for visual review.
//
// Run:
//   flutter drive --profile --driver=test_driver/screen_tour_driver.dart \
//     --target=integration_test/vocle_screen_tour_test.dart -d emulator-5554 \
//     --dart-define=TOUR_SPACE=<id> --dart-define=TOUR_CHANNEL=<id> \
//     --dart-define=TOUR_DM=<id> --dart-define=TOUR_HANDOFF=<id>
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medcollab_app/app.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';

const _space = String.fromEnvironment('TOUR_SPACE');
const _channel = String.fromEnvironment('TOUR_CHANNEL');
const _dm = String.fromEnvironment('TOUR_DM');
const _handoff = String.fromEnvironment('TOUR_HANDOFF');

/// Every signed-in screen reachable by URL (QR scanner needs a camera).
final _screens = <String, String>{
  'home': AppRoutes.home,
  'messages': AppRoutes.messages,
  'handoffs': AppRoutes.handoffs,
  'alerts': AppRoutes.notifications,
  'profile': AppRoutes.profile,
  'edit_profile': AppRoutes.editProfile,
  'groups': AppRoutes.spacesList,
  'group_detail': AppRoutes.spaceDetailPath(_space),
  'channel_chat': AppRoutes.channelPath(_space, _channel),
  'group_members': AppRoutes.spaceMembersPath(_space),
  'group_handoffs': AppRoutes.spaceHandoffsPath(_space),
  'handoff_create': AppRoutes.spaceHandoffCreatePath(_space),
  'handoff_detail': AppRoutes.spaceHandoffDetailPath(_space, _handoff),
  'handoff_edit': AppRoutes.spaceHandoffEditPath(_space, _handoff),
  'dm_chat': AppRoutes.dmPath(_dm),
  'start_dm': AppRoutes.startDm,
  'search': AppRoutes.search,
  'bookmarks': AppRoutes.bookmarks,
  'notification_settings': AppRoutes.notificationSettings,
  'join_invite_bad_code': AppRoutes.joinInvitePath('ZZZ999'),
  'help': AppRoutes.help,
  'report_bug': AppRoutes.reportBug,
  'feature_request': AppRoutes.featureRequest,
  'feedback': AppRoutes.feedback,
  'contact': AppRoutes.contact,
  'privacy': AppRoutes.privacy,
  'terms': AppRoutes.terms,
  'developer': AppRoutes.developerMode,
};

final _report = <String, Object?>{};
final _errors = <String, List<String>>{};

/// Anything that means "still loading" on screen: spinners, progress bars
/// and skeleton placeholders. Timings run until all of them are gone.
Finder get _spinner => find.byWidgetPredicate((w) =>
        w is CircularProgressIndicator ||
        w is LinearProgressIndicator ||
        w is AppSkeletonBox ||
        w is AppListSkeleton ||
        w is AppCardSkeleton ||
        w is AppMessageSkeleton).hitTestable();

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Vocle screen tour', (tester) async {
    // Collect Flutter errors per screen instead of failing on the first one.
    var current = 'startup';
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString().split('\n').first;
      final where = details.context?.toDescription() ?? '';
      (_errors[current] ??= []).add('$text ${where.isEmpty ? '' : '($where)'}');
    };
    addTearDown(() => FlutterError.onError = original);

    AppDependencies.instance.init();
    await tester.pumpWidget(const MedCollabApp());

    Future<void> settle({Duration max = const Duration(seconds: 6)}) async {
      final w = Stopwatch()..start();
      // At least a few frames, then until spinners are gone (or max).
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      while (w.elapsed < max && _spinner.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // Screenshots are taken from the host (adb screencap) on this marker:
    // in-app surface capture crashed the emulator's GLES raster thread.
    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 250)); // finish fades
      // ignore: avoid_print
      print('TOURSHOT $name');
      final w = Stopwatch()..start();
      while (w.elapsedMilliseconds < 1500) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // ── Signed-out screens ────────────────────────────────────────────
    current = 'phone_entry';
    final waitPhone = Stopwatch()..start();
    while (find.text('Continue').evaluate().isEmpty &&
        waitPhone.elapsed < const Duration(seconds: 20)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Cold start → sign-in button usable (not showing the loading spinner).
    final auth = AppDependencies.instance.authBloc;
    final launch = Stopwatch()..start();
    while (auth.state.isLoading && launch.elapsed.inSeconds < 30) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    _report['phone_entry_ready_ms'] = waitPhone.elapsedMilliseconds;
    _report['phone_entry_loading_ms_after_visible'] =
        launch.elapsedMilliseconds;
    await settle();
    await shot('light_phone_entry');
    current = 'otp';
    AppDependencies.instance.authBloc.add(const AuthPhoneSubmitted('9100000001'));
    while (find.text('Verify & Continue').evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle();
    await shot('light_otp');
    current = 'sign_in';
    AppDependencies.instance.authBloc.add(const AuthOtpSubmitted('123456'));
    final home = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^Good ').hasMatch(w.data ?? ''));
    while (home.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle();

    final router = AppDependencies.instance.appRouter.router;
    final themeCubit = tester
        .element(find.byType(MaterialApp).first)
        .read<ThemeModeCubit>();

    Future<void> tour(String variant) async {
      final timings = <String, int>{};
      for (final entry in _screens.entries) {
        current = '${variant}_${entry.key}';
        final w = Stopwatch()..start();
        router.go(entry.value);
        await settle();
        timings[entry.key] = w.elapsedMilliseconds;
        await shot(current);
        // Dismiss anything a screen opened on arrival (keyboard, sheet).
        FocusManager.instance.primaryFocus?.unfocus();
      }
      router.go(AppRoutes.home);
      await settle();
      _report['timings_$variant'] = timings;
    }

    await tour('light');

    await themeCubit.setMode(ThemeMode.dark);
    await settle();
    await tour('dark');

    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await settle();
    await tour('dark_text130');
    await themeCubit.setMode(ThemeMode.light);
    await settle();
    await tour('light_text130');

    await themeCubit.setMode(ThemeMode.system);
    _report['errors'] = _errors;
    // Merge: on Android the binding keeps screenshots in reportData.
    binding.reportData = {...?binding.reportData, ..._report};
  });
}
