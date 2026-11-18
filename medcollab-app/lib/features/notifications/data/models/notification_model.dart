import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';

enum AppNotificationCategory {
  mention,
  reply,
  message,
  invite,
  handoff,
  announcement,
  other,
}

class NotificationMetadata extends Equatable {
  const NotificationMetadata({
    this.spaceId,
    this.channelId,
    this.messageId,
    this.handoffId,
    this.voiceMode = false,
  });

  factory NotificationMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NotificationMetadata();
    return NotificationMetadata(
      spaceId: _cleanId(json['spaceId']),
      channelId: _cleanId(json['channelId']),
      messageId: _cleanId(json['messageId']),
      handoffId: _cleanId(json['handoffId']),
      voiceMode: json['voiceMode'] == true || json['voiceMode']?.toString() == 'true',
    );
  }

  /// A Needl Voice clip (opens the voice space).
  final bool voiceMode;

  /// Mongo nulls and the literal string "null" must not open fake routes.
  static String? _cleanId(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    return s;
  }

  final String? spaceId;
  final String? channelId;
  final String? messageId;
  final String? handoffId;

  @override
  List<Object?> get props => [spaceId, channelId, messageId, handoffId, voiceMode];
}

class AppNotificationModel extends Equatable {
  const AppNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
    this.actorName,
    this.metadata = const NotificationMetadata(),
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['id'];
    return AppNotificationModel(
      id: id.toString(),
      type: json['type'] as String? ?? 'new_message',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      actorName: json['actorName'] as String?,
      metadata: NotificationMetadata.fromJson(asJsonMap(json['metadata'])),
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;
  final String? actorName;
  final NotificationMetadata metadata;

  AppNotificationCategory get category {
    return switch (type) {
      'mention' => AppNotificationCategory.mention,
      'thread_reply' => AppNotificationCategory.reply,
      'space_invite' => AppNotificationCategory.invite,
      'handoff_received' || 'handoff_acknowledged' =>
        AppNotificationCategory.handoff,
      'emergency_alert' || 'new_message' when title.toLowerCase().contains('announce') =>
        AppNotificationCategory.announcement,
      'new_message' || 'emergency_alert' => AppNotificationCategory.message,
      _ => AppNotificationCategory.other,
    };
  }

  String get categoryLabel => switch (category) {
        AppNotificationCategory.mention => 'Mention',
        AppNotificationCategory.reply => 'Reply',
        AppNotificationCategory.message => 'Message',
        AppNotificationCategory.invite => 'Invite',
        AppNotificationCategory.handoff => 'Handoff',
        AppNotificationCategory.announcement => 'Announcement',
        AppNotificationCategory.other => 'Activity',
      };

  @override
  List<Object?> get props =>
      [id, type, title, body, read, createdAt, actorName, metadata];
}

class NotificationsPageResult {
  const NotificationsPageResult({
    required this.notifications,
    required this.hasMore,
    required this.unreadCount,
  });

  final List<AppNotificationModel> notifications;
  final bool hasMore;
  final int unreadCount;
}
