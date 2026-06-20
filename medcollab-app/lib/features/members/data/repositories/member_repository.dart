import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/members/data/models/space_member_model.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

class MemberRepository extends BaseRepository {
  MemberRepository({required super.apiClient});

  /// `GET /api/spaces/:id/members`
  Future<List<SpaceMemberModel>> getSpaceMembers(String spaceId) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.spaceMembers(spaceId),
        parser: (json) =>
            parseNestedList(json, 'members', SpaceMemberModel.fromJson),
      ),
    );
  }

  /// `GET /api/users/search?q=...&spaceId=...`
  Future<List<UserModel>> searchMembers({
    required String query,
    String? spaceId,
  }) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.searchUsers,
        queryParameters: {
          'q': query,
          if (spaceId != null) 'spaceId': spaceId,
        },
        parser: (json) => parseNestedList(json, 'users', UserModel.fromJson),
      ),
    );
  }

  /// `GET /api/users/:id`
  Future<UserModel> getUserById(String userId) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.userById(userId),
        parser: (json) =>
            UserModel.fromJson(json['user'] as Map<String, dynamic>),
      ),
    );
  }
}
