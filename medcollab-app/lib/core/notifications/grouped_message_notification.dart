import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One shade entry per conversation, with each new line appended underneath.
class GroupedMessageNotification {
  static const _prefsPrefix = 'vocle_notif_lines_';
  static const _maxLines = 8;

  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> showFromRemote(RemoteMessage message) async {
    final data = message.data;
    final title = message.notification?.title ??
        data['title']?.toString() ??
        'Vocle';
    final body = message.notification?.body ?? data['body']?.toString() ?? '';
    if (body.isEmpty && title.isEmpty) return;
    await show(
      title: title,
      body: body,
      data: {
        ...data,
        'title': title,
        'body': body,
      },
    );
  }

  /// Posts (or re-posts) a chat's conversation notification.
  ///
  /// [outgoing]: [body] is the doctor's own reply — shown as "You", like
  /// WhatsApp. An empty [body] re-posts the conversation unchanged (ends
  /// Android's inline-reply spinner).
  static Future<void> show({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    bool outgoing = false,
  }) async {
    final type = data['type']?.toString() ?? '';
    final emergency = type.toLowerCase().contains('emergency');
    final channelKey = data['channelId']?.toString() ?? '';
    final groupKey = !emergency && channelKey.isNotEmpty
        ? channelKey
        : 'solo-${DateTime.now().millisecondsSinceEpoch}';

    List<_Line> lines;
    try {
      lines = await _appendLine(groupKey, body, mine: outgoing);
    } catch (_) {
      // Storage unavailable (e.g. background isolate trouble): still post.
      lines = body.trim().isEmpty
          ? const []
          : [_Line(body.trim(), DateTime.now().millisecondsSinceEpoch, mine: outgoing)];
    }
    final id = _idFor(groupKey);

    final person = Person(name: title, key: groupKey);
    final style = MessagingStyleInformation(
      const Person(name: 'You', key: 'me'),
      conversationTitle: title,
      groupConversation: false,
      messages: [
        for (final line in lines)
          Message(
            line.text,
            DateTime.fromMillisecondsSinceEpoch(line.at),
            // null person = the device user ("You").
            line.mine ? null : person,
          ),
      ],
    );

    final actions = channelKey.isEmpty
        ? const <AndroidNotificationAction>[]
        : <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'reply',
              'Reply',
              inputs: <AndroidNotificationActionInput>[
                AndroidNotificationActionInput(label: 'Message'),
              ],
              cancelNotification: false,
              showsUserInterface: false,
            ),
            const AndroidNotificationAction(
              'mark_read',
              'Mark as read',
              showsUserInterface: false,
            ),
          ];

    await plugin.show(
      id,
      title,
      lines.isEmpty ? (body.isEmpty ? title : body) : lines.last.text,
      NotificationDetails(
        android: AndroidNotificationDetails(
          emergency ? 'emergency' : 'messages',
          emergency ? 'Emergency' : 'Messages',
          channelDescription: emergency
              ? 'Emergency channel alerts'
              : 'Clinical chat and handoffs',
          importance: emergency ? Importance.max : Importance.high,
          priority: emergency ? Priority.max : Priority.high,
          icon: '@mipmap/ic_launcher',
          tag: groupKey,
          category: AndroidNotificationCategory.message,
          styleInformation: style,
          actions: actions,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({
        'type': type,
        'notificationId': data['notificationId'],
        'spaceId': data['spaceId'],
        'channelId': data['channelId'],
        'messageId': data['messageId'],
        'handoffId': data['handoffId'],
        'title': title,
        'body': body,
      }),
    );
  }

  /// Removes a chat's notification and forgets its lines, so the next
  /// message starts a fresh conversation entry instead of re-showing ones
  /// already read (REQ 4). Called when the chat is opened or marked read.
  static Future<void> clear(String channelId) async {
    if (channelId.isEmpty) return;
    try {
      await plugin.cancel(_idFor(channelId), tag: channelId);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefsPrefix$channelId');
    } catch (_) {}
  }

  static int _idFor(String key) => key.hashCode & 0x7fffffff;

  static Future<List<_Line>> _appendLine(
    String key,
    String text, {
    bool mine = false,
  }) async {
    final trimmed = text.trim();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('$_prefsPrefix$key');
    final lines = <_Line>[];
    if (stored != null && stored.isNotEmpty) {
      try {
        final raw = jsonDecode(stored);
        if (raw is List) {
          for (final item in raw) {
            if (item is Map) {
              lines.add(
                _Line(
                  item['text']?.toString() ?? '',
                  (item['at'] as num?)?.toInt() ??
                      DateTime.now().millisecondsSinceEpoch,
                  mine: item['mine'] == true,
                ),
              );
            }
          }
        }
      } catch (_) {}
    }
    if (trimmed.isEmpty) return lines; // re-post as is
    lines.add(_Line(trimmed, DateTime.now().millisecondsSinceEpoch, mine: mine));
    final kept = lines.length > _maxLines
        ? lines.sublist(lines.length - _maxLines)
        : lines;
    await prefs.setString(
      '$_prefsPrefix$key',
      jsonEncode([
        for (final line in kept)
          {'text': line.text, 'at': line.at, if (line.mine) 'mine': true},
      ]),
    );
    return kept;
  }
}

class _Line {
  const _Line(this.text, this.at, {this.mine = false});
  final String text;
  final int at;
  final bool mine;
}
