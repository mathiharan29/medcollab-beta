import 'package:equatable/equatable.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';

/// Locally persisted auth session after successful OTP verification.
class AuthSessionModel extends Equatable {
  const AuthSessionModel({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserModel user;

  @override
  List<Object?> get props => [accessToken, refreshToken, user];
}
