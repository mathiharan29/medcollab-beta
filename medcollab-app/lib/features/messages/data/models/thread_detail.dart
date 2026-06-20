import 'package:equatable/equatable.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';

/// `GET /api/channels/:channelId/messages/:id/thread` response payload.
class ThreadDetail extends Equatable {
  const ThreadDetail({
    required this.rootMessage,
    required this.replies,
    required this.hasMore,
  });

  final MessageModel rootMessage;
  final List<MessageModel> replies;
  final bool hasMore;

  @override
  List<Object?> get props => [rootMessage, replies, hasMore];
}
