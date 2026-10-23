import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Color is used by ThemePalette.primary getters.

/// Five clinical accent palettes (Material ColorScheme.primary remap).
/// Screens still using hard-coded [AppColors] stay teal until migrated.
enum ThemePalette {
  teal,
  blue,
  indigo,
  forest,
  slate;

  String get label => switch (this) {
        ThemePalette.teal => 'Vocle teal',
        ThemePalette.blue => 'Clinical blue',
        ThemePalette.indigo => 'Indigo',
        ThemePalette.forest => 'Forest',
        ThemePalette.slate => 'Slate',
      };

  Color get primary => switch (this) {
        ThemePalette.teal => const Color(0xFF00A88F),
        ThemePalette.blue => const Color(0xFF1A6FBF),
        ThemePalette.indigo => const Color(0xFF4F46E5),
        ThemePalette.forest => const Color(0xFF059669),
        ThemePalette.slate => const Color(0xFF475569),
      };

  Color get primaryDark => switch (this) {
        ThemePalette.teal => const Color(0xFF007A68),
        ThemePalette.blue => const Color(0xFF0F4C8A),
        ThemePalette.indigo => const Color(0xFF3730A3),
        ThemePalette.forest => const Color(0xFF047857),
        ThemePalette.slate => const Color(0xFF334155),
      };

  static ThemePalette fromName(String? name) {
    for (final p in ThemePalette.values) {
      if (p.name == name) return p;
    }
    return ThemePalette.teal;
  }
}

class ThemeSettingsState extends Equatable {
  const ThemeSettingsState({
    this.mode = ThemeMode.light,
    this.palette = ThemePalette.teal,
  });

  final ThemeMode mode;
  final ThemePalette palette;

  ThemeSettingsState copyWith({ThemeMode? mode, ThemePalette? palette}) {
    return ThemeSettingsState(
      mode: mode ?? this.mode,
      palette: palette ?? this.palette,
    );
  }

  @override
  List<Object?> get props => [mode, palette];
}

/// Persists Light / Dark / System and the accent palette stub.
class ThemeModeCubit extends Cubit<ThemeSettingsState> {
  ThemeModeCubit() : super(const ThemeSettingsState());

  static const _modeKey = 'vocle_theme_mode';
  static const _paletteKey = 'vocle_theme_palette';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = switch (prefs.getString(_modeKey)) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
      emit(
        ThemeSettingsState(
          mode: mode,
          palette: ThemePalette.fromName(prefs.getString(_paletteKey)),
        ),
      );
    } catch (_) {
      // Keep defaults when prefs are unavailable.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    emit(state.copyWith(mode: mode));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.name);
    } catch (_) {}
  }

  Future<void> setPalette(ThemePalette palette) async {
    emit(state.copyWith(palette: palette));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_paletteKey, palette.name);
    } catch (_) {}
  }
}
