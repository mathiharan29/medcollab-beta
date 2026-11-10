import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_theme.dart';
import 'package:medcollab_app/core/theme/theme_brightness_sync.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          key: const Key('probe'),
          color: AppColors.backgroundApp,
          child: Text('x', style: TextStyle(color: AppColors.textPrimary)),
        ),
      );
}

Widget _app(ThemeModeCubit cubit) => BlocProvider.value(
      value: cubit,
      child: BlocBuilder<ThemeModeCubit, ThemeSettingsState>(
        builder: (context, s) {
          AppColors.setBrightness(s.brightness);
          return MaterialApp(
            theme: AppTheme.lightFor(s.palette),
            darkTheme: AppTheme.darkFor(s.palette),
            themeMode: s.mode,
            builder: (context, child) => ThemeBrightnessSync(child: child!),
            home: const _Probe(),
          );
        },
      ),
    );

Color _probeColor(WidgetTester t) =>
    (t.widget<Container>(find.byKey(const Key('probe'))).color)!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Light -> Dark -> Light repaints app colours', (t) async {
    final cubit = ThemeModeCubit();
    await t.pumpWidget(_app(cubit));
    expect(_probeColor(t), AppColorsLight.backgroundApp);

    await cubit.setMode(ThemeMode.dark);
    await t.pumpAndSettle();
    expect(AppColors.isDark, isTrue);
    expect(_probeColor(t), AppColorsDark.backgroundApp);
    expect(Theme.of(t.element(find.byKey(const Key('probe')))).brightness,
        Brightness.dark);

    await cubit.setMode(ThemeMode.light);
    await t.pumpAndSettle();
    expect(_probeColor(t), AppColorsLight.backgroundApp);
  });

  testWidgets('Dark persists across restart', (t) async {
    final cubit = ThemeModeCubit();
    await cubit.setMode(ThemeMode.dark);
    final restarted = ThemeModeCubit();
    await restarted.load();
    expect(restarted.state.mode, ThemeMode.dark);
    await t.pumpWidget(_app(restarted));
    await t.pumpAndSettle();
    expect(_probeColor(t), AppColorsDark.backgroundApp);
  });
}
