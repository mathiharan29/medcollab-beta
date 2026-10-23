import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Remembers bottom-tab visits so system back returns to the previous tab
/// (Slack-style) instead of exiting the app immediately.
abstract final class ShellTabHistory {
  static StatefulNavigationShell? shell;
  static final List<int> _stack = <int>[0];

  static void bind(StatefulNavigationShell navigationShell) {
    shell = navigationShell;
    final index = navigationShell.currentIndex;
    if (_stack.isEmpty || _stack.last != index) {
      _stack
        ..clear()
        ..add(index);
    }
  }

  static void visit(int index) {
    if (_stack.isNotEmpty && _stack.last == index) return;
    _stack.add(index);
    if (_stack.length > 24) {
      _stack.removeRange(0, _stack.length - 24);
    }
  }

  /// Returns true when back was handled by switching tabs.
  static bool goBack() {
    final nav = shell;
    if (nav == null) return false;
    if (_stack.length < 2) {
      // No tab history (e.g. stack reset on rebuild) but not on Home:
      // go Home first instead of letting the caller treat it as an exit.
      if (nav.currentIndex != 0) {
        try {
          _stack
            ..clear()
            ..add(0);
          nav.goBranch(0);
          return true;
        } catch (e, st) {
          debugPrint('ShellTabHistory.goBack (home) failed: $e\n$st');
        }
      }
      return false;
    }
    _stack.removeLast();
    final previous = _stack.last;
    try {
      nav.goBranch(previous);
      return true;
    } catch (e, st) {
      debugPrint('ShellTabHistory.goBack failed: $e\n$st');
      return false;
    }
  }
}
