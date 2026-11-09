import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_delivery_state.dart';
import 'package:medcollab_app/features/messages/data/models/message_read_receipt.dart';
import 'package:medcollab_app/features/messages/data/models/message_reply_to.dart';
import 'package:medcollab_app/features/messages/data/models/thread_reply_preview.dart';

class MessageContent extends Equatable {
  const MessageContent({
    this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.width,
    this.height,
    this.durationMs,
    this.waveform = const [],
  });

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    return MessageContent(
      text: _stringOrNull(json['text']),
      mediaUrl: json['mediaUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      mimeType: json['mimeType'] as String?,
      // num, not int: some uploads report 1080.0.
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      waveform: (json['waveform'] is List)
          ? (json['waveform'] as List)
              .whereType<num>()
              .map((n) => n.toInt().clamp(0, 100))
              .toList()
          : const [],
    );
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    // Defensive: never crash the chat list on coerced API payloads.
    return value.toString();
  }

  final String? text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final int? width;
  final int? height;

  /// Voice note length (REQ 12).
  final int? durationMs;

  /// Voice note loudness bars, 0–100 (REQ 12).
  final List<int> waveform;

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        if (text != null) 'text': text,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (mimeType != null) 'mimeType': mimeType,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationMs != null) 'durationMs': durationMs,
        if (waveform.isNotEmpty) 'waveform': waveform,
      };

  @override
  List<Object?> get props =>
      [text, mediaUrl, thumbnailUrl, fileName, fileSize, mimeType, width, height,
       durationMs, waveform];
}

class MessageModel extends Equatable {
  const MessageModel({
    required this.id,
    required this.channelId,
    required this.sender,
    this.type = MessageType.text,
    this.content = const MessageContent(),
    this.priority = MessagePriority.normal,
    this.threadId,
    this.replyTo,
    this.replyCount = 0,
    this.lastReply,
    this.isEdited = false,
    this.isDeleted = false,
    this.createdAt,
    this.deliveryState,
    this.localOnly = false,
    this.mentions = const [],
    this.readBy = const [],
    this.reactions = const [],
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['id'];
    final senderJson = asJsonMap(json['senderId']) ?? asJsonMap(json['sender']);
    final UserModel sender;
    if (senderJson != null) {
      sender = UserModel.fromJson(senderJson);
    } else {
      sender = UserModel(id: json['senderId']?.toString() ?? '');
    }

    final contentJson = asJsonMap(json['content']);
    final lastReplyJson = asJsonMap(json['lastReply']);
    final mentionsRaw = json['mentions'];
    final readByRaw = json['readBy'];
    final reactionsRaw = json['reactions'];

    return MessageModel(
      id: id.toString(),
      channelId: json['channelId']?.toString() ?? '',
      sender: sender,
      type: MessageType.fromString(json['type'] as String?),
      content: contentJson != null
          ? MessageContent.fromJson(contentJson)
          : const MessageContent(),
      priority: MessagePriority.fromString(json['priority'] as String?),
      threadId: json['threadId']?.toString(),
      replyTo: parseMessageReplyTo(json['replyTo']),
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      lastReply: lastReplyJson != null
          ? ThreadReplyPreview.fromJson(lastReplyJson)
          : null,
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      mentions: mentionsRaw is List
          ? mentionsRaw
              .map((m) {
                final map = asJsonMap(m);
                if (map != null) {
                  return UserModel.fromJson(map).id;
                }
                return m?.toString() ?? '';
              })
              .where((id) => id.isNotEmpty && id != 'null')
              .toList()
          : const [],
      readBy: readByRaw is List
          ? readByRaw
              .map(asJsonMap)
              .whereType<Map<String, dynamic>>()
              .map(MessageReadReceipt.fromJson)
              .toList()
          : const [],
      reactions: reactionsRaw is List
          ? reactionsRaw
              .map(asJsonMap)
              .whereType<Map<String, dynamic>>()
              .map(MessageReaction.fromJson)
              .toList()
          : const [],
    );
  }

  final String id;
  final String channelId;
  final UserModel sender;
  final MessageType type;
  final MessageContent content;
  final MessagePriority priority;
  final String? threadId;
  final MessageReplyTo? replyTo;
  final int replyCount;
  final ThreadReplyPreview? lastReply;
  final bool isEdited;
  final bool isDeleted;
  final DateTime? createdAt;
  final MessageDeliveryState? deliveryState;
  final bool localOnly;
  final List<String> mentions;
  final List<MessageReadReceipt> readBy;
  final List<MessageReaction> reactions;

  bool get isThreadReply => threadId != null && threadId!.isNotEmpty;
  bool get hasThread => replyCount > 0;
  bool get hasQuoteReply => replyTo != null && replyTo!.messageId.isNotEmpty;

  String get displayText {
    if (isDeleted) return 'This message was deleted';
    if (type == MessageType.image) return content.text ?? 'Image';
    if (type == MessageType.video) {
      return content.text?.trim().isNotEmpty == true
          ? content.text!
          : (content.fileName ?? 'Video');
    }
    if (type == MessageType.document) {
      return content.fileName ?? content.text ?? 'Document';
    }
    return content.text ?? '';
  }

  MessageModel copyWith({
    String? id,
    String? channelId,
    UserModel? sender,
    MessageType? type,
    MessageContent? content,
    MessagePriority? priority,
    String? threadId,
    MessageReplyTo? replyTo,
    int? replyCount,
    ThreadReplyPreview? lastReply,
    bool? isEdited,
    bool? isDeleted,
    DateTime? createdAt,
    MessageDeliveryState? deliveryState,
    bool? localOnly,
    List<String>? mentions,
    List<MessageReadReceipt>? readBy,
    List<MessageReaction>? reactions,
    bool clearReplyTo = false,
  }) {
    return MessageModel(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      threadId: threadId ?? this.threadId,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      replyCount: replyCount ?? this.replyCount,
      lastReply: lastReply ?? this.lastReply,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      deliveryState: deliveryState ?? this.deliveryState,
      localOnly: localOnly ?? this.localOnly,
      mentions: mentions ?? this.mentions,
      readBy: readBy ?? this.readBy,
      reactions: reactions ?? this.reactions,
    );
  }

  @override
  List<Object?> get props => [
        id,
        channelId,
        sender,
        type,
        content,
        priority,
        threadId,
        replyTo,
        replyCount,
        lastReply,
        isEdited,
        isDeleted,
        createdAt,
        deliveryState,
        localOnly,
        mentions,
        readBy,
        reactions,
      ];
}

/// Emoji reaction aggregate for a message.
class MessageReaction extends Equatable {
  const MessageReaction({
    required this.emoji,
    this.userIds = const [],
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    final raw = json['userIds'];
    final ids = <String>[];
    if (raw is List) {
      for (final id in raw) {
        final s = id?.toString() ?? '';
        if (s.isNotEmpty && s != 'null') ids.add(s);
      }
    }
    return MessageReaction(
      emoji: json['emoji']?.toString() ?? '',
      userIds: ids,
    );
  }

  final String emoji;
  final List<String> userIds;

  int get count => userIds.length;

  bool reactedBy(String userId) => userIds.contains(userId);

  @override
  List<Object?> get props => [emoji, userIds];
}
