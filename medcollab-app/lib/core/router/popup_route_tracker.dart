import 'package:flutter/widgets.dart';

/// Tracks open popup routes (dialogs, bottom sheets, dropdown menus, popup
/// menus — all [PopupRoute]s) across the root navigator and every shell
/// branch navigator.
///
/// [AppNavigationBackHandler] intercepts system back on shell tab roots to
/// drive tab history. Popups are not GoRouter pages, so without this the
/// handler switched tabs underneath an open dialog and left it showing
/// (REQ-1: Create group dialog stayed open after back on Messages → Groups).
class PopupRouteTracker {
  final List<PopupRoute<dynamic>> _open = <PopupRoute<dynamic>>[];

  /// A new observer for one navigator. A [NavigatorObserver] can only be
  /// attached to a single navigator, so each navigator needs its own.
  NavigatorObserver createObserver() => _PopupRouteObserver(this);

  bool get hasOpenPopup => _open.isNotEmpty;

  /// Asks the navigator that owns the most recently opened popup to pop it.
  ///
  /// Uses [NavigatorState.maybePop] so a popup that guards its own dismissal
  /// (e.g. with [PopScope]) still gets to decide. Returns `true` if a popup
  /// was open, meaning the back press belongs to it and must not also
  /// navigate the page underneath.
  Future<bool> dismissTopmost() async {
    while (_open.isNotEmpty) {
      final route = _open.last;
      final navigator = route.navigator;
      if (navigator == null || !route.isActive) {
        _open.removeLast();
        continue;
      }
      await navigator.maybePop();
      return true;
    }
    return false;
  }

  void _add(Route<dynamic>? route) {
    if (route is PopupRoute<dynamic>) _open.add(route);
  }

  void _remove(Route<dynamic>? route) {
    if (route is PopupRoute<dynamic>) _open.remove(route);
  }
}

class _PopupRouteObserver extends NavigatorObserver {
  _PopupRouteObserver(this._tracker);

  final PopupRouteTracker _tracker;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _tracker._add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _tracker._remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _tracker._remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _tracker._remove(oldRoute);
    _tracker._add(newRoute);
  }
}
