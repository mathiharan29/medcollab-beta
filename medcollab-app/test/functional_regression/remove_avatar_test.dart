// REQ 7: removing the profile photo sends avatarUrl:null to PUT /api/users/me
// and returns the user without a photo.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';

import 'fakes/chat_fakes.dart';

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'Profile updated',
        'data': {
          'user': {'_id': 'u1', 'name': 'Dr Asha Rao', 'avatarUrl': null},
        },
      }),
      200,
      headers: {'content-type': ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('removeAvatar PUTs avatarUrl:null and returns user without photo',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = isolatedApiClient();
    final adapter = _CaptureAdapter();
    api.dio.httpClientAdapter = adapter;

    final user = await UserRepository(apiClient: api).removeAvatar();

    expect(adapter.last!.method, 'PUT');
    expect(adapter.last!.path, endsWith('/users/me'));
    final body = adapter.last!.data is String
        ? jsonDecode(adapter.last!.data as String)
        : adapter.last!.data;
    expect((body as Map).containsKey('avatarUrl'), isTrue);
    expect(body['avatarUrl'], isNull);
    expect(user.avatarUrl, isNull);
  });
}
