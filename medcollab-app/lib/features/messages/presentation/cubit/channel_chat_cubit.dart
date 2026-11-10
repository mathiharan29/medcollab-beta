import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/state/safe_emit.dart';
import 'package:medcollab_app/core/chat/active_chat_tracker.dart';
import 'package:medcollab_app/core/chat/chat_transcript_cache.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/media/data/repositories/media_repository.dart';
import 'package:medcollab_app/features/members/data/repositories/member_repository.dart';
import 'package:medcollab_app/features/messages/data/models/message_delivery_state.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_reply_to.dart';
import 'package:medcollab_app/features/messages/data/models/thread_reply_preview.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';

part 'channel_chat_state.dart';

class ChannelChatCubit extends Cubit<ChannelChatState> with SafeEmit<ChannelChatState> {
  StreamSubscription<bool>? _connectionSub;

  /// Dedupe socket fan-out (channel room + user room).
  final Set<String> _seenSocketMessageIds = {};

  ChannelChatCubit({
    required MessageRepository messageRepository,
    required MediaRepository mediaRepository,
    required SocketClient socketClient,
    required this.channelId,
    required this.currentUserId,
    this.spaceId,
    MemberRepository? memberRepository,
    NotificationRepository? notificationRepository,
    void Function(int unreadCount)? onChannelAlertsCleared,
    this.readReceiptsEnabled,
  })  : _messageRepository = messageRepository,
        _mediaRepository = mediaRepository,
        _socketClient = socketClient,
        _memberRepository = memberRepository,
        _notificationRepository = notificationRepository,
        _onChannelAlertsCleared = onChannelAlertsCleared,
        super(
          ChannelChatState(
            messages: ChatTranscriptCache.messagesFor(channelId) ?? const [],
            hasMore: ChatTranscriptCache.hasMoreFor(channelId),
            isLoading: (ChatTranscriptCache.messagesFor(channelId) ?? const [])
                .isEmpty,
          ),
        ) {
    _listenForSocketMessages();
    _listenForSocketUpdates();
    _listenForTyping();
    _listenForInChatNotificationFallback();
    _listenForMembershipRevocation();
    _connectionSub = _socketClient.connectionStream.listen((connected) {
      if (connected) {
        _socketClient.joinChannel(channelId);
        loadMessages(silent: true);
      }
    });
    if (_socketClient.isConnected) {
      _socketClient.joinChannel(channelId);
    }
    ActiveChatTracker.instance.enter(channelId);
    loadMessages(silent: state.messages.isNotEmpty);
    _markChannelNotificationsRead();
    unawaited(_checkSpaceMembership());
  }

  final MessageRepository _messageRepository;
  final MediaRepository _mediaRepository;
  final SocketClient _socketClient;
  final MemberRepository? _memberRepository;
  final NotificationRepository? _notificationRepository;
  final void Function(int unreadCount)? _onChannelAlertsCleared;
  final String channelId;
  final String currentUserId;
  final String? spaceId;

  /// When returns false, DM read receipts are neither written nor used by this cubit for mark-read.
  final bool Function()? readReceiptsEnabled;

  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _messageUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _messageDeletedSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _stoppedTypingSub;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;
  StreamSubscription<Map<String, dynamic>>? _memberLeftSub;

  final Map<String, String> _typingUsers = {};
  final Map<String, Timer> _typingExpiry = {};

  /// Overridable in unit tests so expiry can be asserted without long pumps.
  @visibleForTesting
  static Duration typingExpiryDuration = const Duration(seconds: 5);

  Future<void> _markChannelNotificationsRead() async {
    final repo = _notificationRepository;
    if (repo == null) return;
    try {
      final count = await repo.markReadByChannel(channelId);
      _onChannelAlertsCleared?.call(count);
    } catch (_) {
      /* non-fatal — chat still works */
    }
  }

  Future<void> loadMessages({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) {
      emit(state.copyWith(isLoading: true, error: null));
    }
    try {
      final page = await _messageRepository.getMessages(channelId);
      if (isClosed) return;
      emit(
        state.copyWith(
          messages: page.messages,
          hasMore: page.hasMore,
          isLoading: false,
        ),
      );
      ChatTranscriptCache.save(
        channelId,
        page.messages,
        hasMore: page.hasMore,
      );
      _socketClient.joinChannel(channelId);
      unawaited(_markMessagesRead(page.messages));
      unawaited(_markChannelNotificationsRead());
    } on AppException catch (e) {
      if (isClosed) return;
      _markReadOnlyForAccessError(e);
      emit(state.copyWith(isLoading: false, error: e.message));
    }
  }

  Future<void> _checkSpaceMembership() async {
    final sid = spaceId;
    final repository = _memberRepository;
    if (sid == null || sid.isEmpty || repository == null) return;
    try {
      final members = await repository.getSpaceMembers(sid);
      if (!members.any((member) => member.user.id == currentUserId)) {
        _markReadOnly('You have been removed from this space');
      }
    } on AppException catch (error) {
      _markReadOnlyForAccessError(error);
    }
  }

  void _listenForMembershipRevocation() {
    final sid = spaceId;
    if (sid == null || sid.isEmpty) return;
    _memberLeftSub =
        _socketClient.onMapEvent(SocketEvents.spaceMemberLeft).listen((data) {
      final eventSpaceId = data['spaceId']?.toString() ?? '';
      final eventUserId = data['userId']?.toString() ?? '';
      if (eventSpaceId != sid || eventUserId != currentUserId) return;
      final reason = data['reason']?.toString() ?? 'removed';
      if (reason == 'left') {
        _markReadOnly('You left this space');
        return;
      }
      final byName = (data['byUserName']?.toString() ?? '').trim();
      _markReadOnly(
        byName.isEmpty
            ? 'You have been removed from this space'
            : 'Removed by $byName',
      );
    });
  }

  void _markReadOnlyForAccessError(AppException error) {
    final message = error.message.toLowerCase();
    if (message.contains('forbidden') ||
        message.contains('not a member') ||
        message.contains('no longer') ||
        message.contains('removed') ||
        message.contains('access denied') ||
        message.contains('access to this')) {
      _markReadOnly('You have been removed from this space');
    }
  }

  void _markReadOnly(String reason) {
    if (state.isReadOnly) return;
    emit(state.copyWith(
      readOnlyReason: reason,
      isSending: false,
      isUploading: false,
      clearPendingReply: true,
    ));
  }

  Future<void> _markMessagesRead(List<MessageModel> messages) async {
    final prefsEnabled = readReceiptsEnabled?.call() ?? true;
    if (!prefsEnabled) return;
    final ids = messages
        .where(
            (m) => !m.localOnly && !m.isDeleted && m.sender.id != currentUserId)
        .map((m) => m.id)
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;
    try {
      await _messageRepository.markMessagesRead(
        channelId: channelId,
        messageIds: ids,
      );
    } catch (_) {
      /* non-fatal */
    }
  }

  /// If `new_message` is missed (room race), inbox events still refresh the open chat.
  void _listenForInChatNotificationFallback() {
    _notificationSub =
        _socketClient.onMapEvent(SocketEvents.newNotification).listen((data) {
      final meta = asJsonMap(data['metadata']);
      final cid =
          meta?['channelId']?.toString() ?? data['channelId']?.toString() ?? '';
      if (cid.isEmpty || cid == 'null' || cid != channelId) return;
      unawaited(loadMessages(silent: true));
      unawaited(_markChannelNotificationsRead());
    });
  }

  // Sends go out one after another in the background so the composer never
  // blocks (typing / sending again while one is in flight, like WhatsApp)
  // and the server keeps the order they were written in.
  Future<void> _sendChain = Future.value();
  int _inFlight = 0;
  int _tempSeq = 0;

  String _nextTempId() =>
      'local-${DateTime.now().millisecondsSinceEpoch}-${_tempSeq++}';

  Future<void> _enqueue(Future<void> Function() job) {
    _inFlight++;
    emit(state.copyWith(isSending: true, error: null));
    final run = _sendChain.then((_) => job()).whenComplete(() {
      _inFlight--;
      // copyWith clears error unless passed: keep a send failure visible.
      if (_inFlight == 0) {
        emit(state.copyWith(isSending: false, error: state.error));
      }
    });
    _sendChain = run.catchError((Object _) {});
    return run;
  }

  Future<void> sendMessage(String text,
      {List<String> mentions = const []}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isReadOnly) return;

    final replySource = state.pendingReply;
    final replyTo = replySource == null || replySource.localOnly
        ? null
        : MessageReplyTo.fromMessage(
            messageId: replySource.id,
            senderId: replySource.sender.id,
            senderName: replySource.sender.displayName,
            type: replySource.type,
            text: replySource.displayText,
          );

    final tempId = _nextTempId();
    final optimistic = MessageModel(
      id: tempId,
      channelId: channelId,
      sender: UserModel(id: currentUserId),
      type: MessageType.text,
      content: MessageContent(text: trimmed),
      replyTo: replyTo,
      createdAt: DateTime.now(),
      localOnly: true,
      deliveryState: MessageDeliveryState.sending,
    );
    // Shown instantly; the network round trip happens in the background.
    _upsertRootMessage(optimistic);
    emit(state.copyWith(clearPendingReply: true));
    await _enqueue(() async {
      try {
        final message = await _messageRepository.sendTextMessage(
          channelId: channelId,
          text: trimmed,
          mentions: mentions,
          replyToId: replyTo?.messageId,
        );
        _replaceLocalMessage(tempId, message);
      } on AppException catch (e) {
        _markFailed(tempId);
        _markReadOnlyForAccessError(e);
        emit(state.copyWith(error: e.message));
      } catch (_) {
        _markFailed(tempId);
        emit(state.copyWith(error: 'Failed to send message'));
      }
    });
  }

  Future<void> retryFailedMessage(String messageId) async {
    if (state.isReadOnly) return;
    final failed = state.messages
        .where((message) =>
            message.id == messageId &&
            message.deliveryState == MessageDeliveryState.failed)
        .firstOrNull;
    if (failed == null || failed.type != MessageType.text) return;
    final remaining =
        state.messages.where((message) => message.id != messageId).toList();
    emit(state.copyWith(messages: remaining, error: null));
    await sendMessage(failed.content.text ?? '');
  }

  void setPendingReply(MessageModel message) {
    if (message.localOnly || message.isDeleted) return;
    emit(state.copyWith(pendingReply: message));
  }

  void clearPendingReply() {
    if (state.pendingReply == null) return;
    emit(state.copyWith(clearPendingReply: true));
  }

  Future<void> sendAttachment({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? caption,
    // Voice note (REQ 12).
    int? durationMs,
    List<int> waveform = const [],
  }) async {
    if (state.isReadOnly) return;
    if (bytes.length > 50 * 1024 * 1024) {
      emit(state.copyWith(error: 'That file is over 50 MB'));
      return;
    }

    final replySource = state.pendingReply;
    final replyTo = replySource == null || replySource.localOnly
        ? null
        : MessageReplyTo.fromMessage(
            messageId: replySource.id,
            senderId: replySource.sender.id,
            senderName: replySource.sender.displayName,
            type: replySource.type,
            text: replySource.displayText,
          );

    final tempId = _nextTempId();
    final mediaType = MessageType.forMime(mimeType);
    final optimistic = MessageModel(
      id: tempId,
      channelId: channelId,
      sender: UserModel(id: currentUserId),
      type: mediaType,
      content: MessageContent(
        text: caption,
        fileName: fileName,
        mimeType: mimeType,
        durationMs: durationMs,
        waveform: waveform,
      ),
      replyTo: replyTo,
      createdAt: DateTime.now(),
      localOnly: true,
      deliveryState: MessageDeliveryState.sending,
    );
    final localMedia = Map<String, List<int>>.from(state.localMediaByMessageId)
      ..[tempId] = bytes;
    emit(
      state.copyWith(
        localMediaByMessageId: localMedia,
        clearPendingReply: true,
      ),
    );
    _upsertRootMessage(optimistic);
    // Upload starts right away and never blocks typing or other sends;
    // only the final "post message" step joins the ordered send queue.
    _uploading++;
    emit(state.copyWith(error: null, isUploading: true));
    void doneUploading() {
      _uploading--;
      if (_uploading == 0) {
        emit(state.copyWith(isUploading: false, error: state.error));
      }
    }

    try {
      final upload = await _mediaRepository.uploadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      doneUploading();
      await _enqueue(() async {
        try {
          final message = await _messageRepository.sendMediaMessage(
            channelId: channelId,
            type: mediaType,
            upload: upload,
            caption: caption,
            replyToId: replyTo?.messageId,
            durationMs: durationMs,
            waveform: waveform,
          );
          _replaceLocalMessage(tempId, message);
        } on AppException catch (e) {
          _markFailed(tempId);
          _markReadOnlyForAccessError(e);
          emit(state.copyWith(error: e.message));
        } catch (_) {
          _markFailed(tempId);
          emit(state.copyWith(error: 'Failed to send attachment'));
        }
      });
    } on AppException catch (e) {
      doneUploading();
      _markFailed(tempId);
      _markReadOnlyForAccessError(e);
      emit(state.copyWith(error: e.message));
    } catch (_) {
      doneUploading();
      _markFailed(tempId);
      emit(state.copyWith(error: 'Failed to send attachment'));
    }
  }

  int _uploading = 0;

  Future<void> editMessage(String messageId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      final updated = await _messageRepository.editMessage(
        channelId: channelId,
        messageId: messageId,
        text: trimmed,
      );
      _upsertRootMessage(updated);
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  /// WhatsApp-style delete. [forEveryone] removes it from the server for all
  /// members; otherwise it is hidden for this user only. Either way it
  /// leaves the timeline immediately and comes back only if the call fails.
  Future<void> deleteMessage(String messageId, {bool forEveryone = true}) async {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final before = state.messages;
    emit(state.copyWith(
      messages: before.where((m) => m.id != messageId).toList(),
    ));
    try {
      await _messageRepository.deleteMessage(
        channelId: channelId,
        messageId: messageId,
        forEveryone: forEveryone,
      );
    } on AppException catch (e) {
      // Restore, keeping anything that arrived meanwhile.
      final current = state.messages;
      final restored = List<MessageModel>.from(current)..add(before[index]);
      restored.sort(_byCreatedAt);
      emit(state.copyWith(messages: restored, error: e.message));
    }
  }

  /// "Clear chat" (this user only). Messages still sending stay visible.
  Future<bool> clearChat() async {
    final before = state.messages;
    emit(state.copyWith(
      messages: before.where((m) => m.localOnly).toList(),
      hasMore: false,
    ));
    try {
      await _messageRepository.clearChat(channelId);
      return true;
    } on AppException catch (e) {
      emit(state.copyWith(messages: before, error: e.message));
      return false;
    }
  }

  static int _byCreatedAt(MessageModel a, MessageModel b) {
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return at.compareTo(bt);
  }

  void _listenForTyping() {
    _typingSub =
        _socketClient.onMapEvent(SocketEvents.userTyping).listen((data) {
      final msgChannelId = data['channelId']?.toString() ?? '';
      if (msgChannelId != channelId) return;
      final userId = data['userId']?.toString() ?? '';
      if (userId.isEmpty || userId == currentUserId) return;
      final userName = data['userName']?.toString() ?? 'Someone';
      _typingUsers[userId] = userName;
      _typingExpiry[userId]?.cancel();
      _typingExpiry[userId] = Timer(typingExpiryDuration, () {
        if (isClosed) return;
        _typingUsers.remove(userId);
        _typingExpiry.remove(userId);
        emit(state.copyWith(typingUserNames: _typingUsers.values.toList()));
      });
      emit(state.copyWith(typingUserNames: _typingUsers.values.toList()));
    });

    _stoppedTypingSub =
        _socketClient.onMapEvent(SocketEvents.userStoppedTyping).listen((data) {
      final msgChannelId = data['channelId']?.toString() ?? '';
      if (msgChannelId != channelId) return;
      final userId = data['userId']?.toString() ?? '';
      if (userId.isEmpty) return;
      _typingExpiry[userId]?.cancel();
      _typingExpiry.remove(userId);
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

  void _listenForSocketUpdates() {
    _messageUpdatedSub =
        _socketClient.onMapEvent(SocketEvents.messageUpdated).listen((data) {
      final messageId =
          data['messageId']?.toString() ?? data['_id']?.toString() ?? '';
      final reactionsRaw = data['reactions'];
      if (messageId.isNotEmpty && reactionsRaw is List) {
        final reactions = reactionsRaw
            .map(asJsonMap)
            .whereType<Map<String, dynamic>>()
            .map(MessageReaction.fromJson)
            .toList();
        final index = state.messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          final updated = List<MessageModel>.from(state.messages);
          updated[index] = updated[index].copyWith(reactions: reactions);
          emit(state.copyWith(messages: updated));
        }
        return;
      }

      // Edits arrive as a partial update { messageId, content, isEdited }:
      // merge them into the message we already show. Parsing them as a full
      // message created a stray "null" row and the edit never appeared.
      if (data['_id'] == null && data['id'] == null) {
        if (messageId.isEmpty) return;
        final index = state.messages.indexWhere((m) => m.id == messageId);
        if (index < 0) return;
        final contentJson = asJsonMap(data['content']);
        final updated = List<MessageModel>.from(state.messages);
        updated[index] = updated[index].copyWith(
          content: contentJson != null
              ? MessageContent.fromJson(contentJson)
              : updated[index].content,
          isEdited: data['isEdited'] == true || updated[index].isEdited,
          // A thread reply deleted for everyone lowers the root's count.
          replyCount: (data['replyCount'] as num?)?.toInt(),
        );
        emit(state.copyWith(messages: updated));
        return;
      }

      final message = _parseSocketMessage(data);
      if (message == null) return;
      final msgChannelId = message.channelId.isNotEmpty
          ? message.channelId
          : data['channelId']?.toString() ?? '';
      if (msgChannelId.isNotEmpty && msgChannelId != channelId) return;
      if (message.isThreadReply) {
        // A full message_updated for a reply is not a *new* reply: don't
        // bump the count (only new_message does).
        return;
      }
      _upsertRootMessage(message);
    });

    _messageDeletedSub =
        _socketClient.onMapEvent(SocketEvents.messageDeleted).listen((data) {
      final messageId =
          data['messageId']?.toString() ?? data['_id']?.toString() ?? '';
      if (messageId.isEmpty) return;
      final index = state.messages.indexWhere((m) => m.id == messageId);
      if (index < 0) {
        // Not in the main timeline (e.g. a thread reply, or another chat —
        // deletes also reach members' personal rooms). Never turn the
        // payload into a row.
        return;
      }
      // Deleted for everyone = gone from the server, so gone from view
      // (matches what a reload shows).
      emit(state.copyWith(
        messages: state.messages.where((m) => m.id != messageId).toList(),
      ));
    });
  }

  void _markFailed(String tempId) {
    final index = state.messages.indexWhere((m) => m.id == tempId);
    if (index < 0) return;
    final updated = List<MessageModel>.from(state.messages);
    updated[index] = updated[index].copyWith(
      deliveryState: MessageDeliveryState.failed,
      localOnly: true,
    );
    emit(state.copyWith(
        messages: updated, isUploading: false, isSending: false));
  }

  void _replaceLocalMessage(String tempId, MessageModel message) {
    final updated = List<MessageModel>.from(state.messages);
    // Only this send's placeholder (and a live echo of the same message):
    // matching by text dropped a second identical quick send for a moment.
    updated.removeWhere((m) => m.id == tempId || m.id == message.id);
    updated.add(message);
    updated.sort(_compareByCreatedAt);

    final localMedia = Map<String, List<int>>.from(state.localMediaByMessageId);
    final bytes = localMedia.remove(tempId);
    if (bytes != null) {
      localMedia[message.id] = bytes;
    }

    emit(state.copyWith(messages: updated, localMediaByMessageId: localMedia));
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
    if (message.id.isNotEmpty && !_seenSocketMessageIds.add(message.id)) {
      return;
    }
    if (message.isThreadReply) {
      _applyThreadReplyToRoot(message);
      return;
    }
    _upsertRootMessage(message, fromSocket: true);
    // Keep Alerts in sync when messages arrive while this chat is open.
    unawaited(_markMessagesRead([message]));
    unawaited(_markChannelNotificationsRead());
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    try {
      final reactions = await _messageRepository.toggleReaction(
        channelId: channelId,
        messageId: messageId,
        emoji: emoji,
      );
      final index = state.messages.indexWhere((m) => m.id == messageId);
      if (index < 0) return;
      final updated = List<MessageModel>.from(state.messages);
      updated[index] = updated[index].copyWith(reactions: reactions);
      emit(state.copyWith(messages: updated));
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
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

    if (fromSocket &&
        message.sender.id == currentUserId &&
        !updated.any((m) => m.id == message.id)) {
      // Our own message echoed live: retire the oldest matching placeholder
      // only (two quick identical sends keep both visible).
      final i = updated.indexWhere(
        (m) =>
            m.localOnly &&
            m.sender.id == currentUserId &&
            _messagesMatch(m, message),
      );
      if (i >= 0) updated.removeAt(i);
    }

    final existing = updated.indexWhere((m) => m.id == message.id);
    if (existing >= 0) {
      updated[existing] = message;
    } else {
      updated.add(message);
      updated.sort(_compareByCreatedAt);
    }
    emit(state.copyWith(messages: updated));
    ChatTranscriptCache.save(
      channelId,
      updated,
      hasMore: state.hasMore,
    );
  }

  bool _messagesMatch(MessageModel a, MessageModel b) {
    if (a.type != b.type) return false;
    if (a.type == MessageType.text) {
      return a.content.text?.trim() == b.content.text?.trim();
    }
    if (a.type == MessageType.image ||
        a.type == MessageType.video ||
        a.type == MessageType.document) {
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
    emitTypingStop();
    ActiveChatTracker.instance.leave(channelId);
    for (final timer in _typingExpiry.values) {
      timer.cancel();
    }
    _typingExpiry.clear();
    _connectionSub?.cancel();
    _socketClient.leaveChannel(channelId);
    _messageSub?.cancel();
    _messageUpdatedSub?.cancel();
    _messageDeletedSub?.cancel();
    _typingSub?.cancel();
    _stoppedTypingSub?.cancel();
    _notificationSub?.cancel();
    _memberLeftSub?.cancel();
    return super.close();
  }
}
