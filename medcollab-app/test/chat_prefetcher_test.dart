// Issue 2 (beta 11-14): chats open instantly from a prefetched transcript.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/chat/chat_prefetcher.dart';
import 'package:medcollab_app/core/chat/chat_transcript_cache.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/models/last_message_preview.dart';

import 'functional_regression/fakes/chat_fakes.dart';

ChannelModel _chat(String id, int minutesAgo, {String? last}) => ChannelModel(
      id: id,
      name: id,
      lastMessage: LastMessagePreview(
        messageId: last ?? 'm-$id',
        text: 'hi',
        sentAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      ),
    );

MessageModel _m(String id, String channel) => MessageModel(
      id: id,
      channelId: channel,
      sender: const UserModel(id: 'u'),
      content: const MessageContent(text: 'x'),
    );

class _Repo extends FakeMessageRepository {
  final calls = <String>[];
  int active = 0, peak = 0;
  @override
  Future<MessagesPage> getMessages(String channelId, {String? before, int limit = 30}) async {
    calls.add(channelId);
    active++;
    peak = active > peak ? active : peak;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    active--;
    return MessagesPage(messages: [_m('m-$channelId', channelId)], hasMore: false);
  }
}

void main() {
  setUp(ChatTranscriptCache.clearAll);

  test('warms the most recent chats first, bounded count and concurrency', () async {
    final repo = _Repo();
    final p = ChatPrefetcher(repo);
    final chats = [for (var i = 0; i < 12; i++) _chat('c$i', i)];
    await p.warm(chats.reversed, max: 5, concurrency: 2);
    expect(repo.calls.toSet(), {'c0', 'c1', 'c2', 'c3', 'c4'}, reason: 'newest 5');
    expect(repo.peak, lessThanOrEqualTo(2));
    expect(ChatTranscriptCache.messagesFor('c0'), isNotNull);
    expect(ChatTranscriptCache.messagesFor('c9'), isNull);
  });

  test('skips chats whose cached transcript already has the latest message', () async {
    final repo = _Repo();
    final p = ChatPrefetcher(repo);
    ChatTranscriptCache.save('c0', [_m('m-c0', 'c0')], hasMore: false);
    await p.warm([_chat('c0', 0), _chat('c1', 1)]);
    expect(repo.calls, ['c1']);

    // A newer message arrived in c0 → refetched.
    await p.warm([_chat('c0', 0, last: 'newer')]);
    expect(repo.calls, ['c1', 'c0']);
  });

  test('a failing fetch never breaks the others', () async {
    final repo = _Repo();
    var n = 0;
    final failing = _FailingRepo(() => n++ == 0);
    await ChatPrefetcher(failing).warm([_chat('a', 0), _chat('b', 1)], concurrency: 1);
    expect(ChatTranscriptCache.messagesFor('b'), isNotNull);
    expect(repo.calls, isEmpty);
  });
}

class _FailingRepo extends FakeMessageRepository {
  _FailingRepo(this.shouldFail);
  final bool Function() shouldFail;
  @override
  Future<MessagesPage> getMessages(String channelId, {String? before, int limit = 30}) async {
    if (shouldFail()) throw Exception('offline');
    return MessagesPage(messages: [_m('m-$channelId', channelId)], hasMore: false);
  }
}
