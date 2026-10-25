import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentSpaceItem {
  const RecentSpaceItem({
    required this.spaceId,
    required this.name,
    required this.visitedAt,
  });

  factory RecentSpaceItem.fromJson(Map<String, dynamic> json) {
    return RecentSpaceItem(
      spaceId: json['spaceId'] as String,
      name: json['name'] as String? ?? 'Space',
      visitedAt: DateTime.tryParse(json['visitedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String spaceId;
  final String name;
  final DateTime visitedAt;

  Map<String, dynamic> toJson() => {
        'spaceId': spaceId,
        'name': name,
        'visitedAt': visitedAt.toIso8601String(),
      };
}

class RecentChannelItem {
  const RecentChannelItem({
    required this.spaceId,
    required this.channelId,
    required this.channelName,
    required this.spaceName,
    required this.visitedAt,
  });

  factory RecentChannelItem.fromJson(Map<String, dynamic> json) {
    return RecentChannelItem(
      spaceId: json['spaceId'] as String,
      channelId: json['channelId'] as String,
      channelName: json['channelName'] as String? ?? 'channel',
      spaceName: json['spaceName'] as String? ?? '',
      visitedAt: DateTime.tryParse(json['visitedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String spaceId;
  final String channelId;
  final String channelName;
  final String spaceName;
  final DateTime visitedAt;

  Map<String, dynamic> toJson() => {
        'spaceId': spaceId,
        'channelId': channelId,
        'channelName': channelName,
        'spaceName': spaceName,
        'visitedAt': visitedAt.toIso8601String(),
      };
}

class PinnedHomeItem {
  const PinnedHomeItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.spaceId,
    this.channelId,
    this.handoffId,
  });

  factory PinnedHomeItem.fromJson(Map<String, dynamic> json) {
    return PinnedHomeItem(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? 'channel',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      spaceId: json['spaceId'] as String?,
      channelId: json['channelId'] as String?,
      handoffId: json['handoffId'] as String?,
    );
  }

  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String? spaceId;
  final String? channelId;
  final String? handoffId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'subtitle': subtitle,
        if (spaceId != null) 'spaceId': spaceId,
        if (channelId != null) 'channelId': channelId,
        if (handoffId != null) 'handoffId': handoffId,
      };
}

/// Tracks recent navigation for the clinical workspace dashboard.
class RecentItemsService {
  RecentItemsService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;
  static const _spacesKey = 'medcollab_recent_spaces_v1';
  static const _channelsKey = 'medcollab_recent_channels_v1';
  static const _pinnedKey = 'medcollab_pinned_home_v1';
  static const _maxItems = 8;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> recordSpaceVisit({
    required String spaceId,
    required String name,
  }) async {
    await init();
    final items = await getRecentSpaces();
    items.removeWhere((s) => s.spaceId == spaceId);
    items.insert(
      0,
      RecentSpaceItem(spaceId: spaceId, name: name, visitedAt: DateTime.now()),
    );
    await _saveList(_spacesKey, items.map((e) => e.toJson()).toList());
  }

  Future<List<RecentSpaceItem>> getRecentSpaces() async {
    return _loadList(_spacesKey, RecentSpaceItem.fromJson);
  }

  Future<void> recordChannelVisit({
    required String spaceId,
    required String channelId,
    required String channelName,
    required String spaceName,
  }) async {
    await init();
    final items = await getRecentChannels();
    items.removeWhere((c) => c.channelId == channelId);
    items.insert(
      0,
      RecentChannelItem(
        spaceId: spaceId,
        channelId: channelId,
        channelName: channelName,
        spaceName: spaceName,
        visitedAt: DateTime.now(),
      ),
    );
    if (items.length > _maxItems) items.removeRange(_maxItems, items.length);
    await _saveList(_channelsKey, items.map((e) => e.toJson()).toList());
  }

  Future<List<RecentChannelItem>> getRecentChannels() async {
    return _loadList(_channelsKey, RecentChannelItem.fromJson);
  }

  Future<List<PinnedHomeItem>> getPinnedItems() async {
    return _loadList(_pinnedKey, PinnedHomeItem.fromJson);
  }

  Future<void> pinItem(PinnedHomeItem item) async {
    await init();
    final items = await getPinnedItems();
    items.removeWhere((p) => p.id == item.id);
    items.insert(0, item);
    if (items.length > 12) items.removeRange(12, items.length);
    await _saveList(_pinnedKey, items.map((e) => e.toJson()).toList());
  }

  Future<void> unpinItem(String id) async {
    await init();
    final items = await getPinnedItems()
      ..removeWhere((p) => p.id == id);
    await _saveList(_pinnedKey, items.map((e) => e.toJson()).toList());
  }

  Future<void> clearAll() async {
    await init();
    await Future.wait([
      _prefs!.remove(_spacesKey),
      _prefs!.remove(_channelsKey),
      _prefs!.remove(_pinnedKey),
    ]);
  }

  Future<List<T>> _loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    await init();
    final raw = _prefs!.getString(key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> data) async {
    await _prefs!.setString(key, jsonEncode(data));
  }
}
