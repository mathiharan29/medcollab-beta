// Needl / thread smoothness: live edits and deletes never create stray rows,
// edits apply in place, and thread reply counts stay exact.
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/models/thread_detail.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/channel_chat_cubit.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/thread_cubit.dart';

import 'fakes/chat_fakes.dart';

MessageModel _msg(String id, String text, {String? threadId, int replyCount = 0}) =>
    MessageModel(
      id: id,
      channelId: 'needl-1',
      sender: const UserModel(id: 'peer', name: 'Peer'),
      content: MessageContent(text: text),
      threadId: threadId,
      replyCount: replyCount,
      createdAt: DateTime.utc(2026, 11, 9),
    );

void main() {
  late FakeMessageRepository messages;
  late FakeSocketClient socket;
  late ChannelChatCubit chat;
  ThreadCubit? thread;

  setUp(() async {
    messages = FakeMessageRepository();
    socket = FakeSocketClient();
    final root = _msg('root', 'Bed 7 K+ 6.1', replyCount: 1);
    messages.onGetMessages =
        () async => MessagesPage(messages: [root, _msg('m2', 'On it')], hasMore: false);
    chat = ChannelChatCubit(
      messageRepository: messages,
      mediaRepository: FakeMediaRepository(),
      socketClient: socket,
      channelId: 'needl-1',
      currentUserId: 'me',
    );
    await pumpEventQueue();
  });

  tearDown(() async {
    await thread?.close();
    thread = null;
    await chat.close();
    await socket.disposeFake();
  });

  test('edit event updates the message in place (no stray row)', () async {
    socket.emitEvent(SocketEvents.messageUpdated, {
      'messageId': 'm2',
      'content': {'text': 'On it — 2 min'},
      'isEdited': true,
    });
    expect(chat.state.messages.map((m) => m.id).toList(), ['root', 'm2']);
    final m2 = chat.state.messages.firstWhere((m) => m.id == 'm2');
    expect(m2.content.text, 'On it — 2 min');
    expect(m2.isEdited, isTrue);
  });

  test('edit for an unknown message is ignored', () async {
    socket.emitEvent(SocketEvents.messageUpdated, {
      'messageId': 'not-here',
      'content': {'text': 'x'},
      'isEdited': true,
    });
    expect(chat.state.messages.map((m) => m.id).toList(), ['root', 'm2']);
  });

  test('deleting a thread reply does not add a "deleted" row to the chat',
      () async {
    socket.emitEvent(SocketEvents.messageDeleted,
        {'messageId': 'reply-9', 'deletedAt': '2026-11-09T10:00:00Z'});
    expect(chat.state.messages.map((m) => m.id).toList(), ['root', 'm2']);
    expect(chat.state.messages.any((m) => m.isDeleted), isFalse);
  });

  test('new thread reply bumps the count once; its later edit does not',
      () async {
    final reply = {
      '_id': 'reply-2',
      'channelId': 'needl-1',
      'threadId': 'root',
      'senderId': {'_id': 'peer', 'name': 'Peer'},
      'content': {'text': 'Calcium given'},
      'createdAt': '2026-11-09T10:00:00.000Z',
    };
    socket.emitEvent(SocketEvents.newMessage, reply);
    socket.emitEvent(SocketEvents.newMessage, reply);
    expect(chat.state.messages.first.replyCount, 2);
    socket.emitEvent(SocketEvents.messageUpdated, {...reply, 'isEdited': true});
    socket.emitEvent(SocketEvents.messageUpdated, {
      'messageId': 'reply-2',
      'content': {'text': 'Calcium given 10 ml'},
      'isEdited': true,
    });
    expect(chat.state.messages.first.replyCount, 2);
    expect(chat.state.messages.length, 2);
  });

  test('open thread: replies edit and disappear live; root edit shows',
      () async {
    final threads = FakeThreadRepository()
      ..onGetThread = () async => ThreadDetail(
            rootMessage: _msg('root', 'Bed 7 K+ 6.1', replyCount: 2),
            replies: [
              _msg('r1', 'Calcium given', threadId: 'root'),
              _msg('r2', 'Insulin started', threadId: 'root'),
            ],
            hasMore: false,
          );
    thread = ThreadCubit(
      threadRepository: threads,
      mediaRepository: FakeMediaRepository(),
      socketClient: socket,
      channelId: 'needl-1',
      rootMessageId: 'root',
      currentUserId: 'me',
    );
    await pumpEventQueue();
    expect(thread!.state.replies.map((r) => r.id).toList(), ['r1', 'r2']);

    socket.emitEvent(SocketEvents.messageUpdated, {
      'messageId': 'r1',
      'content': {'text': 'Calcium gluconate 10 ml given'},
      'isEdited': true,
    });
    expect(thread!.state.replies.first.content.text,
        'Calcium gluconate 10 ml given');
    expect(thread!.state.replies.first.isEdited, isTrue);

    socket.emitEvent(SocketEvents.messageDeleted, {'messageId': 'r2'});
    expect(thread!.state.replies.map((r) => r.id).toList(), ['r1']);

    socket.emitEvent(SocketEvents.messageUpdated, {
      'messageId': 'root',
      'content': {'text': 'Bed 7 K+ 6.4 (repeat)'},
      'isEdited': true,
    });
    expect(thread!.state.rootMessage?.content.text, 'Bed 7 K+ 6.4 (repeat)');

    // A reply for another thread never lands here.
    socket.emitEvent(SocketEvents.newMessage, {
      '_id': 'other',
      'channelId': 'needl-1',
      'threadId': 'some-other-root',
      'senderId': {'_id': 'peer', 'name': 'Peer'},
      'content': {'text': 'not this thread'},
    });
    expect(thread!.state.replies.map((r) => r.id).toList(), ['r1']);
  });
}
