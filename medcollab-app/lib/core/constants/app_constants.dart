/// App-wide constants.
abstract final class AppConstants {
  static const String appName = 'Vocle';

  /// Fallback only — the UI shows the installed version via [AppVersion]
  /// (core/config/app_version.dart). Keep in step with `pubspec.yaml`.
  static const String appVersionName = '1.0.0';
  static const int appVersionCode = 31;
  static const String appVersionLabel = '1.0.0 (31)';

  /// Default when no `--dart-define=API_BASE_URL` is set (see [EnvConfig]).
  static const String defaultApiBaseUrl = 'http://localhost:5000';

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

  /// OTP validity window shown in UI (must match backend OTP_EXPIRY_MINUTES default).
  static const int otpValidityMinutes = 5;

  /// Cooldown before user may request Resend OTP.
  static const int otpResendCooldownSeconds = 30;

  /// Dev bypass OTP when backend has OTP_BYPASS=true.
  static const String devBypassOtp = '123456';

  /// Socket reconnect backoff.
  static const Duration socketReconnectDelay = Duration(seconds: 2);
  static const int socketMaxReconnectAttempts = 10;

  /// HTTP timeouts.
  ///
  /// Connect timeout is generous because Railway (and similar hosts) can
  /// "cold start" a sleeping container — the first request after idle may take
  /// 15–40s to get a response while the server boots.
  static const Duration connectTimeout = Duration(seconds: 40);
  static const Duration receiveTimeout = Duration(seconds: 45);

  /// Automatic retry for connection failures (handles server cold starts).
  static const int networkMaxRetries = 3;
  static const Duration networkRetryBaseDelay = Duration(seconds: 2);

  /// Official Vocle pilot contact.
  static const String supportEmail = 'vocle.official@gmail.com';
  static const String instagramHandle = 'thevocle';
  static const String instagramUrl = 'https://instagram.com/thevocle';
}
