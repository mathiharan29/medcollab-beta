import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';

class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter({this.failRefresh = false, this.repeatUnauthorized = false,
    this.waitForConcurrentOldRequests = false});

  final bool failRefresh;
  final bool repeatUnauthorized;
  final bool waitForConcurrentOldRequests;
  final Completer<void> _oldRequestBarrier = Completer<void>();
  int oldRequests = 0;
  int refreshedRequests = 0;
  int refreshRequests = 0;
  final seenAuthorizations = <String>[];

  ResponseBody _json(int code, Map<String, dynamic> value) =>
      ResponseBody.fromString(jsonEncode(value), code,
          headers: {'content-type': ['application/json']});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path == ApiEndpoints.refreshToken) {
      refreshRequests++;
      expect(options.data, {'refreshToken': 'synthetic-refresh'});
      if (failRefresh) {
        return _json(401, {'success': false, 'message': 'Synthetic refresh denied'});
      }
      return _json(200, {
        'success': true,
        'data': {'accessToken': 'synthetic-new-$refreshRequests'},
      });
    }
    expect(options.path, '/protected');
    final auth = options.headers['Authorization']?.toString() ?? '';
    seenAuthorizations.add(auth);
    if (auth == 'Bearer synthetic-old') {
      oldRequests++;
      if (waitForConcurrentOldRequests) {
        if (oldRequests == 2 && !_oldRequestBarrier.isCompleted) {
          _oldRequestBarrier.complete();
        }
        await _oldRequestBarrier.future;
      }
      return _json(401, {'success': false, 'message': 'Synthetic expired token'});
    }
    if (auth.startsWith('Bearer synthetic-new-')) {
      refreshedRequests++;
      if (repeatUnauthorized && auth == 'Bearer synthetic-new-1') {
        return _json(401, {'success': false, 'message': 'Synthetic repeated 401'});
      }
      return _json(200, {'success': true, 'data': {'value': auth}});
    }
    return _json(401, {'success': false, 'message': 'Missing synthetic token'});
  }

  @override
  void close({bool force = false}) {}
}

Future<(ApiClient, SecureStorageService, _AuthAdapter)> _client(
    _AuthAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({});
  final storage = SecureStorageService(storage: const FlutterSecureStorage());
  await storage.saveSession(
    accessToken: 'synthetic-old',
    refreshToken: 'synthetic-refresh',
    userId: 'doctor-synthetic',
  );
  final dio = Dio(BaseOptions(baseUrl: 'https://synthetic.invalid'));
  dio.httpClientAdapter = adapter;
  return (ApiClient(storage: storage, dio: dio), storage, adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FR-NAV-02: concurrent 401 refresh and bounded-retry policy [NEEDS_DECISION Q7]', () async {
    final (client, storage, adapter) = await _client(
      _AuthAdapter(waitForConcurrentOldRequests: true),
    );
    final refreshed = <String>[];
    client.onAccessTokenRefreshed = (token) async { refreshed.add(token); };
    final responses = await Future.wait([
      client.get<String>('/protected', parser: (json) => json['value'] as String),
      client.get<String>('/protected', parser: (json) => json['value'] as String),
    ]);
    expect(responses.map((response) => response.requireData()),
        ['Bearer synthetic-new-1', 'Bearer synthetic-new-1']);
    expect(adapter.oldRequests, 2);
    expect(adapter.refreshRequests, 1,
        reason: 'Concurrent expired requests share one refresh in flight');
    expect(adapter.refreshedRequests, 2);
    expect(refreshed, ['synthetic-new-1']);
    expect(await storage.getAccessToken(), 'synthetic-new-1');

    final (failedClient, failedStorage, failedAdapter) = await _client(
      _AuthAdapter(failRefresh: true),
    );
    var expiredSignals = 0;
    failedClient.onSessionExpired = () { expiredSignals++; };
    await expectLater(
      failedClient.get<String>('/protected', parser: (json) => json['value'] as String),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(failedAdapter.refreshRequests, 1);
    expect(await failedStorage.hasSession(), isFalse);
    expect(await failedStorage.getUserId(), isNull);

    final (repeatClient, repeatStorage, repeatAdapter) = await _client(
      _AuthAdapter(repeatUnauthorized: true),
    );
    final repeated = await repeatClient.get<String>(
      '/protected', parser: (json) => json['value'] as String,
    );
    expect(repeated.requireData(), 'Bearer synthetic-new-2');
    expect(repeatAdapter.refreshRequests, 2);
    expect(repeatAdapter.seenAuthorizations,
        ['Bearer synthetic-old', 'Bearer synthetic-new-1', 'Bearer synthetic-new-2']);
    expect(await repeatStorage.getAccessToken(), 'synthetic-new-2');
    // This captures current recursive retry behavior. Q7 decides the bound.
    expect(expiredSignals, 1,
        reason: 'A failed refresh must notify the auth UI that its session expired');
  });
}
