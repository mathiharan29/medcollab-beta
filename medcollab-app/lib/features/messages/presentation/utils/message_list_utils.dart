import 'package:medcollab_app/features/messages/data/models/message_model.dart';

/// Builds a channel message list with date separators and sender grouping.
sealed class MessageListItem {
  const MessageListItem();
}

class DateSeparatorItem extends MessageListItem {
  const DateSeparatorItem(this.label);
  final String label;
}

class ChatMessageItem extends MessageListItem {
  const ChatMessageItem({
    required this.message,
    required this.showSender,
    required this.showTimestamp,
    required this.isMine,
  });

  final MessageModel message;
  final bool showSender;
  final bool showTimestamp;
  final bool isMine;
}

List<MessageListItem> buildMessageListItems({
  required List<MessageModel> messages,
  required String currentUserId,
}) {
  if (messages.isEmpty) return const [];

  final items = <MessageListItem>[];
  String? lastDateLabel;
  String? lastSenderId;

  for (final message in messages) {
    final created = message.createdAt?.toLocal();
    final dateLabel = created != null ? _formatDateLabel(created) : null;
    if (dateLabel != null && dateLabel != lastDateLabel) {
      items.add(DateSeparatorItem(dateLabel));
      lastDateLabel = dateLabel;
      lastSenderId = null;
    }

    final isMine = message.sender.id == currentUserId;
    final showSender = !isMine && message.sender.id != lastSenderId;
    items.add(
      ChatMessageItem(
        message: message,
        showSender: showSender,
        showTimestamp: true,
        isMine: isMine,
      ),
    );
    lastSenderId = message.sender.id;
  }

  return items;
}

String _formatDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${date.day}/${date.month}/${date.year}';
}
