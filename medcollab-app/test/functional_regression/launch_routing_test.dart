import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_router.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';
import 'package:medcollab_app/features/shell/presentation/cubit/nav_badges_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/chat_fakes.dart';

class _LaunchSession extends AuthRepository {
  _LaunchSession({required this.present, required FakeSocketClient socket})
      : super(apiClient: isolatedApiClient(),
          storage: SecureStorageService(), socketClient: socket);
  final bool present;
  int checks = 0;
  int socketRestores = 0;

  @override
  Future<bool> hasSession() async {
    checks++;
    return present;
  }

  @override
  Future<void> restoreSocketConnection() async { socketRestores++; }
}

class _LaunchProfiles extends UserRepository {
  _LaunchProfiles(this.user) : super(apiClient: isolatedApiClient());
  final UserModel user;
  int reads = 0;

  @override
  Future<UserModel> getMe() async { reads++; return user; }
}

class _LoopbackAdapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.path);
    return ResponseBody.fromString(jsonEncode({
      'success': true,
      'data': {
        'spaces': [], 'handoffs': [], 'notifications': [],
        'channels': [], 'requests': [], 'count': 0, 'unreadCount': 0,
      },
    }), 200, headers: {'content-type': ['application/json']});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FR-NAV-01: launch routes from stored session and profile',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final deps = AppDependencies.instance;
    deps.init();
    final adapter = _LoopbackAdapter();
    deps.apiClient.dio.httpClientAdapter = adapter;
    final observed = <String, List<String>>{};
    final frameworkErrors = <String>[];
    void captureFrameworkError() {
      final error = tester.takeException();
      if (error != null) frameworkErrors.add(error.toString());
    }

    Future<void> scenario(String label, bool hasSession, UserModel user,
        AuthStatus expectedStatus, String expectedPath) async {
      final socket = FakeSocketClient();
      final session = _LaunchSession(present: hasSession, socket: socket);
      final profiles = _LaunchProfiles(user);
      final auth = AuthBloc(authRepository: session, userRepository: profiles);
      addTearDown(() async {
        await auth.close();
        await socket.disposeFake();
      });
      final appRouter = AppRouter(authBloc: auth);
      final router = appRouter.router;
      final locations = <String>[];
      void recordLocation() {
        locations.add(router.routeInformationProvider.value.uri.path);
      }
      router.routeInformationProvider.addListener(recordLocation);
      await tester.pumpWidget(MultiBlocProvider(providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<NavBadgesCubit>.value(value: deps.navBadgesCubit),
        BlocProvider<NotificationBadgeCubit>.value(
            value: deps.notificationBadgeCubit),
      ], child: MaterialApp.router(routerConfig: router)));
      captureFrameworkError();
      await tester.pump();
      captureFrameworkError();
      await tester.pump(const Duration(milliseconds: 20));
      captureFrameworkError();
      await tester.pump(const Duration(milliseconds: 20));
      captureFrameworkError();
      expect(auth.state.status, expectedStatus, reason: label);
      expect(router.routeInformationProvider.value.uri.path,
          expectedPath, reason: label);
      expect(session.checks, 1, reason: '$label checks one stored session');
      expect(profiles.reads, hasSession ? 1 : 0,
          reason: '$label must load stored identity only for a session');
      if (hasSession) {
        expect(auth.state.user?.id, user.id);
        expect(session.socketRestores, 1);
      } else {
        expect(auth.state.user, isNull);
      }
      observed[label] = locations;
      await tester.pumpWidget(const SizedBox.shrink());
      captureFrameworkError();
      router.routeInformationProvider.removeListener(recordLocation);
      appRouter.dispose();
      router.dispose();
    }

    await scenario('no session', false,
        const UserModel(id: 'unused'), AuthStatus.unauthenticated,
        AppRoutes.phoneEntry);
    await scenario('incomplete profile', true,
        const UserModel(id: 'doctor-incomplete', name: 'A'),
        AuthStatus.needsProfile, AppRoutes.profileSetup);
    await scenario('onboarded profile', true,
        const UserModel(id: 'doctor-onboarded', name: 'Doctor Onboarded',
            isOnboarded: true),
        AuthStatus.authenticated, AppRoutes.home);
    expect(observed['no session'], isNot(contains(AppRoutes.home)));
    expect(observed['incomplete profile'], isNot(contains(AppRoutes.home)));
    expect(observed['onboarded profile'], isNot(contains(AppRoutes.profileSetup)));
    expect(adapter.paths.every((path) => path.startsWith('/api/')), isTrue);
    expect(frameworkErrors, isEmpty,
        reason: 'Each launch destination must render without framework errors');
  });
}
