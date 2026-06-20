import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_delivery_state.dart';
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
  });

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    return MessageContent(
      text: json['text'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      mimeType: json['mimeType'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  final String? text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final int? width;
  final int? height;

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
      };

  @override
  List<Object?> get props =>
      [text, mediaUrl, thumbnailUrl, fileName, fileSize, mimeType, width, height];
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
    this.replyCount = 0,
    this.lastReply,
    this.isEdited = false,
    this.isDeleted = false,
    this.createdAt,
    this.deliveryState,
    this.localOnly = false,
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
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      lastReply: lastReplyJson != null
          ? ThreadReplyPreview.fromJson(lastReplyJson)
          : null,
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  final String id;
  final String channelId;
  final UserModel sender;
  final MessageType type;
  final MessageContent content;
  final MessagePriority priority;
  final String? threadId;
  final int replyCount;
  final ThreadReplyPreview? lastReply;
  final bool isEdited;
  final bool isDeleted;
  final DateTime? createdAt;
  final MessageDeliveryState? deliveryState;
  final bool localOnly;

  bool get isThreadReply => threadId != null && threadId!.isNotEmpty;
  bool get hasThread => replyCount > 0;

  String get displayText {
    if (isDeleted) return 'This message was deleted';
    if (type == MessageType.image) return content.text ?? 'Image';
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
    int? replyCount,
    ThreadReplyPreview? lastReply,
    bool? isEdited,
    bool? isDeleted,
    DateTime? createdAt,
    MessageDeliveryState? deliveryState,
    bool? localOnly,
  }) {
    return MessageModel(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      threadId: threadId ?? this.threadId,
      replyCount: replyCount ?? this.replyCount,
      lastReply: lastReply ?? this.lastReply,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      deliveryState: deliveryState ?? this.deliveryState,
      localOnly: localOnly ?? this.localOnly,
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
        replyCount,
        lastReply,
        isEdited,
        isDeleted,
        createdAt,
        deliveryState,
        localOnly,
      ];
}
