// REQ 4: replying from the notification shade must still work after the
// 15-minute access token has expired (it used to fail every time).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/notifications/notification_reply_sender.dart';
import 'package:medcollab_app/core/storage/storage_keys.dart';

class _Server implements HttpClientAdapter {
  final calls = <String>[];
  String validToken = 'fresh-token';
  int? failWith;
  int dropNext = 0;
  bool hang = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _,
      Future<void>? __) async {
    final auth = o.headers['Authorization']?.toString() ?? '';
    calls.add('${o.method} ${o.path} $auth');
    if (hang) await Completer<void>().future;
    if (dropNext > 0) {
      dropNext--;
      throw DioException.connectionError(
          requestOptions: o, reason: 'synthetic drop');
    }
    if (failWith != null && o.method == 'POST') {
      return ResponseBody.fromString('{"success":false}', failWith!,
          headers: {'content-type': ['application/json']});
    }
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
      throwsA(isA<StateError>()),
    );
  });

  // Issue 7 (beta 11-14): the reply spinner must ALWAYS end, with the
  // outcome visible in the shade.
  group('send() always re-posts the conversation', () {
    late List<Map<String, Object?>> reposts;
    Future<void> repost({
      required String channelId,
      required String title,
      required Map<String, dynamic> payload,
      String? outgoingText,
      String? statusText,
    }) async {
      reposts.add({
        'channel': channelId,
        'out': outgoingText,
        'status': statusText,
      });
    }

    NotificationResponse reply(String? text) => NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'reply',
          input: text,
          payload: jsonEncode({'channelId': 'c1', 'title': 'Dr Bala'}),
        );

    setUp(() => reposts = []);

    test('sent: own line added, chat marked read', () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.accessToken: 'fresh-token',
        StorageKeys.refreshToken: 'refresh-1',
      });
      final r = await NotificationReplySender.send(reply('On my way'),
          dio: dio, storage: storage, repost: repost);
      expect(r, ShadeReplyOutcome.sent);
      expect(reposts.single['out'], 'On my way');
      expect(server.calls.where((c) => c.startsWith('POST')), hasLength(1));
      expect(server.calls.any((c) => c.contains('read-by-channel')), isTrue);
    });

    test('server error: "Not sent" shown, no spinner left', () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.accessToken: 'fresh-token',
      });
      server.failWith = 500;
      final r = await NotificationReplySender.send(reply('BP 90/60'),
          dio: dio, storage: storage, repost: repost);
      expect(r, ShadeReplyOutcome.failed);
      expect(reposts.single['status'], contains('Not sent'));
      expect(server.calls.where((c) => c.startsWith('POST')), hasLength(1),
          reason: 'a server response is never retried (could duplicate)');
    });

    test('dropped connection: retried once, then sent', () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.accessToken: 'fresh-token',
      });
      server.dropNext = 1;
      final r = await NotificationReplySender.send(reply('Coming'),
          dio: dio, storage: storage, repost: repost);
      expect(r, ShadeReplyOutcome.sent);
      expect(reposts.single['out'], 'Coming');
    });

    test('signed out: tells the doctor to sign in', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final r = await NotificationReplySender.send(reply('x'),
          dio: dio, storage: storage, repost: repost);
      expect(r, ShadeReplyOutcome.signedOut);
      expect(reposts.single['status'], contains('Sign in'));
      expect(server.calls, isEmpty);
    });

    test('empty reply: nothing sent, spinner still ends', () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.accessToken: 'fresh-token',
      });
      final r = await NotificationReplySender.send(reply('   '),
          dio: dio, storage: storage, repost: repost);
      expect(r, ShadeReplyOutcome.ignored);
      expect(reposts, hasLength(1));
      expect(server.calls, isEmpty);
    });

    test('server never answers: gives up within the budget', () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.accessToken: 'fresh-token',
      });
      server.hang = true;
      final sw = Stopwatch()..start();
      final r = await NotificationReplySender.send(reply('late'),
          dio: dio, storage: storage, repost: repost);
      expect(r, ShadeReplyOutcome.failed);
      expect(reposts.single['status'], contains('Not sent'));
      expect(sw.elapsed, lessThan(NotificationReplySender.budget +
          const Duration(seconds: 2)));
    }, timeout: const Timeout(Duration(seconds: 40)));
  });
}
