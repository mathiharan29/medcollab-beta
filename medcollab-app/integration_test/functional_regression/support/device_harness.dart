import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medcollab_app/app.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/messages/presentation/pages/channel_chat_page.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/mention_composer.dart';

import 'provider_inputs.dart';

const devicePhase = String.fromEnvironment('DEVICE_PHASE');
const deviceRun = String.fromEnvironment('DEVICE_RUN_ID');
const controlOrigin = String.fromEnvironment('DEVICE_CONTROL_URL');
final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
final deviceMessaging = DeviceMessaging();
final deps = AppDependencies.instance;
final deviceStorage = SecureStorageService();
final observations = <String>[];
Map<String, dynamic>? _fixture;

// Dart top-level fields are lazy. Force the integration binding to exist in
// main, before testWidgets can create an automated unit-test binding.
void deviceMain() {
  binding.reportData = {'tier': 'D', 'phase': devicePhase, 'runId': deviceRun};
}

class DeviceInfrastructureError implements Exception {
  DeviceInfrastructureError(this.message);
  final String message;
  @override
  String toString() => message;
}

class DeviceDecision implements Exception {
  DeviceDecision(this.message);
  final String message;
  @override
  String toString() => message;
}

void safeDeviceOrigin(String value) {
  final uri = Uri.parse(value);
  if (uri.scheme != 'http' ||
      uri.host != '10.0.2.2' ||
      !uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      uri.path.isNotEmpty && uri.path != '/') {
    throw DeviceInfrastructureError(
        'Device origin must be an explicit local emulator port');
  }
}

Future<Map<String, dynamic>> control(String action,
    [Map<String, dynamic> data = const {}]) async {
  safeDeviceOrigin(controlOrigin);
  final client = Dio(BaseOptions(
      baseUrl: controlOrigin,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'x-vocle-run': deviceRun}));
  try {
    final result =
        await client.post<Map<String, dynamic>>('/control/$action', data: data);
    final payload = result.data!;
    if (payload['status'] == 'ERROR')
      throw DeviceInfrastructureError(payload['error'].toString());
    if (payload['status'] == 'FAIL')
      throw TestFailure(payload['error'].toString());
    return payload;
  } on DioException catch (e) {
    throw DeviceInfrastructureError(
        'Local device control $action failed (${e.type})');
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> fixture() async =>
    _fixture ??= await control('fixture');

Future<void> initializeDevice({RemoteMessage? initialMessage}) async {
  if (!Platform.isAndroid || const bool.fromEnvironment('dart.vm.product')) {
    throw DeviceInfrastructureError(
        'Only a debug Android emulator build is supported');
  }
  safeDeviceOrigin(EnvConfig.apiBaseUrl);
  safeDeviceOrigin(EnvConfig.socketUrl);
  FirebasePlatform.instance = DeviceFirebase();
  FirebaseMessagingPlatform.instance = deviceMessaging;
  deviceMessaging.initialMessage = initialMessage;
}

Future<void> installSession(String label) async {
  final person = (await fixture())[label] as Map<String, dynamic>;
  await deviceStorage.saveSession(
      accessToken: person['token'] as String,
      refreshToken: person['refreshToken'] as String,
      userId: person['userId'] as String);
}

Future<void> nativeStorageProbe() async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  const key = 'vocle_regression_native_probe';
  await storage.write(key: key, value: 'synthetic-native-value');
  expect(await storage.read(key: key), 'synthetic-native-value',
    reason: 'Native encrypted storage must round-trip before session assertions');
  await storage.delete(key: key);
  expect(await storage.read(key: key), isNull);
}

Future<void> launch(WidgetTester tester,
    {String? session, bool firebase = false, bool currentChat = false, String? entryRoute}) async {
  if (session != null) await installSession(session);
  // Stored-session fixtures must exist before dependencies start their initial
  // badge requests, exactly as they do before a real cold launch. Seeding after
  // init allows an earlier unauthenticated 401 to clear the fixture session.
  deps.init();
  if (currentChat) {
    final f = await fixture();
    entryRoute = AppRoutes.channelPath(f['spaceId'] as String, chatId(f));
  }
  if (entryRoute != null) deps.appRouter.rememberNotificationRoute(entryRoute);
  // Matches main.dart ordering; cold notifications emitted here must survive
  // until MedCollabApp subscribes and authentication has finished.
  if (firebase) await deps.fcmService.initialize();
  await tester.pumpWidget(const MedCollabApp());
  await until(
      tester,
      () =>
          deps.authBloc.state.status != AuthStatus.unknown &&
          deps.authBloc.state.status != AuthStatus.loading,
      'authentication settles');
}

Future<void> until(
    WidgetTester tester, bool Function() predicate, String reason,
    {Duration limit = const Duration(seconds: 15)}) async {
  final watch = Stopwatch()..start();
  while (!predicate() && watch.elapsed < limit) {
    await tester.pump(const Duration(milliseconds: 50));
    checkFramework(tester);
  }
  checkFramework(tester);
  expect(predicate(), isTrue, reason: reason);
}

void checkFramework(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null)
    throw TestFailure('Application framework exception: $error');
}

Future<void> login(WidgetTester tester, String label, {bool resumeChat = false}) async {
  final f = await fixture();
  if (resumeChat) deps.appRouter.rememberNotificationRoute(
    AppRoutes.channelPath(f['spaceId'] as String, chatId(f)));
  final person = f[label] as Map<String, dynamic>;
  deps.authBloc.add(
      AuthPhoneSubmitted((person['phone'] as String).replaceFirst('+91', '')));
  await until(tester, () => deps.authBloc.state.status == AuthStatus.otpSent,
      'synthetic OTP request through the real AuthBloc');
  final otp = await control('otp', {'label': label});
  deps.authBloc.add(AuthOtpSubmitted(otp['otp'] as String));
  await until(
      tester,
      () => deps.authBloc.state.status == AuthStatus.authenticated,
      'login authenticates the intended synthetic identity');
  expect(deps.authBloc.state.user?.id, person['userId']);
}

Future<void> logout(WidgetTester tester) async {
  deps.authBloc.add(const AuthLogoutRequested());
  await until(
      tester,
      () => deps.authBloc.state.status == AuthStatus.unauthenticated,
      'logout terminates authentication');
  expect(await deps.secureStorage.hasSession(), isFalse);
  expect(await deps.secureStorage.getAccessToken(), isNull);
  expect(await deps.secureStorage.getRefreshToken(), isNull);
  expect(await deps.secureStorage.getUserId(), isNull);
}

Future<void> openChat(WidgetTester tester, String channelId) async {
  final f = await fixture();
  deps.appRouter.router
      .go(AppRoutes.channelPath(f['spaceId'] as String, channelId));
  await until(tester, () => find.byType(ChannelChatPage).evaluate().any((element) =>
      (element.widget as ChannelChatPage).channelId == channelId) &&
      find.byType(MentionAwareComposer).evaluate().isNotEmpty,
      'chat composer mounts');
  await until(tester, () => deps.socketClient.isConnected,
      'real local Socket.IO connects');
}

// A PASS is emitted only after the body and any pending framework exception are
// checked. Setup/control failures remain ERROR; required business assertions FAIL.
void deviceCase(String id, Future<void> Function(WidgetTester) body) {
  testWidgets('$id: Android $devicePhase', (tester) async {
    final watch = Stopwatch()..start();
    observations.clear();
    var status = 'PASS';
    String? error;
    Object? failure;
    StackTrace? stack;
    try {
      await body(tester);
      await tester.pump();
      checkFramework(tester);
    } catch (e, st) {
      status = e is DeviceInfrastructureError
          ? 'ERROR'
          : e is DeviceDecision
              ? 'NEEDS_DECISION'
              : 'FAIL';
      error = e.toString();
      failure = e;
      stack = st;
    }
    final record = {
      'id': id,
      'status': status,
      'executed': true,
      'phase': devicePhase,
      'runId': deviceRun,
      'processId': pid,
      'durationMs': watch.elapsedMilliseconds,
      'evidence': List.of(observations),
      if (error != null) 'error': error
    };
    // Preserve the original business outcome even if the control connection
    // fails while reporting it. The host driver writes this fallback evidence.
    binding.reportData = {'case': record};
    final diagnostic = jsonEncode(record)
        .replaceAll(RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), '[redacted-jwt]')
        .replaceAll(RegExp(r'synthetic-device-[a-z0-9_-]+'), '[redacted-device-token]');
    // A transport-independent copy preserves the first failure if the report
    // POST or integration driver's response-data callback cannot complete.
    // ignore: avoid_print
    print('VOCLE_DEVICE_RECORD $diagnostic');
    await control('result', record);
    if (failure != null && status != 'NEEDS_DECISION')
      Error.throwWithStackTrace(failure, stack!);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<void> checkpoint(String phase, Map<String, dynamic> evidence) async {
  await control('checkpoint', {
    'phase': phase,
    'runId': deviceRun,
    'processId': pid,
    'status': 'PASS',
    'evidence': evidence
  });
}

class LifecycleTrace with WidgetsBindingObserver {
  final states = <AppLifecycleState>[];
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    states.add(state);
  }
}

Future<Map<String, dynamic>> peerMessage(String channelId, String text) =>
    control('peer-message', {'channelId': channelId, 'text': text});

Future<List<Map<String, dynamic>>> storedMessages(String channelId) async {
  final result = await control('messages', {'channelId': channelId});
  return (result['messages'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
}

String chatId(Map<String, dynamic> f) => f['channelId'] as String;

Future<void> cleanupDevice(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await deps.socketClient.disconnect();
}
