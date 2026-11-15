import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/chat/chat_transcript_cache.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/media/data/models/media_upload_result.dart';
import 'package:medcollab_app/features/messages/data/models/message_delivery_state.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/channel_chat_cubit.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/thread_cubit.dart';
import 'package:medcollab_app/features/messages/data/models/thread_detail.dart';

import 'fakes/chat_fakes.dart';

MessageModel message(String id, String text, {String channel = 'chat-regression', String sender = 'peer', String? threadId, int replyCount = 0}) =>
    MessageModel(id: id, channelId: channel, sender: UserModel(id: sender, name: sender),
        content: MessageContent(text: text), threadId: threadId, replyCount: replyCount,
        createdAt: DateTime.utc(2026, 10, 10));

Future<void> settle() => pumpEventQueue();

void main() {
  late FakeMessageRepository messages;
  late FakeMediaRepository media;
  late FakeSocketClient socket;
  late ChannelChatCubit cubit;
  ThreadCubit? threadCubit;

  setUp(() {
    messages = FakeMessageRepository();
    media = FakeMediaRepository();
    socket = FakeSocketClient();
  });

  tearDown(() async {
    await threadCubit?.close();
    await cubit.close();
    await socket.disposeFake();
  });

  test('FR-OFF-01 optimistic text reconciles to one server ID with quote', () async {
    final source = message('source-1', 'Original note');
    messages.onGetMessages = () async => MessagesPage(messages: [source], hasMore: false);
    final pending = Completer<MessageModel>();
    String? capturedReply;
    messages.onSendText = (text, replyToId) {
      expect(text, 'Quoted reply');
      capturedReply = replyToId;
      return pending.future;
    };
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    cubit.setPendingReply(source);
    final sending = cubit.sendMessage('  Quoted reply  ');
    expect(cubit.state.isSending, isTrue);
    // Shown instantly, before the network call starts.
    final optimistic = cubit.state.messages.where((item) => item.localOnly).single;
    expect(optimistic.content.text, 'Quoted reply');
    expect(optimistic.replyTo?.messageId, source.id);
    await settle(); // queued send starts on the next microtask
    expect(capturedReply, source.id);
    pending.complete(message('server-1', 'Quoted reply', sender: 'me').copyWith(replyTo: optimistic.replyTo));
    await sending;
    expect(cubit.state.isSending, isFalse);
    expect(cubit.state.messages.where((item) => item.id == 'server-1').length, 1);
    expect(cubit.state.messages.where((item) => item.localOnly), isEmpty);
    expect(cubit.state.messages.last.replyTo?.messageId, source.id);
  });

  test('FR-OFF-02 failed send remains visible and composer can send again', () async {
    messages.onSendText = (text, _) async {
      if (text == 'First attempt') throw const NetworkException('Synthetic transport failure');
      return message('server-after-retry', text, sender: 'me');
    };
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    await cubit.sendMessage('First attempt');
    expect(cubit.state.isSending, isFalse);
    expect(cubit.state.error, 'Synthetic transport failure');
    expect(cubit.state.messages.single.deliveryState, MessageDeliveryState.failed);
    expect(cubit.state.messages.single.localOnly, isTrue);
    await cubit.sendMessage('Second attempt');
    expect(cubit.state.isSending, isFalse);
    expect(cubit.state.messages.any((item) => item.id == 'server-after-retry'), isTrue);
    expect(messages.textSendCount, 2);
  });

  test('FR-OFF-04 cached transcript survives offline load and refreshes on recovery', () async {
    final cached = message('cached-1', 'Old content', channel: 'offline-regression');
    ChatTranscriptCache.save('offline-regression', [cached], hasMore: true);
    messages.onGetMessages = () async => throw const NetworkException('Synthetic offline');
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'offline-regression', currentUserId: 'me');
    expect(cubit.state.messages.single.id, 'cached-1');
    expect(cubit.state.isLoading, isFalse);
    await settle();
    expect(cubit.state.messages.single.content.text, 'Old content');
    expect(cubit.state.error, 'Synthetic offline');
    final current = message('server-2', 'Fresh content', channel: 'offline-regression');
    messages.onGetMessages = () async => MessagesPage(messages: [current], hasMore: false);
    await cubit.loadMessages();
    expect(cubit.state.error, isNull);
    expect(cubit.state.messages.map((item) => item.id).toList(), ['server-2']);
    expect(ChatTranscriptCache.messagesFor('offline-regression')?.single.id, 'server-2');
    expect(ChatTranscriptCache.hasMoreFor('offline-regression'), isFalse);
  });

  test('FR-OFF-05 failed upload creates no message; uploads never block typing or other sends', () async {
    final pendingUpload = Completer<MediaUploadResult>();
    media.onUpload = () => pendingUpload.future;
    messages.onSendMedia = (type, upload, caption) async =>
        message('media-server', caption ?? '', sender: 'me');
    messages.onSendText = (text, _) async => message('text-during-upload', text, sender: 'me');
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    final upload = cubit.sendAttachment(bytes: [1, 2, 3], fileName: 'synthetic.png', mimeType: 'image/png');
    expect(media.uploadCount, 1);
    expect(cubit.state.isUploading, isTrue);
    // While the photo uploads, a text still goes out (beta feedback).
    await cubit.sendMessage('Typed during upload');
    expect(cubit.state.messages.any((item) => item.id == 'text-during-upload'), isTrue);
    expect(cubit.state.isUploading, isTrue);
    pendingUpload.completeError(const NetworkException('Synthetic upload failure'));
    await upload;
    expect(cubit.state.isUploading, isFalse);
    expect(cubit.state.isSending, isFalse);
    expect(cubit.state.error, 'Synthetic upload failure');
    expect(cubit.state.messages.where((m) => m.deliveryState == MessageDeliveryState.failed).length, 1);
    expect(messages.mediaSendCount, 0);
    media.onUpload = () async => const MediaUploadResult(
        url: 'https://synthetic.invalid/upload.png', publicId: 'synthetic/upload',
        fileName: 'synthetic.png', fileSize: 3, mimeType: 'image/png');
    await cubit.sendAttachment(bytes: [1, 2, 3], fileName: 'synthetic.png', mimeType: 'image/png');
    expect(media.uploadCount, 2);
    expect(messages.mediaSendCount, 1);
    expect(cubit.state.messages.any((item) => item.id == 'media-server'), isTrue);
  });

  test('quick sends: all shown instantly, sent in order, none dropped', () async {
    final order = <String>[];
    final gates = <Completer<void>>[];
    messages.onSendText = (text, _) async {
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
      order.add(text);
      return message('srv-$text', text, sender: 'me');
    };
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    final a = cubit.sendMessage('one');
    final b = cubit.sendMessage('ok');
    final c = cubit.sendMessage('ok');
    // All three visible immediately (the old code dropped b and c).
    expect(cubit.state.messages.where((m) => m.localOnly).length, 3);
    for (var i = 0; i < 3; i++) {
      await settle();
      gates[i].complete();
    }
    await Future.wait([a, b, c]);
    expect(order, ['one', 'ok', 'ok']);
    expect(messages.textSendCount, 3);
    expect(cubit.state.messages.where((m) => m.localOnly), isEmpty);
    expect(cubit.state.isSending, isFalse);
  });

  test('FR-THR-05 duplicate reply event increments once and HTTP refresh converges', () async {
    final root = message('root-1', 'Root note');
    messages.onGetMessages = () async => MessagesPage(messages: [root], hasMore: false);
    final threadRepository = FakeThreadRepository();
    threadRepository.onGetThread = () async => ThreadDetail(rootMessage: root, replies: const [], hasMore: false);
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    threadCubit = ThreadCubit(threadRepository: threadRepository, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', rootMessageId: 'root-1',
        currentUserId: 'me', initialRoot: root);
    await settle();
    final reply = {
      '_id': 'reply-1', 'channelId': 'chat-regression', 'threadId': 'root-1',
      'senderId': {'_id': 'peer', 'name': 'Peer'},
      'content': {'text': 'Reply text'}, 'createdAt': '2026-10-10T00:00:00.000Z',
    };
    socket.emitEvent(SocketEvents.newMessage, reply);
    socket.emitEvent(SocketEvents.newMessage, reply);
    expect(cubit.state.messages.single.id, 'root-1');
    expect(cubit.state.messages.single.replyCount, 1);
    expect(threadCubit!.state.replies.map((item) => item.id).toList(), ['reply-1']);
    messages.onGetMessages = () async => MessagesPage(
        messages: [root.copyWith(replyCount: 3)], hasMore: false);
    threadRepository.onGetThread = () async => ThreadDetail(
        rootMessage: root.copyWith(replyCount: 3),
        replies: [message('reply-1', 'Reply text', threadId: 'root-1'),
          message('reply-2', 'Second reply', threadId: 'root-1'),
          message('reply-3', 'Third reply', threadId: 'root-1')], hasMore: false);
    await cubit.loadMessages();
    await threadCubit!.loadThread();
    expect(cubit.state.messages.single.replyCount, 3);
    expect(cubit.state.messages.length, 1);
    expect(threadCubit!.state.replies.map((item) => item.id).toList(), ['reply-1', 'reply-2', 'reply-3']);
    expect(threadCubit!.state.rootMessage?.replyCount, 3);
  });

  test('FR-RT-05 reconnect fetches persisted messages and socket duplicates stay one row', () async {
    messages.onGetMessages = () async => const MessagesPage(messages: [], hasMore: false);
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    final pushed = {
      '_id': 'persisted-1', 'channelId': 'chat-regression',
      'senderId': {'_id': 'peer', 'name': 'Peer'},
      'content': {'text': 'Persisted after disconnect'},
    };
    socket.emitEvent(SocketEvents.newMessage, pushed);
    socket.emitEvent(SocketEvents.newMessage, pushed);
    expect(cubit.state.messages.map((item) => item.id).toList(), ['persisted-1']);
    final persisted = message('persisted-1', 'Persisted after disconnect');
    final missed = message('persisted-2', 'Missed during disconnect');
    messages.onGetMessages = () async => MessagesPage(messages: [persisted, missed], hasMore: false);
    socket.emitConnected();
    await settle();
    expect(socket.joined, contains('chat-regression'));
    expect(cubit.state.messages.map((item) => item.id).toList(), ['persisted-1', 'persisted-2']);
    socket.emitEvent(SocketEvents.newMessage, pushed);
    expect(cubit.state.messages.where((item) => item.id == 'persisted-1').length, 1);
  });

  test('FR-RT-04 typing state handles peers, self, duplicate, expiry and disposal', () async {
    final previousExpiry = ChannelChatCubit.typingExpiryDuration;
    ChannelChatCubit.typingExpiryDuration = const Duration(milliseconds: 30);
    addTearDown(() => ChannelChatCubit.typingExpiryDuration = previousExpiry);

    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    socket.emitEvent(SocketEvents.userTyping,
        {'channelId': 'chat-regression', 'userId': 'me', 'userName': 'Me'});
    socket.emitEvent(SocketEvents.userTyping,
        {'channelId': 'other-channel', 'userId': 'peer-a', 'userName': 'Wrong channel'});
    expect(cubit.state.typingUserNames, isEmpty);
    socket.emitEvent(SocketEvents.userTyping,
        {'channelId': 'chat-regression', 'userId': 'peer-a', 'userName': 'Ada'});
    socket.emitEvent(SocketEvents.userTyping,
        {'channelId': 'chat-regression', 'userId': 'peer-a', 'userName': 'Ada'});
    socket.emitEvent(SocketEvents.userTyping,
        {'channelId': 'chat-regression', 'userId': 'peer-b', 'userName': 'Ben'});
    expect(cubit.state.typingUserNames, ['Ada', 'Ben']);
    socket.emitEvent(SocketEvents.userStoppedTyping,
        {'channelId': 'chat-regression', 'userId': 'peer-a'});
    expect(cubit.state.typingUserNames, ['Ben']);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(cubit.state.typingUserNames, isEmpty,
        reason: 'A stale peer typing indicator must expire without a stop event');
    await cubit.close();
    socket.emitEvent(SocketEvents.userTyping,
        {'channelId': 'chat-regression', 'userId': 'peer-c', 'userName': 'Cai'});
    expect(cubit.state.typingUserNames, isEmpty);
  });

  test('delete for me / for everyone: instant removal, restore on failure, live delete', () async {
    final mine = message('m-1', 'mine', sender: 'me');
    final theirs = message('t-1', 'theirs');
    final other = message('o-1', 'other');
    messages.onGetMessages = () async => MessagesPage(messages: [mine, theirs, other], hasMore: false);
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    expect(cubit.state.messages.length, 3);

    await cubit.deleteMessage('m-1', forEveryone: true);
    expect(messages.deletes.last, ('m-1', true));
    expect(cubit.state.messages.map((m) => m.id), ['t-1', 'o-1']);

    await cubit.deleteMessage('t-1', forEveryone: false);
    expect(messages.deletes.last, ('t-1', false));
    expect(cubit.state.messages.map((m) => m.id), ['o-1']);

    // Server refuses: the message comes back with an error.
    messages.onDelete = () async => throw const ForbiddenException('You can only delete your own messages for everyone');
    await cubit.deleteMessage('o-1', forEveryone: true);
    expect(cubit.state.messages.map((m) => m.id), ['o-1']);
    expect(cubit.state.error, contains('your own messages'));

    // Someone deleted for everyone: it disappears live (no placeholder row).
    socket.emitEvent(SocketEvents.messageDeleted, {'messageId': 'o-1', 'channelId': 'chat-regression'});
    expect(cubit.state.messages, isEmpty);
    // Unknown ids (other chats / thread replies) never create rows.
    socket.emitEvent(SocketEvents.messageDeleted, {'messageId': 'elsewhere'});
    expect(cubit.state.messages, isEmpty);
  });

  test('partial message_updated with replyCount lowers the root count', () async {
    messages.onGetMessages = () async =>
        MessagesPage(messages: [message('root', 'root', replyCount: 2)], hasMore: false);
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    socket.emitEvent(SocketEvents.messageUpdated, {'messageId': 'root', 'replyCount': 1});
    expect(cubit.state.messages.single.replyCount, 1);
    expect(cubit.state.messages.single.content.text, 'root');
  });

  test('clear chat empties the view, keeps sending messages, restores on failure', () async {
    messages.onGetMessages = () async =>
        MessagesPage(messages: [message('a', 'a'), message('b', 'b')], hasMore: true);
    final gate = Completer<MessageModel>();
    messages.onSendText = (text, _) => gate.future;
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    final sending = cubit.sendMessage('in flight');
    expect(await cubit.clearChat(), isTrue);
    expect(messages.clearCount, 1);
    expect(cubit.state.messages.map((m) => m.content.text), ['in flight']);
    expect(cubit.state.hasMore, isFalse);
    gate.complete(message('srv', 'in flight', sender: 'me'));
    await sending;

    messages.onClear = () async => throw const NetworkException('offline');
    final before = cubit.state.messages.length;
    expect(await cubit.clearChat(), isFalse);
    expect(cubit.state.messages.length, before);
    expect(cubit.state.error, 'offline');
  });
}