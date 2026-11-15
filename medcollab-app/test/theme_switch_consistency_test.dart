// Issue 1 (beta 11-14): switching Light ⇄ Dark resized text and moved rows.
// Guards: both themes share every size/padding; the switch is a single
// frame (no ThemeData lerp); the dark palette is neutral (no navy cast).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_theme.dart';
import 'package:medcollab_app/core/theme/theme_brightness_sync.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';
import 'package:medcollab_app/core/theme/theme_switch_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<double?> _geom(TextStyle? s) =>
    [s?.fontSize, s?.height, s?.fontWeight?.value.toDouble(), s?.letterSpacing];

Map<String, Object?> _geometry(ThemeData t) {
  final tt = t.textTheme;
  final nav = t.navigationBarTheme.labelTextStyle;
  return {
    for (final e in {
      'displayLarge': tt.displayLarge,
      'displayMedium': tt.displayMedium,
      'headlineMedium': tt.headlineMedium,
      'titleLarge': tt.titleLarge,
      'titleMedium': tt.titleMedium,
      'titleSmall': tt.titleSmall,
      'bodyLarge': tt.bodyLarge,
      'bodyMedium': tt.bodyMedium,
      'bodySmall': tt.bodySmall,
      'labelLarge': tt.labelLarge,
      'labelMedium': tt.labelMedium,
      'labelSmall': tt.labelSmall,
    }.entries)
      e.key: _geom(e.value),
    'listTitle': _geom(t.listTileTheme.titleTextStyle),
    'listSubtitle': _geom(t.listTileTheme.subtitleTextStyle),
    'listPadding': t.listTileTheme.contentPadding,
    'listMinV': t.listTileTheme.minVerticalPadding,
    'navLabelSel': _geom(nav?.resolve({WidgetState.selected})),
    'navLabel': _geom(nav?.resolve({})),
    'navHeight': t.navigationBarTheme.height,
    'appBarH': t.appBarTheme.toolbarHeight,
    'appBarTitle': _geom(t.appBarTheme.titleTextStyle),
    'inputPad': t.inputDecorationTheme.contentPadding,
    'inputHint': _geom(t.inputDecorationTheme.hintStyle),
    'filledPad': t.filledButtonTheme.style?.padding?.resolve({}),
    'filledText': _geom(t.filledButtonTheme.style?.textStyle?.resolve({})),
    'outlinedPad': t.outlinedButtonTheme.style?.padding?.resolve({}),
    'chipPad': t.chipTheme.padding,
    'chipLabel': _geom(t.chipTheme.labelStyle),
    'iconBtnMin': t.iconButtonTheme.style?.minimumSize?.resolve({}),
    'searchMin': t.searchBarTheme.constraints,
    'searchText': _geom(t.searchBarTheme.textStyle?.resolve({})),
    'dialogTitle': _geom(t.dialogTheme.titleTextStyle),
    'snackText': _geom(t.snackBarTheme.contentTextStyle),
    'density': t.visualDensity,
    'iconSize': t.iconTheme.size,
  };
}

class _Page extends StatelessWidget {
  const _Page();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          children: const [
            ListTile(key: Key('tile'), title: Text('Light'), subtitle: Text('sub')),
            ListTile(title: Text('Dark')),
          ],
        ),
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final palette in ThemePalette.values) {
    test('light and dark share every size (${palette.name})', () {
      final light = _geometry(AppTheme.lightFor(palette));
      final dark = _geometry(AppTheme.darkFor(palette));
      for (final k in light.keys) {
        expect(dark[k], light[k], reason: '$k differs between light and dark');
      }
    });
  }

  test('theme text colours follow their own theme, not the global flag', () {
    AppColors.setBrightness(Brightness.dark);
    final light = AppTheme.lightFor(ThemePalette.teal);
    expect(light.textTheme.bodyLarge!.color, AppColorsLight.textPrimary);
    AppColors.setBrightness(Brightness.light);
    final dark = AppTheme.darkFor(ThemePalette.teal);
    expect(dark.textTheme.bodyLarge!.color, AppColorsDark.textPrimary);
  });

  test('dark palette is neutral graphite (no navy/blue cast)', () {
    for (final c in [
      AppColorsDark.backgroundApp,
      AppColorsDark.surfaceCard,
      AppColorsDark.chrome,
      AppColorsDark.borderDefault,
    ]) {
      final r = (c.r * 255).round(), b = (c.b * 255).round();
      expect((b - r).abs() <= 8, isTrue,
          reason: '${c.toARGB32().toRadixString(16)} has a blue cast');
    }
  });

  testWidgets('switch is one frame and list rows keep their size',
      (tester) async {
    final cubit = ThemeModeCubit();
    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: BlocBuilder<ThemeModeCubit, ThemeSettingsState>(
        builder: (context, s) {
          AppColors.setBrightness(s.brightness);
          return MaterialApp(
            theme: AppTheme.lightFor(s.palette),
            darkTheme: AppTheme.darkFor(s.palette),
            themeMode: s.mode,
            themeAnimationDuration: Duration.zero,
            builder: (c, child) => ThemeSwitchTransition(
              child: ThemeBrightnessSync(child: child!),
            ),
            home: const _Page(),
          );
        },
      ),
    ));
    final tile = find.byKey(const Key('tile'));
    final lightSize = tester.getSize(tile);
    final lightTitle = tester.getSize(find.text('Light'));

    await cubit.setMode(ThemeMode.dark);
    await tester.pump(); // exactly one frame
    expect(Theme.of(tester.element(tile)).brightness, Brightness.dark);
    expect(tester.getSize(tile), lightSize);
    expect(tester.getSize(find.text('Light')), lightTitle);
    await tester.pumpAndSettle();
    expect(ThemeSwitchController.instance.snapshot.value, isNull);

    await cubit.setMode(ThemeMode.light);
    await tester.pump();
    expect(Theme.of(tester.element(tile)).brightness, Brightness.light);
    expect(tester.getSize(tile), lightSize);
    await tester.pumpAndSettle();
  });
}
