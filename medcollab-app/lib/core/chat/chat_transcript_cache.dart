import 'package:medcollab_app/features/messages/data/models/message_model.dart';

/// Last fetched transcript per channel so reopening a chat paints immediately.
class ChatTranscriptCache {
  ChatTranscriptCache._();

  static final Map<String, List<MessageModel>> _messages = {};
  static final Map<String, bool> _hasMore = {};

  static List<MessageModel>? messagesFor(String channelId) {
    final cached = _messages[channelId];
    if (cached == null || cached.isEmpty) return null;
    return cached;
  }

  static bool hasMoreFor(String channelId) => _hasMore[channelId] ?? false;

  static void save(
    String channelId,
    List<MessageModel> messages, {
    required bool hasMore,
  }) {
    if (channelId.isEmpty) return;
    _messages[channelId] = List<MessageModel>.from(messages);
    _hasMore[channelId] = hasMore;
  }

  static void clearAll() {
    _messages.clear();
    _hasMore.clear();
  }
}
