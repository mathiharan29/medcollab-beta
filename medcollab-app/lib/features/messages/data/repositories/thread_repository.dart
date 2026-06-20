import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/models/thread_detail.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

/// Thread API — mirrors backend thread routes on `message.controller.js`.
class ThreadRepository extends BaseRepository {
  ThreadRepository({required super.apiClient});

  /// `GET /api/channels/:channelId/messages/:id/thread`
  Future<ThreadDetail> getThread(
    String channelId,
    String rootMessageId, {
    String? before,
    int limit = 50,
  }) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.messageThread(channelId, rootMessageId),
        queryParameters: {
          'limit': limit,
          if (before != null) 'before': before,
        },
        parser: (json) => ThreadDetail(
          rootMessage: parseNested(json, 'rootMessage', MessageModel.fromJson),
          replies: parseNestedList(json, 'replies', MessageModel.fromJson),
          hasMore: json['hasMore'] as bool? ?? false,
        ),
      ),
    );
  }

  /// `POST /api/channels/:channelId/messages/:id/reply`
  Future<MessageModel> sendReply({
    required String channelId,
    required String rootMessageId,
    required String text,
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.messageReply(channelId, rootMessageId),
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
