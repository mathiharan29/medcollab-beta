import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/state/safe_emit.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/media/data/repositories/media_repository.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/repositories/thread_repository.dart';

part 'thread_state.dart';

class ThreadCubit extends Cubit<ThreadState> with SafeEmit<ThreadState> {
  ThreadCubit({
    required ThreadRepository threadRepository,
    required MediaRepository mediaRepository,
    required SocketClient socketClient,
    required this.channelId,
    required this.rootMessageId,
    required this.currentUserId,
    MessageModel? initialRoot,
  })  : _threadRepository = threadRepository,
        _mediaRepository = mediaRepository,
        _socketClient = socketClient,
        super(ThreadState(rootMessage: initialRoot)) {
    if (_socketClient.isConnected) {
      _socketClient.joinChannel(channelId);
    }
    _listenForSocketReplies();
    _listenForTyping();
    _connectionSub = _socketClient.connectionStream.listen((connected) {
      if (connected) {
        _socketClient.joinChannel(channelId);
        loadThread(silent: true);
      }
    });
    loadThread();
  }

  final ThreadRepository _threadRepository;
  final MediaRepository _mediaRepository;
  final SocketClient _socketClient;
  final String channelId;
  final String rootMessageId;
  final String currentUserId;

  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _stoppedTypingSub;

  final Map<String, String> _typingUsers = {};
  final Set<String> _seenReplyIds = {};

  Future<void> loadThread({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(isLoading: true, error: null));
    }
    try {
      final detail = await _threadRepository.getThread(
        channelId,
        rootMessageId,
      );
      for (final r in detail.replies) {
        if (r.id.isNotEmpty) _seenReplyIds.add(r.id);
      }
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

  // Replies show instantly and go out in order in the background; typing is
  // never blocked while one is in flight.
  Future<void> _sendChain = Future.value();
  int _replySeq = 0;

  Future<void> sendReply(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final tempId =
        'local-${DateTime.now().millisecondsSinceEpoch}-${_replySeq++}';
    _upsertReply(MessageModel(
      id: tempId,
      channelId: channelId,
      sender: UserModel(id: currentUserId),
      content: MessageContent(text: trimmed),
      threadId: rootMessageId,
      createdAt: DateTime.now(),
      localOnly: true,
    ));
    emit(state.copyWith(error: null));

    final run = _sendChain.then((_) async {
      try {
        final reply = await _threadRepository.sendReply(
          channelId: channelId,
          rootMessageId: rootMessageId,
          text: trimmed,
        );
        if (reply.id.isNotEmpty) _seenReplyIds.add(reply.id);
        _replaceLocalReply(tempId, reply);
      } on AppException catch (e) {
        _dropLocalReply(tempId);
        emit(state.copyWith(error: e.message));
      } catch (_) {
        _dropLocalReply(tempId);
        emit(state.copyWith(error: 'Failed to send reply'));
      }
    });
    _sendChain = run.catchError((Object _) {});
    await run;
  }

  void _dropLocalReply(String tempId) {
    emit(state.copyWith(
      replies: state.replies.where((r) => r.id != tempId).toList(),
    ));
  }

  Future<void> sendAttachment({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    if (bytes.length > 50 * 1024 * 1024) {
      emit(state.copyWith(error: 'That file is over 50 MB'));
      return;
    }

    final tempId =
        'local-${DateTime.now().millisecondsSinceEpoch}-${_replySeq++}';
    final mediaType = MessageType.forMime(mimeType);
    final optimistic = MessageModel(
      id: tempId,
      channelId: channelId,
      sender: UserModel(id: currentUserId),
      type: mediaType,
      content: MessageContent(fileName: fileName, mimeType: mimeType),
      threadId: rootMessageId,
      createdAt: DateTime.now(),
      localOnly: true,
    );
    _upsertReply(optimistic);

    // Uploads run in parallel with typing and text replies (beta feedback).
    _uploading++;
    emit(state.copyWith(isUploading: true, error: null));
    String? failure;
    try {
      final upload = await _mediaRepository.uploadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      final reply = await _threadRepository.sendReplyMedia(
        channelId: channelId,
        rootMessageId: rootMessageId,
        type: mediaType,
        upload: upload,
      );
      if (reply.id.isNotEmpty) _seenReplyIds.add(reply.id);
      _replaceLocalReply(tempId, reply);
    } on AppException catch (e) {
      failure = e.message;
    } catch (_) {
      failure = 'Failed to send attachment';
    }
    if (failure != null) _dropLocalReply(tempId);
    _uploading--;
    emit(state.copyWith(
      isUploading: _uploading > 0,
      error: failure ?? state.error,
    ));
  }

  int _uploading = 0;

  void _replaceLocalReply(String tempId, MessageModel reply) {
    final updated = List<MessageModel>.from(state.replies);
    // The live echo of our own reply may already be in the list.
    updated.removeWhere((r) => r.id == tempId || r.id == reply.id);
    updated.add(reply);
    updated.sort((a, b) {
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    emit(state.copyWith(replies: updated));
  }

  void _listenForSocketReplies() {
    _messageSub =
        _socketClient.onMapEvent(SocketEvents.newMessage).listen((data) {
      final message = _parseSocketMessage(data);
      if (message == null) return;
      if (message.threadId != rootMessageId) return;
      if (message.channelId.isNotEmpty && message.channelId != channelId) {
        return;
      }
      if (message.id.isNotEmpty && !_seenReplyIds.add(message.id)) return;
      _upsertReply(message);
    });

    // Live edits / deletes of replies (and the root) in an open thread.
    _updatedSub =
        _socketClient.onMapEvent(SocketEvents.messageUpdated).listen((data) {
      final id = data['messageId']?.toString() ?? data['_id']?.toString();
      if (id == null || id.isEmpty) return;
      final contentJson = asJsonMap(data['content']);
      MessageModel apply(MessageModel m) => m.copyWith(
            content: contentJson != null
                ? MessageContent.fromJson(contentJson)
                : m.content,
            isEdited: data['isEdited'] == true || m.isEdited,
          );
      if (state.rootMessage?.id == id) {
        emit(state.copyWith(rootMessage: apply(state.rootMessage!)));
        return;
      }
      final index = state.replies.indexWhere((r) => r.id == id);
      if (index < 0) return;
      final updated = List<MessageModel>.from(state.replies);
      updated[index] = apply(updated[index]);
      emit(state.copyWith(replies: updated));
    });
    _deletedSub =
        _socketClient.onMapEvent(SocketEvents.messageDeleted).listen((data) {
      final id = data['messageId']?.toString() ?? '';
      if (id.isNotEmpty && id == rootMessageId) {
        // The whole thread was deleted for everyone.
        emit(state.copyWith(
          replies: const [],
          error: 'This message was deleted',
        ));
        return;
      }
      final index = state.replies.indexWhere((r) => r.id == id);
      if (index < 0) return;
      final updated = List<MessageModel>.from(state.replies)..removeAt(index);
      emit(state.copyWith(replies: updated));
    });
  }

  StreamSubscription<Map<String, dynamic>>? _updatedSub;
  StreamSubscription<Map<String, dynamic>>? _deletedSub;

  void _listenForTyping() {
    _typingSub =
        _socketClient.onMapEvent(SocketEvents.userTyping).listen((data) {
      final msgChannelId = data['channelId']?.toString() ?? '';
      if (msgChannelId != channelId) return;
      final userId = data['userId']?.toString() ?? '';
      if (userId.isEmpty || userId == currentUserId) return;
      final userName = data['userName']?.toString() ?? 'Someone';
      _typingUsers[userId] = userName;
      emit(state.copyWith(typingUserNames: _typingUsers.values.toList()));
    });

    _stoppedTypingSub = _socketClient
        .onMapEvent(SocketEvents.userStoppedTyping)
        .listen((data) {
      final msgChannelId = data['channelId']?.toString() ?? '';
      if (msgChannelId != channelId) return;
      final userId = data['userId']?.toString() ?? '';
      if (userId.isEmpty) return;
      _typingUsers.remove(userId);
      emit(state.copyWith(typingUserNames: _typingUsers.values.toList()));
    });
  }

  void emitTypingStart() {
    _socketClient.emitTypingStart(channelId);
  }

  void emitTypingStop() {
    _socketClient.emitTypingStop(channelId);
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

  void _upsertReply(MessageModel reply) {
    if (reply.id.isNotEmpty) _seenReplyIds.add(reply.id);
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
    emitTypingStop();
    _connectionSub?.cancel();
    _messageSub?.cancel();
    _updatedSub?.cancel();
    _deletedSub?.cancel();
    _typingSub?.cancel();
    _stoppedTypingSub?.cancel();
    return super.close();
  }
}
