import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/notifications/grouped_message_notification.dart';
import 'package:medcollab_app/core/storage/storage_keys.dart';

/// Result of a reply from the shade (exposed for tests and logs).
enum ShadeReplyOutcome { sent, failed, signedOut, ignored }

/// Re-posts a chat's shade notification. Android shows a spinner on the
/// inline reply until the notification is posted again, so EVERY path
/// through [NotificationReplySender.send] must end here.
typedef ShadeRepost = Future<void> Function({
  required String channelId,
  required String title,
  required Map<String, dynamic> payload,
  String? outgoingText,
  String? statusText,
});

/// Sends a chat reply from the notification shade without opening the app.
///
/// Runs in the notification plugin's BACKGROUND isolate for inline replies
/// (even while the app is open), so it never touches app singletons.
class NotificationReplySender {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const markReadAction = 'mark_read';
  static const replyAction = 'reply';

  /// Whole reply budget: after this the doctor sees "Not sent" instead of a
  /// spinner that never stops (beta 11-14, issue 7).
  static const budget = Duration(seconds: 25);

  static Future<ShadeReplyOutcome> send(
    NotificationResponse response, {
    Dio? dio,
    FlutterSecureStorage storage = _storage,
    ShadeRepost repost = _defaultRepost,
  }) async {
    if (response.actionId == markReadAction) {
      await _markRead(response, dio: dio, storage: storage);
      return ShadeReplyOutcome.ignored;
    }
    if (response.actionId != replyAction) return ShadeReplyOutcome.ignored;

    final map = _decode(response.payload);
    final channelId = map?['channelId']?.toString() ?? '';
    if (map == null || channelId.isEmpty) return ShadeReplyOutcome.ignored;
    final title = map['title']?.toString() ?? 'Vocle';
    final text = response.input?.trim() ?? '';

    var outcome = ShadeReplyOutcome.failed;
    try {
      if (text.isEmpty) {
        outcome = ShadeReplyOutcome.ignored;
      } else {
        outcome = await _deliver(
          channelId: channelId,
          text: text,
          dio: dio ?? _dio(),
          storage: storage,
        ).timeout(budget, onTimeout: () => ShadeReplyOutcome.failed);
      }
    } catch (e) {
      debugPrint('Shade reply failed: $e');
      outcome = ShadeReplyOutcome.failed;
    } finally {
      // Always end the spinner — success, failure, signed out or empty.
      try {
        await repost(
          channelId: channelId,
          title: title,
          payload: map,
          outgoingText: outcome == ShadeReplyOutcome.sent ? text : null,
          statusText: switch (outcome) {
            ShadeReplyOutcome.failed => 'Not sent: "$text" — tap to open and retry',
            ShadeReplyOutcome.signedOut => 'Sign in to Vocle to reply',
            _ => null,
          },
        );
      } catch (e) {
        debugPrint('Shade repost failed: $e');
      }
    }
    return outcome;
  }

  static Future<ShadeReplyOutcome> _deliver({
    required String channelId,
    required String text,
    required Dio dio,
    required FlutterSecureStorage storage,
  }) async {
    final token = await storage
        .read(key: StorageKeys.accessToken)
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    final refresh = await storage
        .read(key: StorageKeys.refreshToken)
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if ((token == null || token.isEmpty) &&
        (refresh == null || refresh.isEmpty)) {
      return ShadeReplyOutcome.signedOut;
    }
    try {
      await postReply(
        dio,
        channelId: channelId,
        text: text,
        token: token ?? '',
        storage: storage,
      );
    } on StateError {
      return ShadeReplyOutcome.signedOut;
    } on DioException catch (e) {
      // One retry for a dropped connection (phone just woke up / switched
      // network). Never retry a response: the server may have saved it.
      final transient = e.response == null &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout);
      if (!transient) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final latest = await storage.read(key: StorageKeys.accessToken);
      await postReply(
        dio,
        channelId: channelId,
        text: text,
        token: latest ?? token ?? '',
        storage: storage,
      );
    }
    // Replying means the chat was read (WhatsApp): clear its alerts.
    try {
      final latest = await storage.read(key: StorageKeys.accessToken);
      await authorized(
        dio,
        token: latest ?? token ?? '',
        storage: storage,
        call: (bearer) => dio.put<dynamic>(
          ApiEndpoints.markNotificationsReadByChannel(channelId),
          options: Options(headers: {'Authorization': 'Bearer $bearer'}),
        ),
      );
    } catch (_) {}
    return ShadeReplyOutcome.sent;
  }

  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Dio _dio() => Dio(
        BaseOptions(
          baseUrl: EnvConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        ),
      );

  static Future<void> _defaultRepost({
    required String channelId,
    required String title,
    required Map<String, dynamic> payload,
    String? outgoingText,
    String? statusText,
  }) =>
      GroupedMessageNotification.show(
        title: title,
        body: statusText ?? outgoingText ?? '',
        outgoing: outgoingText != null || statusText != null,
        data: {...payload, 'title': title, 'channelId': channelId},
      );

  /// "Mark as read" from the shade (REQ 4): clears this chat's unread
  /// alerts on the server and removes the notification, like WhatsApp.
  static Future<void> _markRead(
    NotificationResponse response, {
    Dio? dio,
    FlutterSecureStorage storage = _storage,
  }) async {
    final channelId = _decode(response.payload)?['channelId']?.toString() ?? '';
    if (channelId.isEmpty) return;
    // Remove it from the shade straight away; the server call follows.
    try {
      await GroupedMessageNotification.clear(channelId);
    } catch (_) {}
    try {
      final token = await storage.read(key: StorageKeys.accessToken);
      final client = dio ?? _dio();
      await authorized(
        client,
        token: token ?? '',
        storage: storage,
        call: (bearer) => client.put<dynamic>(
          ApiEndpoints.markNotificationsReadByChannel(channelId),
          options: Options(headers: {'Authorization': 'Bearer $bearer'}),
        ),
      ).timeout(budget);
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

  /// Runs [call] with [token]; on 401 (or no token) refreshes once, saves
  /// and retries.
  @visibleForTesting
  static Future<void> authorized(
    Dio dio, {
    required String token,
    required Future<Object?> Function(String bearer) call,
    FlutterSecureStorage storage = _storage,
  }) async {
    if (token.isNotEmpty) {
      try {
        await call(token);
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 401) rethrow;
      }
    }

    final refresh = await storage.read(key: StorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) {
      throw StateError('signed out');
    }
    final Response<Map<String, dynamic>> res;
    try {
      res = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refresh},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw StateError('signed out');
      rethrow;
    }
    final data = res.data?['data'];
    final fresh = data is Map ? data['accessToken'] as String? : null;
    if (fresh == null || fresh.isEmpty) throw StateError('refresh failed');
    await storage.write(key: StorageKeys.accessToken, value: fresh);
    await call(fresh);
  }
}
