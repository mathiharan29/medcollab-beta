import 'package:equatable/equatable.dart';

/// `POST /api/auth/request-otp` response `data` payload.
class RequestOtpResponse extends Equatable {
  const RequestOtpResponse({
    required this.phone,
    required this.expiresInMinutes,
  });

  factory RequestOtpResponse.fromJson(Map<String, dynamic> json) {
    return RequestOtpResponse(
      phone: json['phone'] as String,
      expiresInMinutes: json['expiresInMinutes'] as int? ?? 10,
    );
  }

  final String phone;
  final int expiresInMinutes;

  @override
  List<Object?> get props => [phone, expiresInMinutes];
}
