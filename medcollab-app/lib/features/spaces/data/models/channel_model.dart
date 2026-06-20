import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
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
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['id'];
    return ChannelModel(
      id: id.toString(),
      spaceId: json['spaceId']?.toString(),
      name: json['name'] as String? ?? 'channel',
      description: json['description'] as String? ?? '',
      type: ChannelType.fromString(json['type'] as String?),
      isPrivate: json['isPrivate'] as bool? ?? false,
      lastMessage: json['lastMessage'] is Map<String, dynamic>
          ? LastMessagePreview.fromJson(
              json['lastMessage'] as Map<String, dynamic>,
            )
          : null,
      position: json['position'] as int? ?? 0,
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

  String get displayName => name.startsWith('#') ? name : '#$name';

  bool get isEmergency => type == ChannelType.emergency;

  @override
  List<Object?> get props =>
      [id, spaceId, name, description, type, isPrivate, lastMessage, position];
}
