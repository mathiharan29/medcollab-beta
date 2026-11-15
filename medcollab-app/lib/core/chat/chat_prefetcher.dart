import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:medcollab_app/core/chat/chat_transcript_cache.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

/// Warms [ChatTranscriptCache] for the chats a doctor is most likely to
/// open next (beta 11-14, issue 2), so tapping one paints its messages
/// instantly instead of waiting a round trip to the server (~0.3–0.6 s on
/// mobile data from India). The chat still refreshes silently on open.
///
/// Bounded: only the [max] most recent chats, [concurrency] requests at a
/// time, and a chat whose cached newest message is already the latest one
/// is skipped. In memory only (cleared at sign-out) — no message content is
/// written to disk.
class ChatPrefetcher {
  ChatPrefetcher(this._repository);

  final MessageRepository _repository;
  final Set<String> _inFlight = {};

  /// Chats warmed in this session (for tests / logs).
  @visibleForTesting
  final List<String> warmed = [];

  static const defaultMax = 8;

  Future<void> warm(
    Iterable<ChannelModel> chats, {
    int max = defaultMax,
    int concurrency = 2,
  }) async {
    final ranked = chats
        .where((c) => c.id.isNotEmpty && c.lastMessage?.messageId != null)
        .toList()
      ..sort((a, b) {
        final at = a.lastMessage?.sentAt ?? DateTime(0);
        final bt = b.lastMessage?.sentAt ?? DateTime(0);
        return bt.compareTo(at);
      });

    final todo = <ChannelModel>[];
    for (final c in ranked) {
      if (todo.length >= max) break;
      if (_inFlight.contains(c.id) || _isFresh(c)) continue;
      todo.add(c);
    }
    if (todo.isEmpty) return;

    var next = 0;
    Future<void> worker() async {
      while (next < todo.length) {
        final c = todo[next++];
        _inFlight.add(c.id);
        try {
          // Never overwrite a transcript an open chat saved meanwhile.
          if (_isFresh(c)) continue;
          final page = await _repository.getMessages(c.id);
          if (ChatTranscriptCache.messagesFor(c.id) == null || !_isFresh(c)) {
            ChatTranscriptCache.save(c.id, page.messages, hasMore: page.hasMore);
            warmed.add(c.id);
          }
        } catch (_) {
          // Prefetch is best effort; the chat loads normally when opened.
        } finally {
          _inFlight.remove(c.id);
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency.clamp(1, 4); i++) worker(),
    ]);
  }

  /// Cached transcript already ends with the chat's latest message.
  static bool _isFresh(ChannelModel c) {
    final cached = ChatTranscriptCache.messagesFor(c.id);
    if (cached == null || cached.isEmpty) return false;
    final latest = c.lastMessage?.messageId;
    return latest != null && cached.any((m) => m.id == latest);
  }
}
