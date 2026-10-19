import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/lifecycle/app_lifecycle_handler.dart';
import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/core/network/api_response.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';

class _RefreshApi extends ApiClient {
  _RefreshApi(SecureStorageService storage) : super(storage: storage);
  bool fail = false;
  int refreshCalls = 0;
  final firstRefresh = Completer<void>();
  final secondRefresh = Completer<void>();

  @override
  Future<ApiResponse<T>> post<T>(String path, {
    Object? data, Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic> json)? parser, Options? options,
  }) async {
    expect(path, ApiEndpoints.refreshToken);
    expect(data, {'refreshToken': 'synthetic-refresh'});
    refreshCalls++;
    if (refreshCalls == 1) firstRefresh.complete();
    if (refreshCalls == 2) secondRefresh.complete();
    if (fail) throw const UnauthorizedException('Synthetic refresh denied');
    return ApiResponse<T>(success: true, message: 'Synthetic refreshed',
        data: parser!({'accessToken': 'synthetic-new'}));
  }
}

class _ResumeSocket extends SocketClient {
  bool connected = false;
  final connectTokens = <String>[];
  final updatedTokens = <String>[];
  int syncCalls = 0;
  final updated = Completer<void>();

  @override
  bool get isConnected => connected;
  @override
  Future<void> connect(String token) async {
    connectTokens.add(token);
    // Synthetic expired access token cannot establish a socket session.
    connected = false;
  }
  @override
  Future<void> updateAccessToken(String token) async {
    updatedTokens.add(token);
    connected = true;
    if (!updated.isCompleted) updated.complete();
  }
  @override
  void syncSpaceRooms() { syncCalls++; }
}

class _UiAuth extends AuthRepository {
  _UiAuth(SecureStorageService storage, SocketClient socket)
      : super(apiClient: ApiClient(storage: storage), storage: storage,
            socketClient: socket);
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<void> restoreSocketConnection() async {}
}

class _UiUser extends UserRepository {
  _UiUser(SecureStorageService storage) : super(apiClient: ApiClient(storage: storage));
  @override
  Future<UserModel> getMe() async => const UserModel(
    id: 'doctor-synthetic', name: 'Synthetic Doctor', isOnboarded: true,
  );
}

void main() {
  testWidgets('FR-RT-06: resume refresh reconnects or recovers session', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService(storage: const FlutterSecureStorage());
    await storage.saveSession(
      accessToken: 'synthetic-expired', refreshToken: 'synthetic-refresh',
      userId: 'doctor-synthetic',
    );
    final socket = _ResumeSocket();
    final api = _RefreshApi(storage);
    final reconnect = AuthRepository(apiClient: api, storage: storage, socketClient: socket);
    AppDependencies.instance.authRepository = reconnect;
    final auth = AuthBloc(
      authRepository: _UiAuth(storage, socket),
      userRepository: _UiUser(storage),
    );
    addTearDown(auth.close);
    final ready = auth.stream.firstWhere((state) => state.status == AuthStatus.authenticated);
    auth.add(const AuthStarted());
    await ready;
    await tester.pumpWidget(const MaterialApp(home: AppLifecycleHandler(
      child: Scaffold(body: Text('Synthetic session screen')),
    )));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() => socket.updated.future.timeout(const Duration(seconds: 5)));
    await tester.pump();
    expect(socket.connectTokens, ['synthetic-expired']);
    expect(api.refreshCalls, 1);
    expect(socket.updatedTokens, ['synthetic-new']);
    expect(socket.syncCalls, 1);
    expect(await storage.getAccessToken(), 'synthetic-new');

    // A second resume with another expired token and a denied refresh.
    socket.connected = false;
    api.fail = true;
    await storage.saveAccessToken('synthetic-expired-again');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() => api.secondRefresh.future.timeout(const Duration(seconds: 5)));
    await tester.pump();
    expect(socket.connectTokens, ['synthetic-expired', 'synthetic-expired-again']);
    expect(api.refreshCalls, 2);
    expect(socket.updatedTokens, ['synthetic-new']);
    expect(socket.syncCalls, 1);
    expect(auth.state.status, isNot(AuthStatus.authenticated),
        reason: 'Denied refresh on resume must expose session recovery instead of retaining Home');
  });
}
