import 'dart:async';

/// App-wide "the Messages hub may be stale" signal.
///
/// The Messages tab stays alive inside the bottom-tab shell, so it never
/// rebuilds its DM / group lists on its own. Producers ping this when
/// something the hub shows may have changed (tab re-shown, a chat closed);
/// the hub debounces pings into a single reload. Socket events are
/// subscribed by the hub directly.
abstract final class HubRefreshSignal {
  static final StreamController<String> _controller =
      StreamController<String>.broadcast();

  static Stream<String> get stream => _controller.stream;

  /// [reason] is for debugging/tests only.
  static void ping(String reason) {
    if (!_controller.isClosed) _controller.add(reason);
  }
}
