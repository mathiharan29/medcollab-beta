import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/storage/bookmark_service.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/bookmarks/presentation/pages/bookmarks_page.dart';
import 'package:medcollab_app/features/handoffs/presentation/pages/handoff_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MissingHandoffAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode({'success': false, 'message': 'Resource not found'}),
      404,
      headers: {'content-type': ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FR-SAVE-02: corrupt bookmarks recover and missing target is actionable',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'medcollab_bookmarks_v1': '{corrupt synthetic JSON',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = BookmarkService(prefs: prefs);
    expect(await service.getAll(), isEmpty);
    expect(await service.isBookmarked('missing-handoff'), isFalse);

    await service.save(BookmarkItem(
      id: 'missing-handoff',
      type: BookmarkType.handoff,
      title: 'Unavailable synthetic handoff',
      subtitle: 'Removed from server',
      savedAt: DateTime.utc(2026, 10, 10),
      spaceId: 'space-synthetic',
      handoffId: 'handoff-missing',
    ));
    expect((await BookmarkService(prefs: prefs).getAll()).single.handoffId,
        'handoff-missing');

    final deps = AppDependencies.instance;
    deps.init();
    final adapter = _MissingHandoffAdapter();
    deps.apiClient.dio.httpClientAdapter = adapter;
    final target = AppRoutes.spaceHandoffDetailPath(
        'space-synthetic', 'handoff-missing');
    final router = GoRouter(initialLocation: '/bookmarks', routes: [
      GoRoute(path: '/bookmarks', builder: (_, __) => const BookmarksPage()),
      GoRoute(
        path: '/spaces/:spaceId/handoffs/:handoffId',
        builder: (_, state) => HandoffDetailPage(
          spaceId: state.pathParameters['spaceId']!,
          handoffId: state.pathParameters['handoffId']!,
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: deps.authBloc,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable synthetic handoff'), findsOneWidget);
    await tester.tap(find.text('Unavailable synthetic handoff'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, target);
    expect(adapter.paths, contains('/api/handoffs/handoff-missing'));
    expect(find.text('Resource not found'), findsOneWidget);

    // The user must have a recovery action after following a stale bookmark.
    expect(find.text('Retry'), findsOneWidget);
  });
}
