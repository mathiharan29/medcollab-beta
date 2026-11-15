// Found on device (beta 11-14 journey): a message that arrived live while
// the chat's load was in flight vanished when the (older) snapshot replaced
// the list — and one deleted meanwhile came back.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/channel_chat_cubit.dart';

import 'functional_regression/fakes/chat_fakes.dart';

MessageModel _m(String id, String text, String channel, int minute) => MessageModel(
      id: id,
      channelId: channel,
      sender: UserModel(id: 'bala', name: 'Bala'),
      content: MessageContent(text: text),
      createdAt: DateTime.utc(2026, 11, 15, 10, minute),
    );

Map<String, dynamic> _wire(String id, String text, String channel, int minute) => {
      '_id': id,
      'channelId': channel,
      'type': 'text',
      'sender': {'_id': 'bala', 'name': 'Bala'},
      'content': {'text': text},
      'createdAt': DateTime.utc(2026, 11, 15, 10, minute).toIso8601String(),
    };

void main() {
  late FakeMessageRepository repo;
  late FakeSocketClient socket;
  late ChannelChatCubit cubit;

  setUp(() {
    repo = FakeMessageRepository();
    socket = FakeSocketClient();
  });
  tearDown(() async {
    await cubit.close();
    await socket.disposeFake();
  });

  test('a message arriving while the load is in flight stays visible', () async {
    const ch = 'race-add';
    final snapshot = Completer<MessagesPage>();
    repo.onGetMessages = () => snapshot.future;
    cubit = ChannelChatCubit(
        messageRepository: repo,
        mediaRepository: FakeMediaRepository(),
        socketClient: socket,
        channelId: ch,
        currentUserId: 'meera');
    await pumpEventQueue();

    socket.emitEvent(SocketEvents.newMessage, _wire('live', 'While you read', ch, 5));
    await pumpEventQueue();
    expect(cubit.state.messages.map((m) => m.id), contains('live'));

    // The request started before "live" existed: its snapshot lacks it.
    snapshot.complete(MessagesPage(
        messages: [_m('a', 'ABG', ch, 1), _m('b', 'Please call back', ch, 3)],
        hasMore: false));
    await pumpEventQueue();
    expect(cubit.state.messages.map((m) => m.id), ['a', 'b', 'live'],
        reason: 'the live message was dropped by the stale snapshot');
  });

  test('a message deleted while the load is in flight does not come back', () async {
    const ch = 'race-del';
    final snapshot = Completer<MessagesPage>();
    repo.onGetMessages = () => snapshot.future;
    cubit = ChannelChatCubit(
        messageRepository: repo,
        mediaRepository: FakeMediaRepository(),
        socketClient: socket,
        channelId: ch,
        currentUserId: 'meera');
    await pumpEventQueue();
    socket.emitEvent(SocketEvents.messageDeleted, {'messageId': 'b', 'channelId': ch});
    await pumpEventQueue();
    snapshot.complete(MessagesPage(
        messages: [_m('a', 'ABG', ch, 1), _m('b', 'wrong dose', ch, 3)],
        hasMore: false));
    await pumpEventQueue();
    expect(cubit.state.messages.map((m) => m.id), ['a']);
  });

  test('a send started while the load is in flight keeps its bubble', () async {
    const ch = 'race-send';
    final snapshot = Completer<MessagesPage>();
    final sent = Completer<MessageModel>();
    repo.onGetMessages = () => snapshot.future;
    repo.onSendText = (text, _) => sent.future;
    cubit = ChannelChatCubit(
        messageRepository: repo,
        mediaRepository: FakeMediaRepository(),
        socketClient: socket,
        channelId: ch,
        currentUserId: 'meera');
    await pumpEventQueue();
    final sending = cubit.sendMessage('On my way');
    await pumpEventQueue();
    snapshot.complete(MessagesPage(messages: [_m('a', 'ABG', ch, 1)], hasMore: false));
    await pumpEventQueue();
    expect(cubit.state.messages.where((m) => m.localOnly).map((m) => m.content.text),
        ['On my way'], reason: 'the sending bubble disappeared mid-send');
    sent.complete(MessageModel(
        id: 'srv', channelId: ch, sender: UserModel(id: 'meera', name: 'Meera'),
        content: MessageContent(text: 'On my way'),
        createdAt: DateTime.utc(2026, 11, 15, 10, 30)));
    await sending;
    expect(cubit.state.messages.map((m) => m.id), ['a', 'srv']);
  });

  test('a later load (no live changes) still replaces the list', () async {
    const ch = 'race-plain';
    var page = MessagesPage(messages: [_m('a', 'one', ch, 1)], hasMore: false);
    repo.onGetMessages = () async => page;
    cubit = ChannelChatCubit(
        messageRepository: repo,
        mediaRepository: FakeMediaRepository(),
        socketClient: socket,
        channelId: ch,
        currentUserId: 'meera');
    await pumpEventQueue();
    page = MessagesPage(messages: [_m('c', 'three', ch, 3)], hasMore: false);
    await cubit.loadMessages(silent: true);
    expect(cubit.state.messages.map((m) => m.id), ['c'],
        reason: 'server-side removals (e.g. delete for me elsewhere) still apply');
  });
}
