import 'package:flutter/material.dart';

/// Vocle's page transition: the new page slides in a short way while fading
/// in (200 ms in, 160 ms back). Cheap to composite — no snapshots, no
/// scaling of the page below — so moving between screens feels immediate.
class VocleFastPageTransitionsBuilder extends PageTransitionsBuilder {
  const VocleFastPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 160);

  static final _slide = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
      .chain(CurveTween(curve: Curves.easeOutCubic));
  static final _fade = CurveTween(curve: Curves.easeOut);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: animation.drive(_slide),
      child: FadeTransition(opacity: animation.drive(_fade), child: child),
    );
  }
}
