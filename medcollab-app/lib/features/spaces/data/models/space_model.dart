import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

class SpaceModel extends Equatable {
  const SpaceModel({
    required this.id,
    required this.name,
    this.type = SpaceType.department,
    this.description = '',
    this.inviteCode,
    this.channels = const [],
    this.myRole = SpaceRole.member,
  });

  factory SpaceModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['id'];
    final channelsRaw = json['channels'];
    return SpaceModel(
      id: id.toString(),
      name: json['name'] as String? ?? 'Space',
      type: SpaceType.fromString(json['type'] as String?),
      description: json['description'] as String? ?? '',
      inviteCode: json['inviteCode'] as String?,
      channels: channelsRaw is List
          ? channelsRaw
              .whereType<Map<String, dynamic>>()
              .map(ChannelModel.fromJson)
              .toList()
          : const [],
      myRole: SpaceRole.fromString(json['myRole'] as String?),
    );
  }

  final String id;
  final String name;
  final SpaceType type;
  final String description;
  final String? inviteCode;
  final List<ChannelModel> channels;
  final SpaceRole myRole;

  @override
  List<Object?> get props =>
      [id, name, type, description, inviteCode, channels, myRole];
}
