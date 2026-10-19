import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/notifications/fcm_service.dart';
import 'package:medcollab_app/core/notifications/push_notification_router.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';
import 'package:medcollab_app/features/shell/presentation/cubit/nav_badges_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PushApiAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.path);
    final isMissing = options.path.contains('handoff-missing');
    final body = options.path.endsWith('/users/me')
        ? {'success': true, 'data': {'user': {
            '_id': 'doctor-synthetic', 'name': 'Synthetic Doctor',
            'isOnboarded': true,
          }}}
        : isMissing
            ? {'success': false, 'message': 'Resource not found'}
            : {'success': true, 'data': {'messages': [], 'hasMore': false}};
    return ResponseBody.fromString(jsonEncode(body), isMissing ? 404 : 200,
        headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FR-LINK-03: push routes debounce, queue through auth and recover missing target',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final deps = AppDependencies.instance;
    deps.init();
    final adapter = _PushApiAdapter();
    deps.apiClient.dio.httpClientAdapter = adapter;
    final router = deps.appRouter.router;
    addTearDown(router.dispose);

    const channel = PushPayload(type: 'message', spaceId: 'space-synthetic',
        channelId: 'channel-synthetic');
    const dm = PushPayload(type: 'message', channelId: 'dm-synthetic');
    const handoff = PushPayload(type: 'handoff', spaceId: 'space-synthetic',
        handoffId: 'handoff-synthetic');
    const missing = PushPayload(type: 'handoff', spaceId: 'space-synthetic',
        handoffId: 'handoff-missing');

    expect(deps.authBloc.state.status, AuthStatus.unknown);
    PushNotificationRouter.open(channel);
    PushNotificationRouter.open(dm);
    PushNotificationRouter.open(handoff);
    await tester.pump();
    // No push target should open before a synthetic session is restored.
    expect(router.routeInformationProvider.value.uri.path,
        isNot(AppRoutes.spaceHandoffDetailPath('space-synthetic', 'handoff-synthetic')));
    await deps.secureStorage.saveSession(accessToken: 'synthetic-access',
        refreshToken: 'synthetic-refresh', userId: 'doctor-synthetic');
    await tester.pumpWidget(MultiBlocProvider(providers: [
      BlocProvider<AuthBloc>.value(value: deps.authBloc),
      BlocProvider<NavBadgesCubit>.value(value: deps.navBadgesCubit),
      BlocProvider<NotificationBadgeCubit>.value(
          value: deps.notificationBadgeCubit),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pump();

    for (var i = 0; i < 20 &&
        deps.authBloc.state.status != AuthStatus.authenticated; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(deps.authBloc.state.status, AuthStatus.authenticated);
    expect(deps.authBloc.state.user?.id, 'doctor-synthetic');
    expect(adapter.paths, contains('/api/users/me'));
    expect(router.routeInformationProvider.value.uri.path,
        AppRoutes.spaceHandoffDetailPath('space-synthetic', 'handoff-synthetic'));

    PushNotificationRouter.open(channel);
    PushNotificationRouter.open(dm);
    PushNotificationRouter.open(handoff);
    await tester.pump(const Duration(milliseconds: 230));
    expect(router.routeInformationProvider.value.uri.path,
        AppRoutes.spaceHandoffDetailPath('space-synthetic', 'handoff-synthetic'));

    await tester.pumpAndSettle();

    // A stale target must fall back to a stable list, rather than strand the user.
    PushNotificationRouter.open(missing);
    await tester.pump(const Duration(milliseconds: 230));
    await tester.pumpAndSettle();
    expect(router.state.uri.path,
        AppRoutes.spaceHandoffDetailPath('space-synthetic', 'handoff-missing'));
    expect(adapter.paths, contains('/api/handoffs/handoff-missing'));
    expect(find.text('Resource not found'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path,
        AppRoutes.handoffs);
  });
}
