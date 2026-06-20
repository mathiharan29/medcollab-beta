import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';

class MessageContent extends Equatable {
  const MessageContent({this.text});

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    return MessageContent(text: json['text'] as String?);
  }

  final String? text;

  Map<String, dynamic> toJson() => {'text': text};

  @override
  List<Object?> get props => [text];
}

class MessageModel extends Equatable {
  const MessageModel({
    required this.id,
    required this.channelId,
    required this.sender,
    this.type = MessageType.text,
    this.content = const MessageContent(),
    this.priority = MessagePriority.normal,
    this.isEdited = false,
    this.isDeleted = false,
    this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['id'];
    final senderRaw = json['senderId'];
    final UserModel sender;
    if (senderRaw is Map<String, dynamic>) {
      sender = UserModel.fromJson(senderRaw);
    } else {
      sender = UserModel(id: senderRaw?.toString() ?? '');
    }

    return MessageModel(
      id: id.toString(),
      channelId: json['channelId']?.toString() ?? '',
      sender: sender,
      type: MessageType.fromString(json['type'] as String?),
      content: json['content'] is Map<String, dynamic>
          ? MessageContent.fromJson(json['content'] as Map<String, dynamic>)
          : const MessageContent(),
      priority: MessagePriority.fromString(json['priority'] as String?),
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
  final bool isEdited;
  final bool isDeleted;
  final DateTime? createdAt;

  String get displayText {
    if (isDeleted) return 'This message was deleted';
    return content.text ?? '';
  }

  @override
  List<Object?> get props =>
      [id, channelId, sender, type, content, priority, isEdited, isDeleted, createdAt];
}
