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
    final optimistic = cubit.state.messages.where((item) => item.localOnly).single;
    expect(optimistic.content.text, 'Quoted reply');
    expect(optimistic.replyTo?.messageId, source.id);
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

  test('FR-OFF-05 failed upload creates no message and blocks duplicate busy send', () async {
    final pendingUpload = Completer<MediaUploadResult>();
    media.onUpload = () => pendingUpload.future;
    messages.onSendMedia = (type, upload, caption) async =>
        message('media-server', caption ?? '', sender: 'me');
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await settle();
    final first = cubit.sendAttachment(bytes: [1, 2, 3], fileName: 'synthetic.png', mimeType: 'image/png');
    final second = cubit.sendAttachment(bytes: [1, 2, 3], fileName: 'synthetic.png', mimeType: 'image/png');
    expect(media.uploadCount, 1);
    expect(messages.mediaSendCount, 0);
    expect(messages.textSendCount, 0);
    expect(cubit.state.isUploading, isTrue);
    pendingUpload.completeError(const NetworkException('Synthetic upload failure'));
    await Future.wait([first, second]);
    expect(cubit.state.isUploading, isFalse);
    expect(cubit.state.isSending, isFalse);
    expect(cubit.state.error, 'Synthetic upload failure');
    expect(cubit.state.messages.single.deliveryState, MessageDeliveryState.failed);
    expect(messages.mediaSendCount, 0);
    media.onUpload = () async => const MediaUploadResult(
        url: 'https://synthetic.invalid/upload.png', publicId: 'synthetic/upload',
        fileName: 'synthetic.png', fileSize: 3, mimeType: 'image/png');
    await cubit.sendAttachment(bytes: [1, 2, 3], fileName: 'synthetic.png', mimeType: 'image/png');
    expect(media.uploadCount, 2);
    expect(messages.mediaSendCount, 1);
    expect(cubit.state.messages.any((item) => item.id == 'media-server'), isTrue);
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

  testWidgets('FR-RT-04 typing state handles peers, self, duplicate, expiry and disposal', (tester) async {
    cubit = ChannelChatCubit(messageRepository: messages, mediaRepository: media,
        socketClient: socket, channelId: 'chat-regression', currentUserId: 'me');
    await tester.pump();
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
    await tester.pump(const Duration(seconds: 5));
    expect(cubit.state.typingUserNames, isEmpty,
        reason: 'A stale peer typing indicator must expire without a stop event');
    await cubit.close();
    socket.emitEvent(SocketEvents.userTyping,
        {'channelId': 'chat-regression', 'userId': 'peer-c', 'userName': 'Cai'});
    expect(cubit.state.typingUserNames, isEmpty);
  });
}
