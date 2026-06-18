import 'package:equatable/equatable.dart';

enum AuthStatus {
  unknown,
  loading,
  unauthenticated,
  otpSent,
  needsProfile,
  authenticated,
}

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// App launch — restore session or show login.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Submit 10-digit local phone number (without country code).
final class AuthPhoneSubmitted extends AuthEvent {
  const AuthPhoneSubmitted(this.localPhone);

  final String localPhone;

  @override
  List<Object?> get props => [localPhone];
}

final class AuthOtpSubmitted extends AuthEvent {
  const AuthOtpSubmitted(this.otp);

  final String otp;

  @override
  List<Object?> get props => [otp];
}

final class AuthProfileSubmitted extends AuthEvent {
  const AuthProfileSubmitted({
    required this.name,
    required this.role,
    this.speciality,
    this.institution,
  });

  final String name;
  final String role;
  final String? speciality;
  final String? institution;

  @override
  List<Object?> get props => [name, role, speciality, institution];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

final class AuthErrorDismissed extends AuthEvent {
  const AuthErrorDismissed();
}

final class AuthOtpResendRequested extends AuthEvent {
  const AuthOtpResendRequested();
}

final class AuthChangePhoneRequested extends AuthEvent {
  const AuthChangePhoneRequested();
}
