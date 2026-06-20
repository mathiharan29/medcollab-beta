import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/media/data/repositories/media_repository.dart';
import 'package:medcollab_app/features/messages/data/models/message_delivery_state.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/models/thread_reply_preview.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';

part 'channel_chat_state.dart';

class ChannelChatCubit extends Cubit<ChannelChatState> {
  StreamSubscription<bool>? _connectionSub;

  ChannelChatCubit({
    required MessageRepository messageRepository,
    required MediaRepository mediaRepository,
    required SocketClient socketClient,
    required this.channelId,
    required this.currentUserId,
  })  : _messageRepository = messageRepository,
        _mediaRepository = mediaRepository,
        _socketClient = socketClient,
        super(const ChannelChatState()) {
    _listenForSocketMessages();
    _connectionSub = _socketClient.connectionStream.listen((connected) {
      if (connected) {
        _socketClient.joinChannel(channelId);
      }
    });
    loadMessages();
  }

  final MessageRepository _messageRepository;
  final MediaRepository _mediaRepository;
  final SocketClient _socketClient;
  final String channelId;
  final String currentUserId;

  StreamSubscription<Map<String, dynamic>>? _messageSub;

  Future<void> loadMessages() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final page = await _messageRepository.getMessages(channelId);
      emit(
        state.copyWith(
          messages: page.messages,
          hasMore: page.hasMore,
          isLoading: false,
        ),
      );
      _socketClient.joinChannel(channelId);
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final tempId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: tempId,
      channelId: channelId,
      sender: UserModel(id: currentUserId),
      type: MessageType.text,
      content: MessageContent(text: trimmed),
      createdAt: DateTime.now(),
      deliveryState: MessageDeliveryState.sending,
      localOnly: true,
    );
    _upsertRootMessage(optimistic);

    emit(state.copyWith(isSending: true, error: null));
    try {
      final message = await _messageRepository.sendTextMessage(
        channelId: channelId,
        text: trimmed,
      );
      _replaceLocalMessage(tempId, message.copyWith(deliveryState: MessageDeliveryState.sent));
      emit(state.copyWith(isSending: false));
    } on AppException catch (e) {
      _markFailed(tempId);
      emit(state.copyWith(isSending: false, error: e.message));
    }
  }

  Future<void> sendAttachment({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? caption,
  }) async {
    if (state.isSending) return;

    final tempId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final isImage = mimeType.startsWith('image/');
    final optimistic = MessageModel(
      id: tempId,
      channelId: channelId,
      sender: UserModel(id: currentUserId),
      type: isImage ? MessageType.image : MessageType.document,
      content: MessageContent(
        text: caption,
        fileName: fileName,
        mimeType: mimeType,
      ),
      createdAt: DateTime.now(),
      deliveryState: MessageDeliveryState.sending,
      localOnly: true,
    );
    _upsertRootMessage(optimistic);

    emit(state.copyWith(isSending: true, error: null, isUploading: true));
    try {
      final upload = await _mediaRepository.uploadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      final message = await _messageRepository.sendMediaMessage(
        channelId: channelId,
        type: isImage ? MessageType.image : MessageType.document,
        upload: upload,
        caption: caption,
      );
      _replaceLocalMessage(
        tempId,
        message.copyWith(deliveryState: MessageDeliveryState.sent),
      );
      emit(state.copyWith(isSending: false, isUploading: false));
    } on AppException catch (e) {
      _markFailed(tempId);
      emit(state.copyWith(isSending: false, isUploading: false, error: e.message));
    }
  }

  void _markFailed(String tempId) {
    final index = state.messages.indexWhere((m) => m.id == tempId);
    if (index < 0) return;
    final updated = List<MessageModel>.from(state.messages);
    updated[index] = updated[index].copyWith(
      deliveryState: MessageDeliveryState.failed,
    );
    emit(state.copyWith(messages: updated));
  }

  void _replaceLocalMessage(String tempId, MessageModel message) {
    final index = state.messages.indexWhere((m) => m.id == tempId);
    final updated = List<MessageModel>.from(state.messages);
    if (index >= 0) {
      updated[index] = message;
    } else {
      updated.add(message);
    }
    updated.sort((a, b) {
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    emit(state.copyWith(messages: updated));
  }

  void _listenForSocketMessages() {
    _messageSub =
        _socketClient.onMapEvent(SocketEvents.newMessage).listen((data) {
      try {
        final message = MessageModel.fromJson(data);
        final msgChannelId =
            message.channelId.isNotEmpty ? message.channelId : channelId;
        if (msgChannelId != channelId) return;
        _handleIncomingMessage(message);
      } catch (_) {
        // Ignore malformed socket payloads.
      }
    });
  }

  void _handleIncomingMessage(MessageModel message) {
    if (message.isThreadReply) {
      _applyThreadReplyToRoot(message);
      return;
    }
    _upsertRootMessage(message);
  }

  void _applyThreadReplyToRoot(MessageModel reply) {
    final rootId = reply.threadId;
    if (rootId == null || rootId.isEmpty) return;

    final index = state.messages.indexWhere((m) => m.id == rootId);
    if (index < 0) return;

    final root = state.messages[index];
    final updated = List<MessageModel>.from(state.messages);
    updated[index] = root.copyWith(
      replyCount: root.replyCount + 1,
      lastReply: ThreadReplyPreview(
        senderName: reply.sender.displayName,
        text: _truncate(reply.displayText, 100),
        sentAt: reply.createdAt,
      ),
    );
    emit(state.copyWith(messages: updated));
  }

  String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}…';
  }

  void _upsertRootMessage(MessageModel message) {
    final existing = state.messages.indexWhere((m) => m.id == message.id);
    final updated = List<MessageModel>.from(state.messages);
    if (existing >= 0) {
      updated[existing] = message;
    } else {
      updated.add(message);
      updated.sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return at.compareTo(bt);
      });
    }
    emit(state.copyWith(messages: updated));
  }

  @override
  Future<void> close() {
    _connectionSub?.cancel();
    _socketClient.leaveChannel(channelId);
    _messageSub?.cancel();
    return super.close();
  }
}
