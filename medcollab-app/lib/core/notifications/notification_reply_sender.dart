import 'dart:convert';

import 'package:dio/dio.dart';
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
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    try {
      await dio.post(
        ApiEndpoints.channelMessages(channelId),
        data: {
          'type': 'text',
          'content': {'text': text},
        },
      );

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
}
