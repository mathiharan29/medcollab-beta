import 'package:equatable/equatable.dart';

/// Snapshot of the latest reply on a root message — mirrors backend `lastReply`.
class ThreadReplyPreview extends Equatable {
  const ThreadReplyPreview({
    this.senderName,
    this.text,
    this.sentAt,
  });

  factory ThreadReplyPreview.fromJson(Map<String, dynamic> json) {
    return ThreadReplyPreview(
      senderName: json['senderName'] as String?,
      text: json['text'] as String?,
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString())
          : null,
    );
  }

  final String? senderName;
  final String? text;
  final DateTime? sentAt;

  @override
  List<Object?> get props => [senderName, text, sentAt];
}
