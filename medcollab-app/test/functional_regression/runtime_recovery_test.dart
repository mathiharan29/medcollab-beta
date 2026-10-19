import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/handoffs/presentation/cubit/handoffs_cubit.dart';
import 'package:medcollab_app/features/handoffs/presentation/pages/handoff_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/chat_fakes.dart';

const _handoff = {
  '_id': 'handoff-recovered',
  'spaceId': 'space-synthetic',
  'channelId': 'channel-synthetic',
  'fromUserId': {'_id': 'doctor-a', 'name': 'Doctor A'},
  'toUserId': {'_id': 'doctor-b', 'name': 'Doctor B'},
  'shiftDate': '2026-10-10T12:00:00Z',
  'shiftType': 'morning',
  'shiftSummary': 'Recovered synthetic shift',
  'status': 'submitted',
};

class _RecoveryAdapter implements HttpClientAdapter {
  String listMode = 'timeout';
  String detailMode = 'timeout';
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options.path);
    final isDetail = options.path == '/api/handoffs/handoff-recovered';
    final isSpaceList = options.path.startsWith('/api/spaces/') &&
        options.path.endsWith('/handoffs');
    final mode = isDetail ? detailMode : isSpaceList ? listMode : 'ok';
    if (mode == 'timeout') {
      throw DioException(requestOptions: options,
          type: DioExceptionType.receiveTimeout);
    }
    final status = mode == 'server' ? 500 : 200;
    final body = mode == 'server'
        ? {'success': false, 'message': 'Synthetic server failure'}
        : mode == 'malformed'
            ? {'success': true, 'data': ['unexpected']}
            : {'success': true, 'data': isDetail
                ? {'handoff': _handoff}
                : {'handoffs': isSpaceList ? [_handoff] : [], 'hasMore': false}};
    return ResponseBody.fromString(jsonEncode(body), status,
        headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FR-RUN-03: list and detail recover after timeout, 5xx and malformed data',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final adapter = _RecoveryAdapter();
    final client = isolatedApiClient()..dio.httpClientAdapter = adapter;
    final repository = HandoffRepository(apiClient: client);
    final socket = FakeSocketClient();
    addTearDown(socket.disposeFake);
    await tester.runAsync(() async {
      final cubit = HandoffsCubit(handoffRepository: repository,
          socketClient: socket, spaceId: 'space-synthetic',
          currentUserId: 'doctor-b');
      addTearDown(cubit.close);
      final firstError = await cubit.stream.firstWhere(
          (state) => !state.isLoading && state.error != null);
      expect(firstError.handoffs, isEmpty);
      expect(firstError.error, 'Connection timed out');

      for (final mode in ['server', 'malformed']) {
        adapter.listMode = mode;
        await cubit.loadHandoffs();
        expect(cubit.state.isLoading, isFalse, reason: mode);
        expect(cubit.state.error, isNotNull, reason: mode);
        expect(cubit.state.handoffs, isEmpty, reason: mode);
      }
      adapter.listMode = 'ok';
      await cubit.loadHandoffs();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.handoffs.single.id, 'handoff-recovered');
      expect(cubit.state.handoffs.single.shiftSummary,
          'Recovered synthetic shift');

      // The same real repository parses detail failures and later correct data.
      for (final mode in ['timeout', 'server', 'malformed']) {
        adapter.detailMode = mode;
        await expectLater(repository.getHandoffById('handoff-recovered'),
            throwsA(isA<AppException>()));
      }
      adapter.detailMode = 'ok';
      final recovered = await repository.getHandoffById('handoff-recovered');
      expect(recovered.id, cubit.state.handoffs.single.id);
      expect(recovered.toUser.id, 'doctor-b');
    });

    // The actual detail page must expose recovery from a transient error.
    final deps = AppDependencies.instance;
    deps.init();
    deps.apiClient.dio.httpClientAdapter = adapter;
    adapter.detailMode = 'timeout';
    final router = GoRouter(initialLocation: '/spaces/space-synthetic/handoffs/handoff-recovered',
        routes: [GoRoute(path: '/spaces/:spaceId/handoffs/:handoffId',
          builder: (_, state) => HandoffDetailPage(
              spaceId: state.pathParameters['spaceId']!,
              handoffId: state.pathParameters['handoffId']!))]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(value: deps.authBloc,
        child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('Connection timed out'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}
