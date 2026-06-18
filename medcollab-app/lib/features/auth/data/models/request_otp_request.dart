import 'package:equatable/equatable.dart';

/// `POST /api/auth/request-otp` request body.
class RequestOtpRequest extends Equatable {
  const RequestOtpRequest({required this.phone});

  /// E.164 format: `+919876543210`
  final String phone;

  Map<String, dynamic> toJson() => {'phone': phone};

  @override
  List<Object?> get props => [phone];
}
