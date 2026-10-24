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
///
/// Prefer passing [router] explicitly: [MaterialApp.router]'s `builder` context
/// sits above [InheritedGoRouter], so [GoRouter.of] on that context is null.
class AppNavigationBackHandler extends StatefulWidget {
  const AppNavigationBackHandler({
    required this.child,
    this.router,
    super.key,
  });

  final Widget child;
  final GoRouter? router;

  @override
  State<AppNavigationBackHandler> createState() =>
      _AppNavigationBackHandlerState();
}

class _AppNavigationBackHandlerState extends State<AppNavigationBackHandler>
    with WidgetsBindingObserver {
  DateTime? _lastExitAttempt;

  static const _shellTabRoots = <String>{
    AppRoutes.home,
    AppRoutes.messages,
    AppRoutes.handoffs,
    AppRoutes.notifications,
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

  bool _allowImmediateExit(String location) =>
      location == AppRoutes.splash ||
      location == AppRoutes.phoneEntry ||
      location == AppRoutes.otpVerification;

  bool _isShellTabRoot(String location) => _shellTabRoots.contains(location);

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
    final router = _router;
    if (router == null) return;

    final location = router.state.uri.path.isNotEmpty
        ? router.state.uri.path
        : router.state.matchedLocation;

    // Shell tab roots: prefer tab history over Navigator.pop. StatefulShell
    // can report canPop=true from branch stacks even when the visible route is
    // already the tab root (FR-NAV-03).
    if (_isShellTabRoot(location)) {
      if (ShellTabHistory.goBack()) return;
      if (location == AppRoutes.home || _allowImmediateExit(location)) {
        _promptExit();
        return;
      }
      router.go(AppRoutes.home);
      return;
    }

    if (router.canPop()) {
      router.pop();
      return;
    }

    if (ShellTabHistory.goBack()) return;

    if (location == AppRoutes.home || _allowImmediateExit(location)) {
      _promptExit();
      return;
    }

    router.go(AppRoutes.home);
  }

  /// [tester.binding.handlePopRoute] / system back.
  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;
    final router = _router;
    if (router == null) return false;
    final location = router.state.uri.path.isNotEmpty
        ? router.state.uri.path
        : router.state.matchedLocation;
    if (!_isShellTabRoot(location) && router.canPop()) {
      return false; // let Navigator pop nested detail routes
    }
    _handleBack();
    return true;
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
