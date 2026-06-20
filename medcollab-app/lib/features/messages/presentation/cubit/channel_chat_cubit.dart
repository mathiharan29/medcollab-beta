import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';

part 'channel_chat_state.dart';

class ChannelChatCubit extends Cubit<ChannelChatState> {
  StreamSubscription<bool>? _connectionSub;

  ChannelChatCubit({
    required MessageRepository messageRepository,
    required SocketClient socketClient,
    required this.channelId,
    required this.currentUserId,
  })  : _messageRepository = messageRepository,
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

    emit(state.copyWith(isSending: true, error: null));
    try {
      final message = await _messageRepository.sendMessage(
        channelId: channelId,
        text: trimmed,
      );
      _upsertMessage(message);
      emit(state.copyWith(isSending: false));
    } on AppException catch (e) {
      emit(state.copyWith(isSending: false, error: e.message));
    }
  }

  void _listenForSocketMessages() {
    _messageSub =
        _socketClient.onMapEvent(SocketEvents.newMessage).listen((data) {
      try {
        final message = MessageModel.fromJson(data);
        final msgChannelId =
            message.channelId.isNotEmpty ? message.channelId : channelId;
        if (msgChannelId != channelId) return;
        _upsertMessage(message);
      } catch (_) {
        // Ignore malformed socket payloads.
      }
    });
  }

  void _upsertMessage(MessageModel message) {
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
