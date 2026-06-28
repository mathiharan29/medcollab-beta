import 'dart:convert';

import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';

/// Thin wrapper around MSG91 [OTPWidget] SDK for send / retry / verify.
class Msg91OtpService {
  Msg91OtpService();

  bool _initialized = false;

  void initialize({required String widgetId, required String tokenAuth}) {
    if (_initialized) return;
    OTPWidget.initializeWidget(widgetId, tokenAuth);
    _initialized = true;
  }

  /// Sends OTP via MSG91 widget. Returns request id for verify/retry.
  Future<String> sendOtp(String phoneE164) async {
    _ensureInitialized();
    final response = await OTPWidget.sendOTP({
      'identifier': _toMsg91Identifier(phoneE164),
    });
    return _extractReqId(response);
  }

  Future<void> retryOtp(String reqId) async {
    _ensureInitialized();
    final response = await OTPWidget.retryOTP({'reqId': reqId});
    _ensureSuccess(response, 'Failed to resend OTP');
  }

  /// Verifies OTP with MSG91 and returns the widget access token for the backend.
  Future<String> verifyOtp({
    required String reqId,
    required String otp,
  }) async {
    _ensureInitialized();
    final response = await OTPWidget.verifyOTP({
      'reqId': reqId,
      'otp': otp,
    });
    return _extractAccessToken(response);
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw const UnknownException('MSG91 OTP widget is not configured');
    }
  }

  static String _toMsg91Identifier(String phoneE164) {
    return phoneE164.replaceFirst('+', '');
  }

  static Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is String && response.isNotEmpty) {
      final decoded = jsonDecode(response);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    throw const UnknownException('Unexpected response from MSG91');
  }

  static void _ensureSuccess(dynamic response, String fallbackMessage) {
    final map = _asMap(response);
    final type = map['type']?.toString().toLowerCase();
    if (type != 'success') {
      final message = map['message']?.toString();
      throw UnknownException(message ?? fallbackMessage);
    }
  }

  static String _extractReqId(dynamic response) {
    final map = _asMap(response);
    _ensureSuccess(map, 'Failed to send OTP');

    // sendOTP can return access-token directly (invisible OTP path).
    final directToken =
        map['access-token'] ?? map['accessToken'] ?? map['token'];
    if (directToken is String &&
        directToken.isNotEmpty &&
        _looksLikeAccessToken(directToken)) {
      throw const UnknownException(
        'Phone verified without OTP — restart login and contact support',
      );
    }

    final reqId = map['reqId'] ?? map['requestId'] ?? map['message'];
    if (reqId is String && reqId.isNotEmpty && !_looksLikeAccessToken(reqId)) {
      return reqId;
    }
    throw const UnknownException('MSG91 did not return a request id');
  }

  static String _extractAccessToken(dynamic response) {
    final map = _asMap(response);
    _ensureSuccess(map, 'Invalid OTP');

    final explicit = map['access-token'] ?? map['accessToken'] ?? map['token'];
    if (explicit is String && explicit.isNotEmpty) {
      return explicit;
    }

    final data = map['data'];
    if (data is Map) {
      final nested =
          data['access-token'] ?? data['accessToken'] ?? data['token'];
      if (nested is String && nested.isNotEmpty) {
        return nested;
      }
    }

    // MSG91 widget SDK returns the JWT access token in `message` on verify success.
    final message = map['message'];
    if (message is String && message.isNotEmpty && _looksLikeAccessToken(message)) {
      return message;
    }

    throw const UnknownException('MSG91 did not return an access token');
  }

  /// Distinguish JWT access tokens from short status text or hex reqIds.
  static bool _looksLikeAccessToken(String value) {
    if (value.length < 20) return false;
    if (value.contains(' ')) return false;
    // JWT-style tokens use dot-separated segments; reqIds are usually hex only.
    return value.contains('.') || value.length >= 32;
  }
}
