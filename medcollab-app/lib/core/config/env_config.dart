import 'package:medcollab_app/core/constants/app_constants.dart';

/// Runtime configuration via `--dart-define` flags.
///
/// Example:
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://api.medcollab.app
/// ```
abstract final class EnvConfig {
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: AppConstants.defaultApiBaseUrl,
  );

  static const bool _enableApiLogging = bool.fromEnvironment(
    'ENABLE_API_LOGGING',
    defaultValue: true,
  );

  /// REST API base URL (no trailing slash).
  static String get apiBaseUrl => _apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  /// Socket.io connects to the same host as the API (no `/api` prefix).
  static String get socketUrl => apiBaseUrl;

  static bool get enableApiLogging => _enableApiLogging;

  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
}
