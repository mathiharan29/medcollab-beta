import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';

/// Space member with role — from `GET /api/spaces/:id/members`.
class SpaceMemberModel extends Equatable {
  const SpaceMemberModel({
    required this.user,
    required this.spaceRole,
    this.isOnline = false,
  });

  factory SpaceMemberModel.fromJson(Map<String, dynamic> json) {
    return SpaceMemberModel(
      user: UserModel.fromJson(json),
      spaceRole: SpaceRole.fromString(json['spaceRole'] as String?),
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }

  final UserModel user;
  final SpaceRole spaceRole;
  final bool isOnline;

  SpaceMemberModel copyWith({UserModel? user, SpaceRole? spaceRole, bool? isOnline}) {
    return SpaceMemberModel(
      user: user ?? this.user,
      spaceRole: spaceRole ?? this.spaceRole,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [user, spaceRole, isOnline];
}
