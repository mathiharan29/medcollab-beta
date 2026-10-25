import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/channels/data/models/channel_detail_model.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

class ChannelRepository extends BaseRepository {
  ChannelRepository({required super.apiClient});

  /// `GET /api/channels/:id`
  Future<ChannelDetailModel> getChannelById(String channelId) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.channelById(channelId),
        parser: (json) {
          final channel = asJsonMap(json['channel']);
          if (channel == null) {
            throw const UnknownException('Unexpected channel response');
          }
          return ChannelDetailModel.fromJson(channel);
        },
      ),
    );
  }

  /// `GET /api/channels/dm`
  Future<List<ChannelModel>> getMyDMs() {
    return execute(
      () => apiClient.get(
        ApiEndpoints.listDms,
        parser: (json) => parseNestedList(json, 'channels', ChannelModel.fromJson),
      ),
    );
  }

  /// `POST /api/channels/dm`
  Future<ChannelModel> createOrGetDM(String userId) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.createDm,
        data: {'userId': userId},
        parser: (json) => parseNested(json, 'channel', ChannelModel.fromJson),
      ),
    );
  }

  /// `POST /api/channels/dm/group` (falls back to `/group-dm`)
  Future<ChannelModel> createGroupDm(List<String> userIds) {
    return execute(() async {
      try {
        return await apiClient.post(
          ApiEndpoints.createGroupDm,
          data: {'userIds': userIds},
          parser: (json) => parseNested(json, 'channel', ChannelModel.fromJson),
        );
      } on NotFoundException {
        return apiClient.post(
          ApiEndpoints.createGroupDmAlias,
          data: {'userIds': userIds},
          parser: (json) => parseNested(json, 'channel', ChannelModel.fromJson),
        );
      }
    });
  }

  /// `POST /api/channels/:id/expand`
  ///
  /// When [history] is `today`, sends the device's local midnight as
  /// `todayStart` so the server filters in phone timezone (Q2).
  Future<ChannelModel> expandDm({
    required String channelId,
    required List<String> userIds,
    required String history, // all | today | none
  }) {
    final payload = <String, dynamic>{
      'userIds': userIds,
      'history': history,
    };
    if (history == 'today') {
      final now = DateTime.now();
      final localMidnight = DateTime(now.year, now.month, now.day);
      payload['todayStart'] = localMidnight.toUtc().toIso8601String();
    }
    return execute(
      () => apiClient.post(
        ApiEndpoints.expandDm(channelId),
        data: payload,
        parser: (json) => parseNested(json, 'channel', ChannelModel.fromJson),
      ),
    );
  }

  /// `PUT /api/channels/:id` — rename group DM (or space channel if admin).
  Future<ChannelModel> renameChannel(String channelId, String name) {
    return execute(
      () => apiClient.put(
        ApiEndpoints.renameChannel(channelId),
        data: {'name': name},
        parser: (json) => parseNested(json, 'channel', ChannelModel.fromJson),
      ),
    );
  }

  /// `GET /api/channels/:id/members`
  Future<List<UserModel>> getChannelMembers(String channelId) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.channelMembers(channelId),
        parser: (json) => parseNestedList(json, 'members', UserModel.fromJson),
      ),
    );
  }

  /// `POST /api/channels/:id/pin/:messageId`
  Future<List<PinnedMessageEntry>> pinMessage(
    String channelId,
    String messageId,
  ) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.pinMessage(channelId, messageId),
        parser: (json) => _parsePinnedList(json),
      ),
    );
  }

  /// `DELETE /api/channels/:id/pin/:messageId`
  Future<List<PinnedMessageEntry>> unpinMessage(
    String channelId,
    String messageId,
  ) {
    return execute(
      () => apiClient.delete(
        ApiEndpoints.pinMessage(channelId, messageId),
        parser: (json) => _parsePinnedList(json),
      ),
    );
  }

  List<PinnedMessageEntry> _parsePinnedList(Map<String, dynamic> json) {
    return parseNestedList(
      json,
      'pinnedMessages',
      PinnedMessageEntry.fromJson,
    );
  }

  /// `GET /api/spaces/:spaceId/channels`
  Future<List<ChannelModel>> getSpaceChannels(String spaceId) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.spaceChannels(spaceId),
        parser: (json) =>
            parseNestedList(json, 'channels', ChannelModel.fromJson),
      ),
    );
  }

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
