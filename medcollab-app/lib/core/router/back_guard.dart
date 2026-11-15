import 'package:flutter/widgets.dart';

/// Lets a screen with unsaved changes veto system back (REQ 3 sends back
/// straight to Home, which would otherwise silently discard a form).
///
/// A screen registers a guard while it is dirty and unregisters it in
/// `dispose`. The guard typically shows a "Discard changes?" dialog and
/// returns true to allow leaving.
abstract final class BackGuard {
  static final List<Future<bool> Function()> _guards = [];

  static void register(Future<bool> Function() guard) {
    if (!_guards.contains(guard)) _guards.add(guard);
  }

  static void unregister(Future<bool> Function() guard) {
    _guards.remove(guard);
  }

  /// Asks the most recently registered guard first.
  static Future<bool> allowLeave(BuildContext context) async {
    for (final guard in List.of(_guards.reversed)) {
      if (!await guard()) return false;
    }
    return true;
  }

  @visibleForTesting
  static void clear() => _guards.clear();
}
