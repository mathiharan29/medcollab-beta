// REQ 4: replying from the notification shade must still work after the
// 15-minute access token has expired (it used to fail every time).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/notifications/notification_reply_sender.dart';
import 'package:medcollab_app/core/storage/storage_keys.dart';

class _Server implements HttpClientAdapter {
  final calls = <String>[];
  String validToken = 'fresh-token';

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
      Future<void>? __) async {
    final auth = o.headers['Authorization']?.toString() ?? '';
    calls.add('${o.method} ${o.path} $auth');
    ResponseBody json(int code, Object body) => ResponseBody.fromString(
          jsonEncode(body),
          code,
          headers: {
            'content-type': ['application/json'],
          },
        );
    if (o.path.endsWith('/auth/refresh')) {
      final body = o.data as Map;
      if (body['refreshToken'] != 'refresh-1') {
        return json(401, {'success': false, 'message': 'Invalid'});
      }
      return json(200, {
        'success': true,
        'message': 'Token refreshed',
        'data': {'accessToken': validToken},
      });
    }
    if (auth != 'Bearer $validToken') {
      return json(401, {'success': false, 'message': 'Token expired'});
    }
    return json(201, {'success': true, 'message': 'sent', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Server server;
  late Dio dio;
  const storage = FlutterSecureStorage();

  setUp(() {
    server = _Server();
    dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = server;
  });

  test('expired access token: refreshes, saves, and retries the reply',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      StorageKeys.accessToken: 'expired-token',
      StorageKeys.refreshToken: 'refresh-1',
    });

    await NotificationReplySender.postReply(dio,
        channelId: 'c1', text: 'On my way', token: 'expired-token',
        storage: storage);

    expect(server.calls, hasLength(3));
    expect(server.calls[0], contains('Bearer expired-token'));
    expect(server.calls[1], contains('/auth/refresh'));
    expect(server.calls[2], contains('Bearer fresh-token'));
    expect(await storage.read(key: StorageKeys.accessToken), 'fresh-token',
        reason: 'the app should not need to refresh again');
  });

  test('valid token: one request, no refresh', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await NotificationReplySender.postReply(dio,
        channelId: 'c1', text: 'ok', token: 'fresh-token', storage: storage);
    expect(server.calls, hasLength(1));
  });

  test('refresh rejected (signed out elsewhere): reply fails visibly',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      StorageKeys.refreshToken: 'revoked',
    });
    await expectLater(
      NotificationReplySender.postReply(dio,
          channelId: 'c1', text: 'x', token: 'expired-token', storage: storage),
      throwsA(isA<DioException>()),
    );
  });
}
