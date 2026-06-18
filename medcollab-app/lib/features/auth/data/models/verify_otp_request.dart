import 'package:equatable/equatable.dart';

/// `POST /api/auth/verify-otp` request body.
class VerifyOtpRequest extends Equatable {
  const VerifyOtpRequest({
    required this.phone,
    required this.otp,
  });

  final String phone;
  final String otp;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'otp': otp,
      };

  @override
  List<Object?> get props => [phone, otp];
}
