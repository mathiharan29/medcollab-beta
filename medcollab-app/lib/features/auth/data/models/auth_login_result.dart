import 'package:equatable/equatable.dart';
import 'package:medcollab_app/features/auth/data/models/auth_session_model.dart';

/// Result of OTP verification — session plus routing hint from backend.
class AuthLoginResult extends Equatable {
  const AuthLoginResult({
    required this.session,
    required this.isNewUser,
  });

  final AuthSessionModel session;
  final bool isNewUser;

  @override
  List<Object?> get props => [session, isNewUser];
}
