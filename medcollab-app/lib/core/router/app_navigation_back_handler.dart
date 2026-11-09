import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/router/back_guard.dart';
import 'package:medcollab_app/core/router/popup_route_tracker.dart';
import 'package:medcollab_app/core/router/shell_tab_history.dart';
import 'package:medcollab_app/core/router/app_routes.dart';

/// Central Android system-back handling for [GoRouter] (REQ 3).
///
/// Signed-in rules, in order:
/// 1. An open dialog / sheet / menu closes first (REQ 1).
/// 2. A screen with unsaved changes may ask to discard them ([BackGuard]).
/// 3. On Home: a second back within 2s exits the app.
/// 4. Anywhere else — another tab, a chat, a thread, settings, a form —
///    back goes straight to Home.
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
      ShellTabHistory.resetToHome();
      router.go(AppRoutes.home);
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
