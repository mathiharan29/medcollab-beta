// REQ 13: identical list fetches are shared, but never served stale after a
// write or realtime event.
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/network/shared_fetch.dart';

void main() {
  setUp(SharedFetch.invalidateAll);

  test('concurrent callers share one request', () async {
    var calls = 0;
    Future<int> fetch() async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return calls;
    }

    final results = await Future.wait([
      SharedFetch.run('k', fetch),
      SharedFetch.run('k', fetch),
      SharedFetch.run('k', fetch),
    ]);
    expect(calls, 1);
    expect(results, [1, 1, 1]);
  });

  test('a call right after completion reuses the result', () async {
    var calls = 0;
    await SharedFetch.run('k', () async => ++calls);
    await SharedFetch.run('k', () async => ++calls);
    expect(calls, 1);
  });

  test('invalidateAll forces a fresh request, even mid-flight', () async {
    var calls = 0;
    Future<int> slow() async {
      final n = ++calls; // which request this is
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return n;
    }

    final first = SharedFetch.run('k', slow);
    SharedFetch.invalidateAll(); // e.g. a POST or socket event lands
    final second = SharedFetch.run('k', slow);
    expect(await first, 1);
    expect(await second, 2);
    // The pre-invalidation result was not cached either.
    expect(await SharedFetch.run('k', slow), 2);
    expect(calls, 2);
  });

  test('failures are not cached', () async {
    var calls = 0;
    await expectLater(
      SharedFetch.run<int>('k', () async {
        calls++;
        throw StateError('offline');
      }),
      throwsStateError,
    );
    expect(await SharedFetch.run('k', () async => ++calls), 2);
  });

  test('different keys do not share', () async {
    var calls = 0;
    await SharedFetch.run('a', () async => ++calls);
    await SharedFetch.run('b', () async => ++calls);
    expect(calls, 2);
  });
}
