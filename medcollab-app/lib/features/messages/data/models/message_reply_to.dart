import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';

/// WhatsApp-style quote snapshot embedded on a message.
class MessageReplyTo extends Equatable {
  const MessageReplyTo({
    required this.messageId,
    this.senderId,
    this.senderName,
    this.text,
    this.type = MessageType.text,
  });

  factory MessageReplyTo.fromJson(Map<String, dynamic> json) {
    final id = json['messageId'] ?? json['_id'] ?? json['id'];
    return MessageReplyTo(
      messageId: id?.toString() ?? '',
      senderId: json['senderId']?.toString(),
      senderName: json['senderName'] as String?,
      text: json['text'] as String?,
      type: MessageType.fromString(json['type'] as String?),
    );
  }

  factory MessageReplyTo.fromMessage({
    required String messageId,
    required String senderName,
    required MessageType type,
    String? senderId,
    String? text,
  }) {
    return MessageReplyTo(
      messageId: messageId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: type,
    );
  }

  final String messageId;
  final String? senderId;
  final String? senderName;
  final String? text;
  final MessageType type;

  String get previewLabel {
    final t = (text ?? '').trim();
    if (t.isNotEmpty) return t;
    switch (type) {
      case MessageType.image:
      case MessageType.ecg:
        return 'Photo';
      case MessageType.video:
        return 'Video';
      case MessageType.document:
        return 'Document';
      case MessageType.handoff:
        return 'Handoff';
      case MessageType.audio:
        return 'Voice message';
      default:
        return 'Message';
    }
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        if (senderId != null) 'senderId': senderId,
        if (senderName != null) 'senderName': senderName,
        if (text != null) 'text': text,
        'type': type.value,
      };

  @override
  List<Object?> get props => [messageId, senderId, senderName, text, type];
}

MessageReplyTo? parseMessageReplyTo(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) return null;
  final id = map['messageId'] ?? map['_id'] ?? map['id'];
  if (id == null || id.toString().isEmpty || id.toString() == 'null') {
    return null;
  }
  return MessageReplyTo.fromJson(map);
}
