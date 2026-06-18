import 'package:equatable/equatable.dart';

/// `POST /api/auth/refresh` response `data` payload.
class RefreshTokenResponse extends Equatable {
  const RefreshTokenResponse({required this.accessToken});

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      accessToken: json['accessToken'] as String,
    );
  }

  final String accessToken;

  @override
  List<Object?> get props => [accessToken];
}
