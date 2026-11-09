import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';

/// Effective brightness for a theme mode before MaterialApp resolves it.
Brightness effectiveBrightness(ThemeMode mode) => switch (mode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };

/// Keeps [AppColors] in step with the resolved theme (REQ 6).
///
/// [AppColors] neutral tokens are read when widgets build. When the
/// brightness changes (Appearance setting, or the phone's dark mode while
/// the app follows "System default"), every element is marked for rebuild
/// once so no screen keeps colours from the previous theme.
class ThemeBrightnessSync extends StatelessWidget {
  const ThemeBrightnessSync({required this.child, super.key});

  final Widget child;

  static void _rebuildEverything() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  }

  /// Brightness this widget last rendered with. Tracked separately from
  /// [AppColors] because the app pre-sets [AppColors] before MaterialApp
  /// builds, so [AppColors.setBrightness] alone would report "no change".
  static Brightness? _lastRendered;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    AppColors.setBrightness(brightness);
    final previous = _lastRendered;
    _lastRendered = brightness;
    if (previous != null && previous != brightness) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildEverything());
    }
    // Android navigation bar follows the theme; status-bar icons are set
    // per screen (navy headers need light icons in both themes).
    final dark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor:
            dark ? AppColorsDark.backgroundApp : AppColorsLight.navyPrimary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    return child;
  }
}

/// Convenience used by [MedCollabApp].
extension ThemeSettingsBrightness on ThemeSettingsState {
  Brightness get brightness => effectiveBrightness(mode);
}
