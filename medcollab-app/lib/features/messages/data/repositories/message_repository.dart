import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/features/media/data/models/media_upload_result.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

class MessagesPage {
  const MessagesPage({required this.messages, required this.hasMore});

  final List<MessageModel> messages;
  final bool hasMore;
}

class MessageRepository extends BaseRepository {
  MessageRepository({required super.apiClient});

  Future<MessagesPage> getMessages(
    String channelId, {
    String? before,
    int limit = 30,
  }) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.channelMessages(channelId),
        queryParameters: {
          'limit': limit,
          if (before != null) 'before': before,
        },
        parser: (json) => MessagesPage(
          messages: parseNestedList(json, 'messages', MessageModel.fromJson),
          hasMore: json['hasMore'] as bool? ?? false,
        ),
      ),
    );
  }

  Future<MessageModel> sendTextMessage({
    required String channelId,
    required String text,
    List<String> mentions = const [],
    String? replyToId,
  }) {
    return _sendMessage(
      channelId: channelId,
      type: MessageType.text,
      content: MessageContent(text: text),
      mentions: mentions,
      replyToId: replyToId,
    );
  }

  Future<MessageModel> sendMediaMessage({
    required String channelId,
    required MessageType type,
    required MediaUploadResult upload,
    String? caption,
    String? replyToId,
    int? durationMs,
    List<int> waveform = const [],
  }) {
    return _sendMessage(
      channelId: channelId,
      type: type,
      content: MessageContent(
        text: caption,
        mediaUrl: upload.url,
        thumbnailUrl: upload.thumbnailUrl,
        fileName: upload.fileName,
        fileSize: upload.fileSize,
        mimeType: upload.mimeType,
        width: upload.width,
        height: upload.height,
        durationMs: durationMs,
        waveform: waveform,
      ),
      replyToId: replyToId,
    );
  }

  Future<MessageModel> _sendMessage({
    required String channelId,
    required MessageType type,
    required MessageContent content,
    List<String> mentions = const [],
    String? replyToId,
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.channelMessages(channelId),
        data: {
          'type': type.value,
          'content': content.toJson(),
          if (mentions.isNotEmpty) 'mentions': mentions,
          if (replyToId != null && replyToId.isNotEmpty) 'replyToId': replyToId,
        },
        parser: (json) =>
            parseNested(json, 'message', MessageModel.fromJson),
      ),
    );
  }

  Future<MessageModel> editMessage({
    required String channelId,
    required String messageId,
    required String text,
  }) {
    return execute(
      () => apiClient.put(
        ApiEndpoints.messageById(channelId, messageId),
        data: {'content': {'text': text}},
        parser: (json) =>
            parseNested(json, 'message', MessageModel.fromJson),
      ),
    );
  }

  /// [forEveryone]: removes the message (and its thread) from the server for
  /// all members. Otherwise hides it for the current user only.
  Future<void> deleteMessage({
    required String channelId,
    required String messageId,
    bool forEveryone = true,
  }) {
    return executeVoid(
      () => apiClient.delete(
        ApiEndpoints.messageById(channelId, messageId),
        queryParameters: {'scope': forEveryone ? 'everyone' : 'me'},
      ),
    );
  }

  /// "Clear chat": hides every message so far, for the current user only.
  Future<void> clearChat(String channelId) {
    return executeVoid(
      () => apiClient.post('${ApiEndpoints.channelMessages(channelId)}/clear'),
    );
  }

  Future<void> markMessagesRead({
    required String channelId,
    required List<String> messageIds,
  }) {
    return executeVoid(
      () => apiClient.post(
        ApiEndpoints.markChannelRead(channelId),
        data: {'messageIds': messageIds},
      ),
    );
  }

  Future<List<MessageReaction>> toggleReaction({
    required String channelId,
    required String messageId,
    required String emoji,
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.messageReact(channelId, messageId),
        data: {'emoji': emoji},
        parser: (json) {
          final raw = json['reactions'];
          if (raw is! List) return <MessageReaction>[];
          return raw
              .map((e) => asJsonMap(e))
              .whereType<Map<String, dynamic>>()
              .map(MessageReaction.fromJson)
              .toList();
        },
      ),
    );
  }
}
