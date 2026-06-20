import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/repositories/thread_repository.dart';

part 'thread_state.dart';

class ThreadCubit extends Cubit<ThreadState> {
  ThreadCubit({
    required ThreadRepository threadRepository,
    required SocketClient socketClient,
    required this.channelId,
    required this.rootMessageId,
    MessageModel? initialRoot,
  })  : _threadRepository = threadRepository,
        _socketClient = socketClient,
        super(ThreadState(rootMessage: initialRoot)) {
    _listenForSocketReplies();
    loadThread();
  }

  final ThreadRepository _threadRepository;
  final SocketClient _socketClient;
  final String channelId;
  final String rootMessageId;

  StreamSubscription<Map<String, dynamic>>? _messageSub;

  Future<void> loadThread() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final detail = await _threadRepository.getThread(
        channelId,
        rootMessageId,
      );
      emit(
        state.copyWith(
          rootMessage: detail.rootMessage,
          replies: detail.replies,
          hasMore: detail.hasMore,
          isLoading: false,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    }
  }

  Future<void> sendReply(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    emit(state.copyWith(isSending: true, error: null));
    try {
      final reply = await _threadRepository.sendReply(
        channelId: channelId,
        rootMessageId: rootMessageId,
        text: trimmed,
      );
      _upsertReply(reply);
      emit(state.copyWith(isSending: false));
    } on AppException catch (e) {
      emit(state.copyWith(isSending: false, error: e.message));
    }
  }

  void _listenForSocketReplies() {
    _messageSub =
        _socketClient.onMapEvent(SocketEvents.newMessage).listen((data) {
      try {
        final message = MessageModel.fromJson(data);
        if (message.threadId != rootMessageId) return;
        if (message.channelId.isNotEmpty && message.channelId != channelId) {
          return;
        }
        _upsertReply(message);
      } catch (_) {
        // Ignore malformed socket payloads.
      }
    });
  }

  void _upsertReply(MessageModel reply) {
    final existing = state.replies.indexWhere((r) => r.id == reply.id);
    final updated = List<MessageModel>.from(state.replies);
    if (existing >= 0) {
      updated[existing] = reply;
    } else {
      updated.add(reply);
      updated.sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return at.compareTo(bt);
      });
    }
    emit(state.copyWith(replies: updated));
  }

  @override
  Future<void> close() {
    _messageSub?.cancel();
    return super.close();
  }
}
