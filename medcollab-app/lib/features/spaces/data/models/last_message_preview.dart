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

  /// Sidebar-friendly label (handles media with empty text).
  /// Older forwards were plain text with a vocle:// link (beta 11-26).
  static final _legacyForward = RegExp(
    r'^\s*(?:↪️|↪)?\s*Forwarded from [^\n]*\n\s*vocle://\S*\s*',
  );

  String get previewLabel {
    var t = text?.trim();
    if (t != null && _legacyForward.hasMatch(t)) {
      t = t.replaceFirst(_legacyForward, '').trim();
      return t.isEmpty ? '↪ Forwarded message' : '↪ $t';
    }
    if (t != null && t.isNotEmpty) return t;
    return switch (type) {
      MessageType.image => '📷 Photo',
      MessageType.video => '🎥 Video',
      MessageType.document => '📎 Document',
      MessageType.ecg => '📈 ECG',
      MessageType.handoff => '🔄 Handoff',
      MessageType.alert => '⚠️ Alert',
      MessageType.audio => '🎤 Voice message',
      MessageType.system => 'Group update',
      MessageType.text => 'Message',
    };
  }

  @override
  List<Object?> get props =>
      [messageId, text, senderName, type, sentAt];
}
