import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/router/back_guard.dart';
import 'package:medcollab_app/core/router/popup_route_tracker.dart';
import 'package:medcollab_app/core/router/shell_tab_history.dart';
import 'package:medcollab_app/core/router/app_routes.dart';

/// Logical parent of a screen that was opened without a page below it
/// (notification tap, deep link, `go`). Null for shell tabs.
///
/// Mirrors how the screens are reached in the UI, so back always moves ONE
/// level up: thread → its chat → Messages → Home.
String? logicalParentOf(String location) {
  final s = Uri.parse(location).pathSegments;
  if (s.isEmpty) return null;
  if (AppRoutes.shellPaths.contains(location)) return null;
  switch (s.first) {
    case 'dm':
      // /dm/:id/threads/:mid → /dm/:id ; /dm/:id and /dm/new → Messages
      if (s.length >= 4 && s[2] == 'threads') return AppRoutes.dmPath(s[1]);
      return AppRoutes.messages;
    case 'spaces':
      if (s.length == 1) return AppRoutes.messages;
      final space = s[1];
      if (s.length == 2) return AppRoutes.messages;
      switch (s[2]) {
        case 'channels':
          if (s.length >= 6 && s[4] == 'threads') {
            return AppRoutes.channelPath(space, s[3]);
          }
          return AppRoutes.messages;
        case 'handoffs':
          if (s.length == 3) return AppRoutes.spaceDetailPath(space);
          if (s.length >= 5 && s[4] == 'edit') {
            return AppRoutes.spaceHandoffDetailPath(space, s[3]);
          }
          if (s[3] == 'create') return AppRoutes.spaceHandoffsPath(space);
          // A handoff opened from a notification → the Handoffs tab.
          return AppRoutes.handoffs;
        default: // members, …
          return AppRoutes.spaceDetailPath(space);
      }
    case 'profile': // /profile/edit
    case 'bookmarks':
    case 'help':
    case 'report-bug':
    case 'feature-request':
    case 'feedback':
    case 'contact':
    case 'privacy':
    case 'terms':
    case 'developer':
      return AppRoutes.profile;
    case 'notifications': // /notifications/settings
      return AppRoutes.profile;
    case 'voice': // Needl Voice opened without its chat below it
      return AppRoutes.messages;
    case 'links':
    case 'join':
    case 'join-scan':
      return AppRoutes.messages;
    default:
      return AppRoutes.home;
  }
}

/// Central Android system-back handling for [GoRouter].
///
/// Signed-in rules, in order (beta 11-14: back is ONE level, never a jump):
/// 1. An open dialog / sheet / menu closes first (REQ 1).
/// 2. A screen with unsaved changes may ask to discard them ([BackGuard]).
/// 3. A pushed screen pops to the screen below it (chat → Messages,
///    Profile › Edit → Profile, thread → chat). The page's own PopScope is
///    respected.
/// 4. A screen with nothing below it (opened from a notification / link)
///    goes to its [logicalParentOf].
/// 5. Another main tab → Home.
/// 6. On Home: a second back within 2s exits the app.
///
/// Sign-in screens keep the platform default: pop if there is something to
/// pop, otherwise exit.
///
/// Prefer passing [router] explicitly: [MaterialApp.router]'s `builder` context
/// sits above [InheritedGoRouter], so [GoRouter.of] on that context is null.
class AppNavigationBackHandler extends StatefulWidget {
  const AppNavigationBackHandler({
    required this.child,
    this.router,
    this.popupTracker,
    super.key,
  });

  final Widget child;
  final GoRouter? router;

  /// When a dialog, sheet or menu is open, back closes it first instead of
  /// going Home underneath it.
  final PopupRouteTracker? popupTracker;

  @override
  State<AppNavigationBackHandler> createState() =>
      _AppNavigationBackHandlerState();
}

class _AppNavigationBackHandlerState extends State<AppNavigationBackHandler>
    with WidgetsBindingObserver {
  DateTime? _lastExitAttempt;
  bool _handling = false;

  static const _signInLocations = <String>{
    AppRoutes.splash,
    AppRoutes.phoneEntry,
    AppRoutes.otpVerification,
    AppRoutes.profileSetup,
  };

  GoRouter? get _router => widget.router ?? GoRouter.maybeOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _location(GoRouter router) => router.state.uri.path.isNotEmpty
      ? router.state.uri.path
      : router.state.matchedLocation;

  void _promptExit() {
    final now = DateTime.now();
    final last = _lastExitAttempt;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _lastExitAttempt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Swipe back again to exit Vocle'),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    SystemNavigator.pop();
  }

  /// Returns true when back was consumed here.
  Future<bool> _handleBack() async {
    if (_handling) return true; // ignore rapid repeats mid-transition
    _handling = true;
    try {
      final popups = widget.popupTracker;
      if (popups != null && popups.hasOpenPopup) {
        _lastExitAttempt = null;
        await popups.dismissTopmost();
        return true;
      }

      final router = _router;
      if (router == null) return false;
      final location = _location(router);

      if (_signInLocations.contains(location)) {
        // Let the navigator pop sign-in sub-steps (e.g. OTP → phone).
        if (location != AppRoutes.splash &&
            location != AppRoutes.phoneEntry &&
            router.canPop()) {
          return false;
        }
        _promptExit();
        return true;
      }

      if (!await BackGuard.allowLeave(context)) return true;
      if (!mounted) return true;

      if (location == AppRoutes.home) {
        _promptExit();
        return true;
      }

      // Leaving somewhere else disarms "back again to exit": the next back
      // on Home must prompt again, never close the app silently.
      _lastExitAttempt = null;

      // 3. One level up when there is a page below.
      if (router.canPop()) {
        final popped = await router.routerDelegate.popRoute();
        if (popped) return true;
      }

      // 4./5. Opened without a parent below it, or a non-Home tab.
      final parent = logicalParentOf(location) ?? AppRoutes.home;
      if (parent == AppRoutes.home) ShellTabHistory.resetToHome();
      router.go(parent);
      return true;
    } finally {
      _handling = false;
    }
  }

  /// System back (gesture or button) and `tester.binding.handlePopRoute`.
  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;
    return _handleBack();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBack());
      },
      child: widget.child,
    );
  }
}
