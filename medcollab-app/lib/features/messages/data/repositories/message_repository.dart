import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

class MessagesPage {
  const MessagesPage({required this.messages, required this.hasMore});

  final List<MessageModel> messages;
  final bool hasMore;
}

class MessageRepository extends BaseRepository {
  MessageRepository({required super.apiClient});

  /// `GET /api/channels/:channelId/messages`
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

  /// `POST /api/channels/:channelId/messages`
  Future<MessageModel> sendMessage({
    required String channelId,
    required String text,
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.channelMessages(channelId),
        data: {
          'type': 'text',
          'content': {'text': text},
        },
        parser: (json) =>
            parseNested(json, 'message', MessageModel.fromJson),
      ),
    );
  }
}
