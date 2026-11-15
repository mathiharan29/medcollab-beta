/// Shares identical list fetches between screens (REQ 13).
///
/// Swipeable tabs keep Home, Messages and Handoffs alive together, so one
/// sign-in used to fire `GET /handoffs` four times and `GET /spaces` three
/// times within ~1.5s. Callers asking for the same [key] now share one
/// in-flight request and reuse its result for [ttl].
///
/// Freshness: [invalidateAll] runs on every local write made through a
/// repository and on every realtime event from the server, so a change is
/// never hidden behind the cache.
class SharedFetch {
  SharedFetch._();

  static const ttl = Duration(milliseconds: 1500);

  static final _inFlight = <String, Future<Object?>>{};
  static final _done = <String, ({DateTime at, Object? value})>{};
  static int _generation = 0;

  static Future<T> run<T>(String key, Future<T> Function() fetch) {
    final hit = _done[key];
    if (hit != null && DateTime.now().difference(hit.at) < ttl) {
      return Future.value(hit.value as T);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending.then((v) => v as T);

    final generation = _generation;
    final future = fetch();
    _inFlight[key] = future;
    future.then((value) {
      if (generation == _generation) {
        _done[key] = (at: DateTime.now(), value: value);
      }
    }, onError: (Object _) {}).whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    });
    return future;
  }

  /// Drops cached results. An in-flight request is not reused after this
  /// either, so the next caller always reaches the server.
  static void invalidateAll() {
    _generation++;
    _done.clear();
    _inFlight.clear();
  }
}
