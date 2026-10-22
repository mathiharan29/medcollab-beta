import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/storage/bookmark_service.dart';
import 'package:medcollab_app/core/storage/draft_message_service.dart';
import 'package:medcollab_app/core/storage/recent_items_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('FR-OFF-03 root and thread drafts restore independently', () async {
    final drafts = DraftMessageService();
    await drafts.saveDraft('channel-a', 'Root text  ');
    await drafts.saveDraft('channel-a', 'Thread one', threadId: 'root-1');
    await drafts.saveDraft('channel-a', 'Thread two', threadId: 'root-2');
    await drafts.saveDraft('channel-b', 'Other channel');

    final reopened = DraftMessageService();
    expect(await reopened.getDraft('channel-a'), 'Root text  ');
    expect(await reopened.getDraft('channel-a', threadId: 'root-1'), 'Thread one');
    expect(await reopened.getDraft('channel-a', threadId: 'root-2'), 'Thread two');
    expect(await reopened.draftChannelIds(), {'channel-a', 'channel-b'});

    await reopened.clearDraft('channel-a', threadId: 'root-1');
    expect(await reopened.getDraft('channel-a', threadId: 'root-1'), isNull);
    expect(await reopened.getDraft('channel-a'), 'Root text  ');
    expect(await reopened.getDraft('channel-a', threadId: 'root-2'), 'Thread two');
    expect(await reopened.getDraft('channel-b'), 'Other channel');
  });

  test('FR-SAVE-01 bookmarks dedupe, order, route IDs and persist removal', () async {
    final storage = await SharedPreferences.getInstance();
    final bookmarks = BookmarkService(prefs: storage);
    final older = DateTime.utc(2026, 10, 1);
    final newer = DateTime.utc(2026, 10, 2);
    final message = BookmarkItem(
      id: 'message-1', type: BookmarkType.message, title: 'Message', subtitle: 'Synthetic',
      savedAt: older, spaceId: 'space-1', channelId: 'channel-1', messageId: 'message-1',
    );
    final thread = BookmarkItem(
      id: 'thread-1', type: BookmarkType.thread, title: 'Thread', subtitle: 'Synthetic',
      savedAt: newer, spaceId: 'space-2', channelId: 'channel-2', messageId: 'root-2',
    );
    final handoff = BookmarkItem(
      id: 'handoff-1', type: BookmarkType.handoff, title: 'Handoff', subtitle: 'Synthetic',
      savedAt: DateTime.utc(2026, 10, 3), handoffId: 'handoff-1',
    );
    await bookmarks.save(message);
    await bookmarks.save(thread);
    await bookmarks.save(handoff);
    await bookmarks.save(message);

    final reopened = BookmarkService(prefs: storage);
    final saved = await reopened.getAll();
    expect(saved.map((item) => item.id).toList(), ['handoff-1', 'thread-1', 'message-1']);
    expect(saved.where((item) => item.id == 'message-1').length, 1);
    expect(saved[0].handoffId, 'handoff-1');
    expect(saved[1].channelId, 'channel-2');
    expect(saved[1].messageId, 'root-2');
    expect(saved[2].spaceId, 'space-1');
    expect(saved[2].messageId, 'message-1');
    await reopened.toggle(message);
    expect(await BookmarkService(prefs: storage).isBookmarked('message-1'), isFalse);
    expect((await reopened.getAll()).map((item) => item.id).toList(), ['handoff-1', 'thread-1']);
  });

  test('FR-SAVE-03 recent channels and pins enforce independent caps', () async {
    final storage = await SharedPreferences.getInstance();
    final service = RecentItemsService(prefs: storage);
    for (var i = 0; i < 9; i++) {
      await service.recordChannelVisit(
        spaceId: 'space-${i % 2}', channelId: 'channel-$i',
        channelName: 'Channel $i', spaceName: 'Space ${i % 2}',
      );
    }
    await service.recordChannelVisit(
      spaceId: 'space-0', channelId: 'channel-4',
      channelName: 'Channel four revisited', spaceName: 'Space 0',
    );
    for (var i = 0; i < 13; i++) {
      await service.pinItem(PinnedHomeItem(
        id: 'pin-$i', kind: 'channel', title: 'Pinned $i', subtitle: 'Synthetic',
        channelId: 'channel-$i', spaceId: 'space-0',
      ));
    }
    await service.pinItem(const PinnedHomeItem(
      id: 'pin-4', kind: 'channel', title: 'Pinned four revisited',
      subtitle: 'Synthetic', channelId: 'channel-4', spaceId: 'space-0',
    ));
    final reopened = RecentItemsService(prefs: storage);
    final recent = await reopened.getRecentChannels();
    final pins = await reopened.getPinnedItems();
    expect(recent.length, 8);
    expect(recent.first.channelId, 'channel-4');
    expect(recent.first.channelName, 'Channel four revisited');
    expect(recent.map((item) => item.channelId).toSet().length, 8);
    expect(recent.any((item) => item.channelId == 'channel-0'), isFalse);
    expect(pins.length, 12);
    expect(pins.first.id, 'pin-4');
    expect(pins.first.channelId, 'channel-4');
    expect(pins.map((item) => item.id).toSet().length, 12);
    expect(pins.any((item) => item.id == 'pin-0'), isFalse);
  });
}
