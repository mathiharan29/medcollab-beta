import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

class ChannelRepository extends BaseRepository {
  ChannelRepository({required super.apiClient});

  /// `POST /api/spaces/:spaceId/channels`
  Future<ChannelModel> createChannel({
    required String spaceId,
    required String name,
    String description = '',
    bool isPrivate = false,
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.spaceChannels(spaceId),
        data: {
          'name': name.trim().toLowerCase().replaceAll(' ', '-'),
          'description': description.trim(),
          'isPrivate': isPrivate,
        },
        parser: (json) =>
            parseNested(json, 'channel', ChannelModel.fromJson),
      ),
    );
  }
}
