// Beta round 11-26: forward display, reactions (several per person, fast
// taps, no "Something went wrong"), camera → gallery, handoff voice replies.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_write_back_note.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_reply_to.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/channel_chat_cubit.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/features/spaces/data/models/last_message_preview.dart';

import 'functional_regression/fakes/chat_fakes.dart';

const _legacy = '↪️ Forwarded from Mathiharan T\n'
    'vocle://c/6af28c978d9036afadb8de9d/m/6af95610cda8c23ea63d03a7\n\nHi babu';

class _ReactRepo extends FakeMessageRepository {
  final calls = <(String emoji, bool? active)>[];
  final pending = <Completer<List<MessageReaction>>>[];
  bool fail = false;

  @override
  Future<List<MessageReaction>> toggleReaction({
    required String channelId,
    required String messageId,
    required String emoji,
    bool? active,
  }) {
    calls.add((emoji, active));
    final c = Completer<List<MessageReaction>>();
    pending.add(c);
    if (fail) c.completeError(const ServerException('Something went wrong. Please try again.'));
    return c.future;
  }
}

MessageModel _msg({List<MessageReaction> reactions = const []}) => MessageModel(
      id: 'm1',
      channelId: 'c1',
      sender: const UserModel(id: 'sriram', name: 'Sriram'),
      content: const MessageContent(text: 'Yeah noted'),
      createdAt: DateTime.utc(2026, 11, 25, 22, 38),
      reactions: reactions,
    );

void main() {
  group('forward (issue 2)', () {
    test('old text forwards are read back without the vocle:// link', () {
      final m = MessageModel(
        id: 'x',
        channelId: 'c',
        sender: const UserModel(id: 'u'),
        content: const MessageContent(text: _legacy),
      );
      expect(m.forwardInfo!.fromName, 'Mathiharan T');
      expect(m.forwardInfo!.sourceMessageId, '6af95610cda8c23ea63d03a7');
      expect(m.displayText, 'Hi babu');
      expect(m.displayText, isNot(contains('vocle://')));
    });

    test('old media forward: storage URL becomes an attachment, not text', () {
      final info = ForwardInfo.fromLegacyText(
          '↪️ Forwarded from Sriram\nvocle://c/abc/m/def\n\nLook at this\nhttps://res.cloudinary.com/x/image/upload/a.jpg')!;
      expect(info.body, 'Look at this');
      expect(info.legacyMediaUrl, 'https://res.cloudinary.com/x/image/upload/a.jpg');
    });

    test('quotes and chat-list previews of old forwards hide the link (even cut short)', () {
      const quote = MessageReplyTo(
        messageId: 'q',
        text: '↪️ Forwarded from Mathiharan T\nvocle://c/6af28c978d9036afadb8de9d/m/6…',
      );
      expect(quote.previewLabel, 'Forwarded message');
      const preview = LastMessagePreview(text: _legacy);
      expect(preview.previewLabel, '↪ Hi babu');
    });

    test('server forwards carry who wrote it and where', () {
      final m = MessageModel.fromJson({
        '_id': 'f1',
        'channelId': 'c2',
        'type': 'image',
        'senderId': {'_id': 'me', 'name': 'Meera'},
        'content': {'mediaUrl': 'https://res.cloudinary.com/x/a.jpg'},
        'forwarded': {'fromName': 'Dr Arjun Rao', 'sourceChannelId': 'c1', 'sourceMessageId': 'm9'},
      });
      expect(m.type, MessageType.image);
      expect(m.forwardInfo!.fromName, 'Dr Arjun Rao');
      expect(m.forwardInfo!.canOpenSource, isTrue);
    });

    testWidgets('a forwarded bubble shows "Forwarded from" and never the raw link', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: MessageModel(
              id: 'x',
              channelId: 'c',
              sender: const UserModel(id: 'u', name: 'Sanjay'),
              content: const MessageContent(text: _legacy),
            ),
            isMine: false,
          ),
        ),
      ));
      expect(find.text('Forwarded from Mathiharan T'), findsOneWidget);
      expect(find.textContaining('vocle://'), findsNothing);
      expect(find.textContaining('Hi babu'), findsOneWidget);
    });
  });

  group('reactions (issues 3, 6, 8)', () {
    late _ReactRepo repo;
    late FakeSocketClient socket;
    late ChannelChatCubit cubit;

    Future<void> open(MessageModel m) async {
      repo.onGetMessages = () async => MessagesPage(messages: [m], hasMore: false);
      cubit = ChannelChatCubit(
        messageRepository: repo,
        mediaRepository: FakeMediaRepository(),
        socketClient: socket,
        channelId: 'c1',
        currentUserId: 'me',
      );
      await pumpEventQueue();
    }

    setUp(() {
      repo = _ReactRepo();
      socket = FakeSocketClient();
    });
    tearDown(() async {
      await cubit.close();
      await socket.disposeFake();
    });

    List<String> mine() => [
          for (final r in cubit.state.messages.single.reactions)
            if (r.reactedBy('me')) r.emoji,
        ];

    test('several emojis per person: adding ❤️ keeps 👍 (no replace)', () async {
      await open(_msg(reactions: const [MessageReaction(emoji: '👍', userIds: ['me'])]));
      unawaited(cubit.toggleReaction('m1', '❤️'));
      await pumpEventQueue();
      expect(mine(), ['👍', '❤️']);
      repo.pending.single.complete(const [
        MessageReaction(emoji: '👍', userIds: ['me']),
        MessageReaction(emoji: '❤️', userIds: ['me']),
      ]);
      await pumpEventQueue();
      expect(mine(), ['👍', '❤️']);
      expect(repo.calls.single, ('❤️', true));
    });

    test('a fast double tap shows at once, sends in order with explicit state, no error', () async {
      await open(_msg());
      unawaited(cubit.toggleReaction('m1', '👍'));
      unawaited(cubit.toggleReaction('m1', '👍'));
      await pumpEventQueue();
      expect(mine(), isEmpty, reason: 'second tap undid the first, locally');
      expect(repo.calls, [('👍', true)], reason: 'second request waits for the first');
      // A live echo of the first request must not flash it back.
      socket.emitEvent(SocketEvents.messageUpdated, {
        'messageId': 'm1',
        'reactions': [
          {'emoji': '👍', 'userIds': ['me']}
        ],
      });
      await pumpEventQueue();
      expect(mine(), isEmpty);
      repo.pending[0].complete(const [MessageReaction(emoji: '👍', userIds: ['me'])]);
      await pumpEventQueue();
      expect(repo.calls, [('👍', true), ('👍', false)]);
      repo.pending[1].complete(const []);
      await pumpEventQueue();
      expect(mine(), isEmpty);
      expect(cubit.state.error, isNull);
    });

    test('a failed reaction is undone and the banner clears itself', () async {
      await open(_msg());
      repo.fail = true;
      await cubit.toggleReaction('m1', '👍');
      expect(mine(), isEmpty);
      expect(cubit.state.error, isNotNull);
      cubit.dismissError();
      expect(cubit.state.error, isNull);
    });
  });

  group('reaction chips', () {
    testWidgets('tap someone else\'s emoji adds yours; tapping yours asks before removing', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: _msg(reactions: const [
              MessageReaction(emoji: '👍', userIds: ['sriram']),
              MessageReaction(emoji: '❤️', userIds: ['me']),
            ]),
            isMine: false,
            currentUserId: 'me',
            onReact: taps.add,
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('reaction-m1-👍')));
      expect(taps, ['👍']);
      await tester.tap(find.byKey(const Key('reaction-m1-❤️')));
      await tester.pumpAndSettle();
      expect(taps, ['👍'], reason: 'one tap on your own emoji no longer removes it');
      expect(find.text('Tap to remove'), findsOneWidget);
      // The second tap of a double tap lands on the sheet: it must not remove.
      await tester.tap(find.byKey(const Key('reaction-remove-mine')));
      await tester.tap(find.text('You'), warnIfMissed: false);
      await tester.pump();
      expect(taps, ['👍'], reason: 'a quick second tap does not remove the reaction');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
      await tester.tap(find.byKey(const Key('reaction-remove-mine')));
      await tester.pumpAndSettle();
      expect(taps, ['👍', '❤️'], reason: 'the Remove button removes it');
    });
  });

  group('camera (issue 7)', () {
    testWidgets('camera offers Take photo and Choose from gallery', (tester) async {
      var camera = 0, gallery = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MessageComposer(
              controller: TextEditingController(),
              onSend: (_) {},
              onPickCamera: () => camera++,
              onPickGallery: () => gallery++,
            ),
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Camera'));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect((camera, gallery), (0, 1));
      await tester.tap(find.byTooltip('Camera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      expect((camera, gallery), (1, 1));
    });
  });

  group('handoff voice reply (issue 4)', () {
    test('a write-back note can be a voice note', () {
      final n = HandoffWriteBackNote.fromJson({
        '_id': 'n1',
        'authorId': {'_id': 'm', 'name': 'Mathiharan T'},
        'text': '',
        'kind': 'note',
        'voiceNote': {'url': 'https://res.cloudinary.com/x/v.m4a', 'mimeType': 'audio/mp4', 'durationMs': 4200},
      });
      expect(n.voiceNote!.durationMs, 4200);
      expect(n.text, isEmpty);
    });
  });
}
