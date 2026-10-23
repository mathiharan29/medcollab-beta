import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/router/shell_tab_history.dart';
import 'package:medcollab_app/core/router/app_routes.dart';

/// Central Android/iOS back handling for [GoRouter].
///
/// - Pops the route stack when possible (e.g. My Groups → Profile).
/// - On shell tabs, requires a second back within 2s to exit the app.
/// - Orphan authenticated routes fall back to Home instead of killing the app.
class AppNavigationBackHandler extends StatefulWidget {
  const AppNavigationBackHandler({required this.child, super.key});

  final Widget child;

  @override
  State<AppNavigationBackHandler> createState() =>
      _AppNavigationBackHandlerState();
}

class _AppNavigationBackHandlerState extends State<AppNavigationBackHandler> {
  DateTime? _lastExitAttempt;

  bool _allowImmediateExit(String location) =>
      location == AppRoutes.splash ||
      location == AppRoutes.phoneEntry ||
      location == AppRoutes.otpVerification;

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

  void _handleBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    // Bottom tabs: Home → Handoffs → back should return to Home (not exit).
    if (ShellTabHistory.goBack()) return;

    final location = router.state.uri.path.isNotEmpty
        ? router.state.uri.path
        : router.state.matchedLocation;

    // Home (index 0) with an empty tab stack: double-back to exit.
    if (location == AppRoutes.home || _allowImmediateExit(location)) {
      _promptExit();
      return;
    }

    // Any other shell tab (or orphan route) goes Home first — never exit on
    // the first back, even when ShellTabHistory has no usable shell/stack.
    router.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: widget.child,
    );
  }
}
