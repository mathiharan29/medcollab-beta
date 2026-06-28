/// `POST /api/auth/verify-msg91-token` request body.
class VerifyMsg91TokenRequest {
  const VerifyMsg91TokenRequest({
    required this.phone,
    required this.accessToken,
  });

  final String phone;
  final String accessToken;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'accessToken': accessToken,
      };
}
