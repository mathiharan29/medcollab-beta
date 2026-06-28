import 'package:flutter/foundation.dart';

import 'package:medcollab_app/core/constants/app_constants.dart';

/// Runtime configuration via `--dart-define` flags and platform defaults.
///
/// **Production APK must pass:**
/// `--dart-define=API_BASE_URL=https://your-api.up.railway.app`
/// `--dart-define=MSG91_WIDGET_ID=...`
/// `--dart-define=MSG91_WIDGET_TOKEN=...` (OTP widget token from MSG91 dashboard)
///
/// Optional: `--dart-define=SOCKET_URL=...` if socket host differs from REST.
///
/// Platform defaults (dev only — not for release APK):
/// - Web: `http://localhost:5000`
/// - Android emulator: `http://10.0.2.2:5000`
/// - Physical phone: `--dart-define=API_BASE_URL=http://<PC_IP>:5000`
abstract final class EnvConfig {
  static const String _apiBaseUrlFromDefine = String.fromEnvironment(
    'API_BASE_URL',
  );

  static const String _socketUrlFromDefine = String.fromEnvironment(
    'SOCKET_URL',
  );

  static const String _msg91WidgetId = String.fromEnvironment(
    'MSG91_WIDGET_ID',
  );

  static const String _msg91WidgetToken = String.fromEnvironment(
    'MSG91_WIDGET_TOKEN',
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

  /// Socket.io host (no `/api` prefix). Defaults to [apiBaseUrl].
  static String get socketUrl {
    if (_socketUrlFromDefine.isNotEmpty) {
      return _socketUrlFromDefine.replaceAll(RegExp(r'/+$'), '');
    }
    return apiBaseUrl;
  }

  static bool get enableApiLogging => _enableApiLogging;

  static bool get isProduction =>
      const bool.fromEnvironment('dart.vm.product');

  /// True when a production API URL was injected at build time.
  static bool get hasProductionApiUrl => _apiBaseUrlFromDefine.isNotEmpty;

  /// MSG91 OTP widget — used on mobile production builds (no DLT template).
  static String get msg91WidgetId => _msg91WidgetId;

  static String get msg91WidgetToken => _msg91WidgetToken;

  /// Widget OTP on Android/iOS when widget id + token are provided at build time.
  static bool get useMsg91Widget =>
      !kIsWeb &&
      _msg91WidgetId.isNotEmpty &&
      _msg91WidgetToken.isNotEmpty;
}
