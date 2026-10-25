import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';

class SpaceRepository extends BaseRepository {
  SpaceRepository({required super.apiClient});

  /// `GET /api/spaces`
  Future<List<SpaceModel>> getMySpaces() {
    return execute(
      () => apiClient.get(
        ApiEndpoints.spaces,
        parser: (json) => parseNestedList(json, 'spaces', SpaceModel.fromJson),
      ),
    );
  }

  /// `POST /api/spaces`
  Future<SpaceModel> createSpace({
    required String name,
    SpaceType type = SpaceType.department,
    String description = '',
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.spaces,
        data: {
          'name': name,
          'type': type.value,
          'description': description,
        },
        parser: (json) {
          final space = parseNested(json, 'space', SpaceModel.fromJson);
          final channels =
              parseNestedList(json, 'channels', ChannelModel.fromJson);
          return SpaceModel(
            id: space.id,
            name: space.name,
            type: space.type,
            description: space.description,
            inviteCode: space.inviteCode,
            channels: channels,
            myRole: SpaceRole.owner,
          );
        },
      ),
    );
  }

  /// `POST /api/spaces/join`
  Future<JoinSpaceResult> joinSpace(String inviteCode) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.joinSpace,
        data: {'inviteCode': inviteCode.trim().toUpperCase()},
        parser: (json) {
          if (json['pending'] == true) {
            return JoinSpaceResult.pending(
              spaceId: json['spaceId']?.toString() ?? '',
            );
          }
          final space = parseNested(json, 'space', SpaceModel.fromJson);
          final channels =
              parseNestedList(json, 'channels', ChannelModel.fromJson);
          return JoinSpaceResult.joined(
            SpaceModel(
              id: space.id,
              name: space.name,
              type: space.type,
              description: space.description,
              inviteCode: space.inviteCode,
              channels: channels,
              myRole: space.myRole,
            ),
          );
        },
      ),
    );
  }

  /// `GET /api/spaces/:id/pending`
  Future<List<PendingJoinRequest>> getPendingJoins(String spaceId) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.spacePendingJoins(spaceId),
        parser: (json) {
          final raw = json['pending'];
          if (raw is! List) return <PendingJoinRequest>[];
          return raw
              .map(asJsonMap)
              .whereType<Map<String, dynamic>>()
              .map(PendingJoinRequest.fromJson)
              .toList();
        },
      ),
    );
  }

  /// `POST /api/spaces/:id/pending/:userId/approve`
  Future<SpaceModel> approvePendingJoin(String spaceId, String userId) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.approvePendingJoin(spaceId, userId),
        parser: (json) => parseNested(json, 'space', SpaceModel.fromJson),
      ),
    );
  }

  /// `GET /api/spaces/:id`
  Future<SpaceModel> getSpaceById(String spaceId) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.spaceById(spaceId),
        parser: (json) {
          final raw = json['space'];
          if (raw is! Map<String, dynamic>) {
            throw const UnknownException('Unexpected response format');
          }
          return SpaceModel.fromJson(raw);
        },
      ),
    );
  }

  /// `GET /api/spaces/invite/:code`
  Future<SpaceInvitePreview> previewInvite(String code) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.spaceInvitePreview(code.trim().toUpperCase()),
        parser: (json) {
          final raw = asJsonMap(json['invite']);
          if (raw == null) {
            throw const UnknownException('Unexpected invite response');
          }
          return SpaceInvitePreview.fromJson(raw);
        },
      ),
    );
  }

  /// `POST /api/spaces/:id/invite` — regenerate invite code
  Future<({String inviteCode, String joinUrl})> regenerateInvite(
      String spaceId) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.spaceInvite(spaceId),
        parser: (json) {
          final code = json['inviteCode'] as String? ?? '';
          final url = json['joinUrl'] as String? ??
              'https://medcollab.up.railway.app/join/$code';
          return (inviteCode: code, joinUrl: url);
        },
      ),
    );
  }
}

class JoinSpaceResult {
  const JoinSpaceResult._({
    required this.isPending,
    this.space,
    this.spaceId = '',
  });

  JoinSpaceResult.joined(SpaceModel space)
      : this._(isPending: false, space: space, spaceId: space.id);

  const JoinSpaceResult.pending({required String spaceId})
      : this._(isPending: true, spaceId: spaceId);

  final bool isPending;
  final SpaceModel? space;
  final String spaceId;
}

class SpaceInvitePreview {
  const SpaceInvitePreview({
    required this.inviteCode,
    required this.name,
    required this.type,
    this.description = '',
    this.memberCount = 0,
    this.alreadyMember = false,
    this.joinUrl = '',
  });

  factory SpaceInvitePreview.fromJson(Map<String, dynamic> json) {
    return SpaceInvitePreview(
      inviteCode: json['inviteCode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      alreadyMember: json['alreadyMember'] as bool? ?? false,
      joinUrl: json['joinUrl'] as String? ?? '',
    );
  }

  final String inviteCode;
  final String name;
  final String type;
  final String description;
  final int memberCount;
  final bool alreadyMember;
  final String joinUrl;
}

class PendingJoinRequest {
  const PendingJoinRequest({
    required this.userId,
    required this.displayName,
    this.message = '',
    this.requestedAt,
  });

  factory PendingJoinRequest.fromJson(Map<String, dynamic> json) {
    final user = asJsonMap(json['user']);
    final userId = json['userId']?.toString() ??
        user?['_id']?.toString() ??
        user?['id']?.toString() ??
        '';
    final name = user?['name']?.toString() ??
        user?['displayTitle']?.toString() ??
        'Pending member';
    DateTime? requestedAt;
    final rawDate = json['requestedAt'];
    if (rawDate is String) {
      requestedAt = DateTime.tryParse(rawDate);
    }
    return PendingJoinRequest(
      userId: userId,
      displayName: name,
      message: json['message']?.toString() ?? '',
      requestedAt: requestedAt,
    );
  }

  final String userId;
  final String displayName;
  final String message;
  final DateTime? requestedAt;
}
