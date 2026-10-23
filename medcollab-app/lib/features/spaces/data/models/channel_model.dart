import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/spaces/data/models/last_message_preview.dart';

class ChannelModel extends Equatable {
  const ChannelModel({
    required this.id,
    this.spaceId,
    required this.name,
    this.description = '',
    this.type = ChannelType.general,
    this.isPrivate = false,
    this.lastMessage,
    this.position = 0,
    this.peer,
    this.members = const [],
    this.isNeedl = false,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['id'];
    final peerJson = asJsonMap(json['peer']);
    final membersRaw = json['members'];
    final members = <UserModel>[];
    if (membersRaw is List) {
      for (final m in membersRaw) {
        final map = asJsonMap(m);
        if (map != null && (map['_id'] != null || map['id'] != null)) {
          members.add(UserModel.fromJson(map));
        }
      }
    }
    return ChannelModel(
      id: id.toString(),
      spaceId: json['spaceId']?.toString(),
      name: json['name'] as String? ?? 'channel',
      description: json['description'] as String? ?? '',
      type: ChannelType.fromString(json['type'] as String?),
      isPrivate: json['isPrivate'] as bool? ?? false,
      lastMessage: () {
        final lm = asJsonMap(json['lastMessage']);
        return lm != null ? LastMessagePreview.fromJson(lm) : null;
      }(),
      position: json['position'] as int? ?? 0,
      peer: peerJson != null ? UserModel.fromJson(peerJson) : null,
      members: members,
      isNeedl: json['isNeedl'] == true,
    );
  }

  final String id;
  final String? spaceId;
  final String name;
  final String description;
  final ChannelType type;
  final bool isPrivate;
  final LastMessagePreview? lastMessage;
  final int position;
  final UserModel? peer;
  final List<UserModel> members;

  /// Server-provided multi-person DM flag (Slack-style MPIM).
  final bool isNeedl;

  bool get isDirect => type == ChannelType.direct;

  /// 1:1 DM vs multi-person Needl vs notes-to-self.
  /// Space channels (non-null [spaceId]) are never Needls.
  bool get isGroupDm {
    if (!isDirect) return false;
    if (spaceId != null && spaceId!.isNotEmpty) return false;
    return isNeedl || members.length > 2;
  }

  bool get isSelfNotes =>
      isDirect && members.length == 1;

  String get displayName {
    if (isDirect) {
      if (isGroupDm) {
        // Prefer a custom rename when it is not just one peer's name.
        final stored = name.trim();
        final otherNames = members
            .map((m) => m.displayName.trim())
            .where((n) => n.isNotEmpty)
            .toList();
        final joined = otherNames.take(4).join(', ');
        final looksLikeSinglePeer =
            otherNames.any((n) => stored == n) || stored.isEmpty;
        if (stored.isNotEmpty &&
            stored != 'channel' &&
            stored.toLowerCase() != 'direct message' &&
            !looksLikeSinglePeer) {
          return stored;
        }
        if (joined.isNotEmpty) return joined;
        if (stored.isNotEmpty &&
            stored != 'channel' &&
            stored.toLowerCase() != 'direct message') {
          return stored;
        }
        return 'Needl';
      }
      if (name.isNotEmpty &&
          name != 'channel' &&
          name.toLowerCase() != 'direct message') {
        return name;
      }
      if (peer != null && peer!.displayName.trim().isNotEmpty) {
        return peer!.displayName;
      }
      if (isSelfNotes) return 'Notes to self';
      return 'Direct message';
    }
    return name.startsWith('#') ? name : '#$name';
  }

  ChannelModel copyWith({
    String? id,
    String? spaceId,
    String? name,
    String? description,
    ChannelType? type,
    bool? isPrivate,
    LastMessagePreview? lastMessage,
    int? position,
    UserModel? peer,
    List<UserModel>? members,
    bool? isNeedl,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      isPrivate: isPrivate ?? this.isPrivate,
      lastMessage: lastMessage ?? this.lastMessage,
      position: position ?? this.position,
      peer: peer ?? this.peer,
      members: members ?? this.members,
      isNeedl: isNeedl ?? this.isNeedl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        spaceId,
        name,
        description,
        type,
        isPrivate,
        lastMessage,
        position,
        peer,
        members,
        isNeedl,
      ];
}
