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

  /// `POST /api/spaces/:id/members` (admin/owner) — REQ 2 "Add members".
  /// Returns who was added and who was skipped (already in, privacy).
  Future<AddMembersResult> addMembers({
    required String spaceId,
    required List<String> userIds,
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.spaceMembers(spaceId),
        data: {'userIds': userIds},
        parser: AddMembersResult.fromJson,
      ),
    );
  }

  /// `DELETE /api/spaces/:id/members/:userId` (admin/owner)
  Future<void> removeMember({
    required String spaceId,
    required String userId,
  }) {
    return execute(
      () => apiClient.delete(ApiEndpoints.spaceMember(spaceId, userId)),
    );
  }
}

class AddMembersResult {
  const AddMembersResult({
    required this.addedNames,
    required this.privacySkipped,
    required this.alreadyMembers,
  });

  factory AddMembersResult.fromJson(Map<String, dynamic> json) {
    String nameOf(Map m) =>
        [m['displayTitle'], m['name']]
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .join(' ')
            .trim();
    final added = (json['added'] as List? ?? const [])
        .whereType<Map>()
        .map(nameOf)
        .toList();
    final skipped = (json['skipped'] as List? ?? const []).whereType<Map>();
    return AddMembersResult(
      addedNames: added,
      privacySkipped: skipped
          .where((s) => s['reason'] == 'privacy')
          .map((s) => (s['name'] as String?) ?? 'Doctor')
          .toList(),
      alreadyMembers: skipped
          .where((s) => s['reason'] == 'already_member')
          .map((s) => (s['name'] as String?) ?? 'Doctor')
          .toList(),
    );
  }

  final List<String> addedNames;
  final List<String> privacySkipped;
  final List<String> alreadyMembers;
}
