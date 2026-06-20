import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/availability_model.dart';
import 'package:medcollab_app/features/auth/data/models/notification_preferences_model.dart';

/// User profile — maps to backend `User.toPublicProfile()`.
///
/// Note: `isOnboarded` / `isVerified` / `phone` are not in `toPublicProfile()`
/// but may appear in future API versions. [isNewUser] from verify-otp drives
/// onboarding routing until then.
class UserModel extends Equatable {
  const UserModel({
    required this.id,
    this.phone,
    this.name,
    this.displayTitle,
    this.role = UserRole.intern,
    this.speciality,
    this.pgYear,
    this.institution,
    this.city,
    this.avatarUrl,
    this.bio = '',
    this.availability = const AvailabilityModel(),
    this.notifications = const NotificationPreferencesModel(),
    this.lastSeenAt,
    this.isVerified = false,
    this.isOnboarded = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['id'];
    return UserModel(
      id: id.toString(),
      phone: json['phone'] as String?,
      name: json['name'] as String?,
      displayTitle: json['displayTitle'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      speciality: json['speciality'] as String?,
      pgYear: json['pgYear'] as int?,
      institution: json['institution'] as String?,
      city: json['city'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String? ?? '',
      availability: json['availability'] is Map<String, dynamic>
          ? AvailabilityModel.fromJson(
              json['availability'] as Map<String, dynamic>,
            )
          : const AvailabilityModel(),
      notifications: json['notifications'] is Map<String, dynamic>
          ? NotificationPreferencesModel.fromJson(
              json['notifications'] as Map<String, dynamic>,
            )
          : const NotificationPreferencesModel(),
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.tryParse(json['lastSeenAt'].toString())
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
      isOnboarded: json['isOnboarded'] as bool? ?? false,
    );
  }

  final String id;
  final String? phone;
  final String? name;
  final String? displayTitle;
  final UserRole role;
  final String? speciality;
  final int? pgYear;
  final String? institution;
  final String? city;
  final String? avatarUrl;
  final String bio;
  final AvailabilityModel availability;
  final NotificationPreferencesModel notifications;
  final DateTime? lastSeenAt;
  final bool isVerified;
  final bool isOnboarded;

  String get displayName {
    if (name != null && name!.isNotEmpty) {
      final prefix = displayTitle != null && displayTitle!.isNotEmpty
          ? '$displayTitle '
          : '';
      return '$prefix$name';
    }
    return phone ?? 'Doctor';
  }

  /// True when the user has completed onboarding on the server.
  bool get hasMinimumProfile =>
      isOnboarded || (name != null && name!.trim().length >= 2);

  Map<String, dynamic> toJson() => {
        '_id': id,
        if (phone != null) 'phone': phone,
        if (name != null) 'name': name,
        if (displayTitle != null) 'displayTitle': displayTitle,
        'role': role.value,
        if (speciality != null) 'speciality': speciality,
        if (pgYear != null) 'pgYear': pgYear,
        if (institution != null) 'institution': institution,
        if (city != null) 'city': city,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'bio': bio,
        'availability': availability.toJson(),
        'notifications': notifications.toJson(),
        if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
        'isVerified': isVerified,
        'isOnboarded': isOnboarded,
      };

  UserModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? displayTitle,
    UserRole? role,
    String? speciality,
    int? pgYear,
    String? institution,
    String? city,
    String? avatarUrl,
    String? bio,
    AvailabilityModel? availability,
    NotificationPreferencesModel? notifications,
    DateTime? lastSeenAt,
    bool? isVerified,
    bool? isOnboarded,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      displayTitle: displayTitle ?? this.displayTitle,
      role: role ?? this.role,
      speciality: speciality ?? this.speciality,
      pgYear: pgYear ?? this.pgYear,
      institution: institution ?? this.institution,
      city: city ?? this.city,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      availability: availability ?? this.availability,
      notifications: notifications ?? this.notifications,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isVerified: isVerified ?? this.isVerified,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phone,
        name,
        displayTitle,
        role,
        speciality,
        pgYear,
        institution,
        city,
        avatarUrl,
        bio,
        availability,
        notifications,
        lastSeenAt,
        isVerified,
        isOnboarded,
      ];
}
