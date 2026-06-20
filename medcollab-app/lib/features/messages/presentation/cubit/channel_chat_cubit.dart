import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
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
        loadMessages(silent: true);
      }
    });
    if (_socketClient.isConnected) {
      _socketClient.joinChannel(channelId);
    }
    loadMessages();
  }

  final MessageRepository _messageRepository;
  final MediaRepository _mediaRepository;
  final SocketClient _socketClient;
  final String channelId;
  final String currentUserId;

  StreamSubscription<Map<String, dynamic>>? _messageSub;

  Future<void> loadMessages({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(isLoading: true, error: null));
    }
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
      localOnly: true,
    );
    _upsertRootMessage(optimistic);

    emit(state.copyWith(isSending: true, error: null));
    try {
      final message = await _messageRepository.sendTextMessage(
        channelId: channelId,
        text: trimmed,
      );
      _replaceLocalMessage(tempId, message);
      emit(state.copyWith(isSending: false));
    } on AppException catch (e) {
      _markFailed(tempId);
      emit(state.copyWith(isSending: false, error: e.message));
    } catch (_) {
      _markFailed(tempId);
      emit(state.copyWith(isSending: false, error: 'Failed to send message'));
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
      _replaceLocalMessage(tempId, message);
      emit(state.copyWith(isSending: false, isUploading: false));
    } on AppException catch (e) {
      _markFailed(tempId);
      emit(state.copyWith(isSending: false, isUploading: false, error: e.message));
    } catch (_) {
      _markFailed(tempId);
      emit(
        state.copyWith(
          isSending: false,
          isUploading: false,
          error: 'Failed to send attachment',
        ),
      );
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
    final updated = List<MessageModel>.from(state.messages);
    updated.removeWhere(
      (m) =>
          m.id == tempId ||
          m.id == message.id ||
          (m.localOnly &&
              m.sender.id == currentUserId &&
              _messagesMatch(m, message)),
    );
    updated.add(message);
    updated.sort(_compareByCreatedAt);
    emit(state.copyWith(messages: updated));
  }

  void _listenForSocketMessages() {
    _messageSub =
        _socketClient.onMapEvent(SocketEvents.newMessage).listen((data) {
      final message = _parseSocketMessage(data);
      if (message == null) return;

      final msgChannelId = message.channelId.isNotEmpty
          ? message.channelId
          : data['channelId']?.toString() ?? '';
      if (msgChannelId != channelId) return;
      _handleIncomingMessage(message);
    });
  }

  MessageModel? _parseSocketMessage(Map<String, dynamic> data) {
    try {
      return MessageModel.fromJson(data);
    } catch (_) {
      final nested = asJsonMap(data['message']);
      if (nested == null) return null;
      try {
        return MessageModel.fromJson(nested);
      } catch (_) {
        return null;
      }
    }
  }

  void _handleIncomingMessage(MessageModel message) {
    if (message.isThreadReply) {
      _applyThreadReplyToRoot(message);
      return;
    }
    _upsertRootMessage(message, fromSocket: true);
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

  void _upsertRootMessage(MessageModel message, {bool fromSocket = false}) {
    final updated = List<MessageModel>.from(state.messages);

    if (fromSocket && message.sender.id == currentUserId) {
      updated.removeWhere(
        (m) =>
            m.localOnly &&
            m.sender.id == currentUserId &&
            _messagesMatch(m, message),
      );
    }

    final existing = updated.indexWhere((m) => m.id == message.id);
    if (existing >= 0) {
      updated[existing] = message;
    } else {
      updated.add(message);
      updated.sort(_compareByCreatedAt);
    }
    emit(state.copyWith(messages: updated));
  }

  bool _messagesMatch(MessageModel a, MessageModel b) {
    if (a.type != b.type) return false;
    if (a.type == MessageType.text) {
      return a.content.text?.trim() == b.content.text?.trim();
    }
    if (a.type == MessageType.image || a.type == MessageType.document) {
      return a.content.fileName == b.content.fileName &&
          a.content.text == b.content.text;
    }
    return a.displayText == b.displayText;
  }

  int _compareByCreatedAt(MessageModel a, MessageModel b) {
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return at.compareTo(bt);
  }

  @override
  Future<void> close() {
    _connectionSub?.cancel();
    _socketClient.leaveChannel(channelId);
    _messageSub?.cancel();
    return super.close();
  }
}
