import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/notifications/grouped_message_notification.dart';
import 'package:medcollab_app/core/storage/storage_keys.dart';

/// Sends a chat reply from the notification shade without opening the app.
class NotificationReplySender {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> send(NotificationResponse response) async {
    if (response.actionId == markReadAction) {
      await _markRead(response);
      return;
    }
    if (response.actionId != 'reply') return;
    final text = response.input?.trim() ?? '';
    if (text.isEmpty) return;
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;

    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      map = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    final channelId = map['channelId']?.toString() ?? '';
    if (channelId.isEmpty) return;

    final token = await _storage.read(key: StorageKeys.accessToken);
    if (token == null || token.isEmpty) return;

    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    try {
      await postReply(dio, channelId: channelId, text: text, token: token);

      // Android MessagingStyle reply spinner clears when we re-post the
      // conversation notification including the outbound line.
      final title = map['title']?.toString() ?? 'Vocle';
      await GroupedMessageNotification.show(
        title: title,
        body: 'You: $text',
        data: {
          ...map,
          'title': title,
          'body': 'You: $text',
          'channelId': channelId,
        },
      );
    } catch (_) {
      try {
        final title = map['title']?.toString() ?? 'Vocle';
        await GroupedMessageNotification.show(
          title: title,
          body: 'Reply failed — open chat to retry',
          data: {
            ...map,
            'title': title,
            'body': 'Reply failed — open chat to retry',
            'channelId': channelId,
          },
        );
      } catch (_) {}
    }
  }

  static const markReadAction = 'mark_read';

  /// "Mark as read" from the shade (REQ 4): clears this chat's unread
  /// alerts on the server and removes the notification, like WhatsApp.
  static Future<void> _markRead(NotificationResponse response) async {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    String channelId;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      channelId = decoded['channelId']?.toString() ?? '';
    } catch (_) {
      return;
    }
    if (channelId.isEmpty) return;
    // Remove it from the shade straight away; the server call follows.
    await GroupedMessageNotification.clear(channelId);
    final token = await _storage.read(key: StorageKeys.accessToken);
    if (token == null || token.isEmpty) return;
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    try {
      await authorized(
        dio,
        token: token,
        call: (bearer) => dio.put<dynamic>(
          ApiEndpoints.markNotificationsReadByChannel(channelId),
          options: Options(headers: {'Authorization': 'Bearer $bearer'}),
        ),
      );
    } catch (_) {
      // Best effort: opening the chat marks it read anyway.
    }
  }

  /// Posts the reply; on 401 (access tokens live 15 min, so any reply sent
  /// later than that used to fail) exchanges the stored refresh token for a
  /// new access token, saves it, and retries once (REQ 4).
  @visibleForTesting
  static Future<void> postReply(
    Dio dio, {
    required String channelId,
    required String text,
    required String token,
    FlutterSecureStorage storage = _storage,
  }) {
    return authorized(
      dio,
      token: token,
      storage: storage,
      call: (bearer) => dio.post<dynamic>(
        ApiEndpoints.channelMessages(channelId),
        data: {
          'type': 'text',
          'content': {'text': text},
        },
        options: Options(headers: {'Authorization': 'Bearer $bearer'}),
      ),
    );
  }

  /// Runs [call] with [token]; on 401 refreshes once, saves and retries.
  @visibleForTesting
  static Future<void> authorized(
    Dio dio, {
    required String token,
    required Future<Object?> Function(String bearer) call,
    FlutterSecureStorage storage = _storage,
  }) async {
    try {
      await call(token);
      return;
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;
    }

    final refresh = await storage.read(key: StorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) {
      throw StateError('signed out');
    }
    final res = await dio.post<Map<String, dynamic>>(
      ApiEndpoints.refreshToken,
      data: {'refreshToken': refresh},
    );
    final data = res.data?['data'];
    final fresh = data is Map ? data['accessToken'] as String? : null;
    if (fresh == null || fresh.isEmpty) throw StateError('refresh failed');
    await storage.write(key: StorageKeys.accessToken, value: fresh);
    await call(fresh);
  }
}
