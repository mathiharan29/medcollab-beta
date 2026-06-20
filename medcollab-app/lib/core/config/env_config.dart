import 'package:flutter/foundation.dart';

import 'package:medcollab_app/core/constants/app_constants.dart';

/// Runtime configuration via `--dart-define` flags and platform defaults.
///
/// Chrome / web: `http://localhost:5000`
/// Android emulator: `http://10.0.2.2:5000`
/// Physical phone: `--dart-define=API_BASE_URL=http://<YOUR_PC_IP>:5000`
abstract final class EnvConfig {
  static const String _apiBaseUrlFromDefine = String.fromEnvironment(
    'API_BASE_URL',
  );

  static const bool _enableApiLogging = bool.fromEnvironment(
    'ENABLE_API_LOGGING',
    defaultValue: true,
  );

  /// REST API base URL (no trailing slash).
  static String get apiBaseUrl {
    if (_apiBaseUrlFromDefine.isNotEmpty) {
      return _apiBaseUrlFromDefine.replaceAll(RegExp(r'/+$'), '');
    }
    return _defaultApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  }

  static String get _defaultApiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5000';
      case TargetPlatform.iOS:
        return 'http://localhost:5000';
      default:
        return AppConstants.defaultApiBaseUrl;
    }
  }

  /// Socket.io connects to the same host as the API (no `/api` prefix).
  static String get socketUrl => apiBaseUrl;

  static bool get enableApiLogging => _enableApiLogging;

  static bool get isProduction =>
      const bool.fromEnvironment('dart.vm.product');
}
