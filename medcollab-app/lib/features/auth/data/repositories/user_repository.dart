import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/auth/data/models/availability_model.dart';
import 'package:medcollab_app/features/auth/data/models/notification_preferences_model.dart';
import 'package:medcollab_app/features/auth/data/models/update_profile_request.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/needl_thread_preview.dart';
import 'package:medcollab_app/features/messages/data/models/user_lookup_result.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

/// User profile API — mirrors backend `user.controller.js`.
class UserRepository extends BaseRepository {
  UserRepository({required super.apiClient});

  /// `GET /api/users/me`
  Future<UserModel> getMe() {
    return execute(
      () => apiClient.get(
        ApiEndpoints.me,
        parser: (json) =>
            UserModel.fromJson(json['user'] as Map<String, dynamic>),
      ),
    );
  }

  /// `PUT /api/users/me` — sets `isOnboarded` when name + role are present.
  Future<UserModel> updateMe(UpdateProfileRequest request) {
    return execute(
      () => apiClient.put(
        ApiEndpoints.me,
        data: request.toJson(),
        parser: (json) =>
            UserModel.fromJson(json['user'] as Map<String, dynamic>),
      ),
    );
  }

  /// `PUT /api/users/me` — notification preferences only.
  Future<UserModel> updateNotificationPreferences(
    NotificationPreferencesModel prefs,
  ) {
    return execute(
      () => apiClient.put(
        ApiEndpoints.me,
        data: {'notifications': prefs.toJson()},
        parser: (json) =>
            UserModel.fromJson(json['user'] as Map<String, dynamic>),
      ),
    );
  }

  /// `PUT /api/users/me` — set Cloudinary avatar URL after upload.
  Future<UserModel> updateAvatarUrl(String avatarUrl) {
    return execute(
      () => apiClient.put(
        ApiEndpoints.me,
        data: {'avatarUrl': avatarUrl},
        parser: (json) =>
            UserModel.fromJson(json['user'] as Map<String, dynamic>),
      ),
    );
  }

  /// Removes the profile photo (REQ 7). The server clears `avatarUrl` and
  /// deletes the stored image.
  Future<UserModel> removeAvatar() {
    return execute(
      () => apiClient.put(
        ApiEndpoints.me,
        data: {'avatarUrl': null},
        parser: (json) =>
            UserModel.fromJson(json['user'] as Map<String, dynamic>),
      ),
    );
  }

  /// `PUT /api/users/me/availability`
  Future<AvailabilityModel> updateAvailability({
    required AvailabilityStatus status,
    DateTime? until,
    String? note,
  }) {
    return execute(
      () => apiClient.put(
        ApiEndpoints.myAvailability,
        data: {
          'status': status.value,
          if (until != null) 'until': until.toIso8601String(),
          if (note != null) 'note': note,
        },
        parser: (json) {
          final availability = json['availability'];
          if (availability is Map) {
            return AvailabilityModel.fromJson(
              Map<String, dynamic>.from(availability),
            );
          }
          throw const UnknownException('Unexpected response format');
        },
      ),
    );
  }

  /// `PUT /api/users/me/fcm-token` — register this device for push.
  Future<void> registerFcmToken(String token) {
    return executeVoid(
      () => apiClient.put(
        ApiEndpoints.myFcmToken,
        data: {'token': token},
      ),
    );
  }

  /// `GET /api/users/lookup?phone=` — find doctor by mobile for DM.
  Future<UserLookupResult> lookupByPhone(String phoneE164) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.lookupUser,
        queryParameters: {'phone': phoneE164},
        parser: (json) => UserLookupResult.fromJson(json),
      ),
    );
  }

  /// `GET /api/users/username-available?u=` — REQ 5 live check.
  Future<({bool available, String? reason})> checkUsername(String username) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.usernameAvailable,
        queryParameters: {'u': username},
        parser: (json) => (
          available: json['available'] == true,
          reason: json['reason'] as String?,
        ),
      ),
    );
  }

  /// `GET /api/users/:id/relationship` — can I message / request / accept?
  Future<UserLookupResult> getRelationship(String userId) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.userRelationship(userId),
        parser: (json) => UserLookupResult.fromJson(json),
      ),
    );
  }

  /// `GET /api/users/me/needl` — thread inbox.
  Future<List<NeedlThreadPreview>> getNeedl() {
    return execute(
      () => apiClient.get(
        ApiEndpoints.needlThreads,
        parser: (json) => parseNestedList(
          json,
          'threads',
          NeedlThreadPreview.fromJson,
        ),
      ),
    );
  }
}
