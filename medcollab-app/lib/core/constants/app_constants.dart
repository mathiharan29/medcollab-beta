/// App-wide constants.
abstract final class AppConstants {
  static const String appName = 'MedCollab';

  /// Default API base URL for local development.
  /// Override with `--dart-define=API_BASE_URL=https://your-api.railway.app`
  static const String defaultApiBaseUrl = 'http://10.0.2.2:5000';

  /// Pagination limits — mirrors backend `PAGINATION`.
  static const int messagesPageSize = 30;
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  /// Media limits — mirrors backend `MEDIA`.
  static const int maxFileSizeMb = 25;
  static const int maxFileSizeBytes = maxFileSizeMb * 1024 * 1024;

  /// India default country code for phone auth.
  static const String defaultCountryCode = '+91';

  /// OTP length enforced by backend.
  static const int otpLength = 6;

  /// Dev bypass OTP when backend has OTP_BYPASS=true.
  static const String devBypassOtp = '123456';

  /// Socket reconnect backoff.
  static const Duration socketReconnectDelay = Duration(seconds: 2);
  static const int socketMaxReconnectAttempts = 10;

  /// HTTP timeouts.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
