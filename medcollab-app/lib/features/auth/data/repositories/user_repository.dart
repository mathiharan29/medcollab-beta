import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/auth/data/models/availability_model.dart';
import 'package:medcollab_app/features/auth/data/models/update_profile_request.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
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
}
