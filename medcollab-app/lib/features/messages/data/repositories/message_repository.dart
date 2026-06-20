import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
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
  }) {
    return _sendMessage(
      channelId: channelId,
      type: MessageType.text,
      content: MessageContent(text: text),
    );
  }

  Future<MessageModel> sendMediaMessage({
    required String channelId,
    required MessageType type,
    required MediaUploadResult upload,
    String? caption,
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
      ),
    );
  }

  Future<MessageModel> _sendMessage({
    required String channelId,
    required MessageType type,
    required MessageContent content,
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.channelMessages(channelId),
        data: {
          'type': type.value,
          'content': content.toJson(),
        },
        parser: (json) =>
            parseNested(json, 'message', MessageModel.fromJson),
      ),
    );
  }
}
