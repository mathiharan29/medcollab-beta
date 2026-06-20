import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

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
          final channels = parseNestedList(json, 'channels', ChannelModel.fromJson);
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
  Future<SpaceModel> joinSpace(String inviteCode) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.joinSpace,
        data: {'inviteCode': inviteCode.trim().toUpperCase()},
        parser: (json) {
          final space = parseNested(json, 'space', SpaceModel.fromJson);
          final channels = parseNestedList(json, 'channels', ChannelModel.fromJson);
          return SpaceModel(
            id: space.id,
            name: space.name,
            type: space.type,
            description: space.description,
            inviteCode: space.inviteCode,
            channels: channels,
            myRole: space.myRole,
          );
        },
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
}
