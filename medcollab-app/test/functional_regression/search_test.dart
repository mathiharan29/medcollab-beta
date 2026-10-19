import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/search/data/repositories/search_repository.dart';
import 'package:medcollab_app/features/search/presentation/pages/global_search_page.dart';

import 'fakes/chat_fakes.dart';

class _Searches extends SearchRepository {
  _Searches() : super(apiClient: isolatedApiClient());
  final pending = <String, Completer<GlobalSearchResult>>{};
  final requested = <String>[];

  @override
  Future<GlobalSearchResult> search({
    required String query, String type = 'all', int limit = 20,
  }) {
    requested.add(query);
    return (pending[query] = Completer<GlobalSearchResult>()).future;
  }
}

GlobalSearchResult _channelResult(String query, String channelId, String name) =>
    GlobalSearchResult(query: query, channels: [
      SearchChannelHit(id: channelId, name: name, spaceId: 'space-synthetic',
          spaceName: 'Synthetic ward'),
    ]);

void main() {
  testWidgets('FR-SRCH-04: newest query owns results and failures recover', (tester) async {
    final searches = _Searches();
    AppDependencies.instance.searchRepository = searches;
    final socket = FakeSocketClient();
    final auth = AuthBloc(
      authRepository: AuthRepository(
        apiClient: isolatedApiClient(), storage: SecureStorageService(),
        socketClient: socket,
      ),
      userRepository: UserRepository(apiClient: isolatedApiClient()),
    );
    addTearDown(() async {
      await auth.close();
      await socket.disposeFake();
    });
    final router = GoRouter(initialLocation: '/search', routes: [
      GoRoute(path: '/search', builder: (_, __) => const GlobalSearchPage()),
      GoRoute(
        path: '/spaces/:spaceId/channels/:channelId',
        builder: (_, state) => Scaffold(body: Text(
          'Opened ${state.pathParameters['spaceId']}/${state.pathParameters['channelId']}',
        )),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.enterText(field, 'alpha');
    await tester.pump(const Duration(milliseconds: 560));
    expect(searches.requested, ['alpha']);
    await tester.enterText(field, 'beta');
    await tester.pump(const Duration(milliseconds: 560));
    expect(searches.requested, ['alpha', 'beta']);
    searches.pending['beta']!.complete(_channelResult('beta', 'channel-b', 'Beta'));
    await tester.pump();
    expect(find.text('#Beta'), findsOneWidget);
    searches.pending['alpha']!.complete(_channelResult('alpha', 'channel-a', 'Alpha'));
    await tester.pump();
    expect(find.text('#Beta'), findsOneWidget);
    expect(find.text('#Alpha'), findsNothing,
        reason: 'An older response must not overwrite the newest query');

    await tester.enterText(field, 'empty');
    await tester.pump(const Duration(milliseconds: 560));
    searches.pending['empty']!.complete(const GlobalSearchResult(query: 'empty'));
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);

    await tester.enterText(field, 'gamma');
    await tester.pump(const Duration(milliseconds: 560));
    searches.pending['gamma']!.completeError(const ServerException('Synthetic search failure'));
    await tester.pump();
    final errorVisible = find.textContaining('Could not search').evaluate().isNotEmpty;
    await tester.enterText(field, 'delta');
    await tester.pump(const Duration(milliseconds: 560));
    searches.pending['delta']!.complete(_channelResult('delta', 'channel-d', 'Delta'));
    await tester.pump();
    expect(find.text('#Delta'), findsOneWidget);
    expect(find.text('#Beta'), findsNothing);
    await tester.tap(find.text('#Delta'));
    await tester.pumpAndSettle();
    expect(find.text('Opened space-synthetic/channel-d'), findsOneWidget);
    expect(errorVisible, isTrue,
        reason: 'A failed search needs a visible recoverable error state');
  });
}
