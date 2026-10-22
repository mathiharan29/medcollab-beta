import 'dart:async';

import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/media/data/models/media_upload_result.dart';
import 'package:medcollab_app/features/media/data/repositories/media_repository.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/data/repositories/thread_repository.dart';
import 'package:medcollab_app/features/messages/data/models/thread_detail.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';

ApiClient isolatedApiClient() => ApiClient(storage: SecureStorageService());

class FakeMessageRepository extends MessageRepository {
  FakeMessageRepository() : super(apiClient: isolatedApiClient());

  Future<MessagesPage> Function()? onGetMessages;
  Future<MessageModel> Function(String text, String? replyToId)? onSendText;
  Future<MessageModel> Function(MessageType type, MediaUploadResult upload, String? caption)? onSendMedia;
  int textSendCount = 0;
  final List<String> sentChannelIds = [];
  int mediaSendCount = 0;

  @override
  Future<MessagesPage> getMessages(String channelId, {String? before, int limit = 30}) async {
    return onGetMessages?.call() ?? const MessagesPage(messages: [], hasMore: false);
  }

  @override
  Future<MessageModel> sendTextMessage({
    required String channelId, required String text,
    List<String> mentions = const [], String? replyToId,
  }) {
    textSendCount++;
    sentChannelIds.add(channelId);
    return onSendText!(text, replyToId);
  }

  @override
  Future<MessageModel> sendMediaMessage({
    required String channelId, required MessageType type,
    required MediaUploadResult upload, String? caption, String? replyToId,
  }) {
    mediaSendCount++;
    return onSendMedia!(type, upload, caption);
  }

  @override
  Future<void> markMessagesRead({required String channelId, required List<String> messageIds}) async {}
}

class FakeMediaRepository extends MediaRepository {
  FakeMediaRepository() : super(apiClient: isolatedApiClient());

  Future<MediaUploadResult> Function()? onUpload;
  int uploadCount = 0;

  @override
  Future<MediaUploadResult> uploadFile({
    required List<int> bytes, required String fileName, required String mimeType,
    String context = 'message', void Function(int sent, int total)? onProgress,
  }) {
    uploadCount++;
    return onUpload!();
  }
}

class FakeThreadRepository extends ThreadRepository {
  FakeThreadRepository() : super(apiClient: isolatedApiClient());

  Future<ThreadDetail> Function()? onGetThread;

  @override
  Future<ThreadDetail> getThread(String channelId, String rootMessageId,
      {String? before, int limit = 50}) => onGetThread!();
}

class FakeSocketClient extends SocketClient {
  final Map<String, StreamController<Map<String, dynamic>>> _events = {};
  final StreamController<bool> _connections = StreamController<bool>.broadcast(sync: true);
  final List<String> joined = [];
  final List<String> left = [];

  @override
  bool get isConnected => false;

  @override
  Stream<bool> get connectionStream => _connections.stream;

  @override
  Stream<Map<String, dynamic>> onMapEvent(String event) =>
      _events.putIfAbsent(event, () => StreamController<Map<String, dynamic>>.broadcast(sync: true)).stream;

  void emitEvent(String event, Map<String, dynamic> payload) => _events[event]?.add(payload);

  void emitConnected() => _connections.add(true);

  @override
  void joinChannel(String channelId) => joined.add(channelId);

  @override
  void leaveChannel(String channelId) => left.add(channelId);

  @override
  void emitTypingStop(String channelId) {}

  Future<void> disposeFake() async {
    for (final controller in _events.values) { await controller.close(); }
    await _connections.close();
  }
}
