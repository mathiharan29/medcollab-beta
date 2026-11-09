import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Installed version, e.g. "1.0.0 (29)" (F9: Profile showed a stale
/// hard-coded "1.0.0 (15)").
abstract final class AppVersion {
  static String label = AppConstants.appVersionLabel;

  /// Reads the real version from the installed package. Fire-and-forget at
  /// startup; until it resolves the compiled-in fallback is shown.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        label = info.buildNumber.isEmpty
            ? info.version
            : '${info.version} (${info.buildNumber})';
      }
    } catch (_) {
      // Keep the fallback (tests, unsupported platforms).
    }
  }
}
