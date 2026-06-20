import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';

/// Channel sidebar preview — embedded on [ChannelModel.lastMessage].
class LastMessagePreview extends Equatable {
  const LastMessagePreview({
    this.messageId,
    this.text,
    this.senderName,
    this.type = MessageType.text,
    this.sentAt,
  });

  factory LastMessagePreview.fromJson(Map<String, dynamic> json) {
    return LastMessagePreview(
      messageId: json['messageId']?.toString(),
      text: json['text'] as String?,
      senderName: json['senderName'] as String?,
      type: MessageType.fromString(json['type'] as String?),
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString())
          : null,
    );
  }

  final String? messageId;
  final String? text;
  final String? senderName;
  final MessageType type;
  final DateTime? sentAt;

  @override
  List<Object?> get props =>
      [messageId, text, senderName, type, sentAt];
}
