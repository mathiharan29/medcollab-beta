// REQ 6: neutral colour tokens follow the active theme, and switching the
// theme repaints widgets that would not otherwise rebuild (const subtrees).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/core/theme/theme_brightness_sync.dart';

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('card'),
        color: AppColors.surfaceCard,
        child: Text('Ward note', style: AppTextStyles.cardTitle),
      );
}

void main() {
  tearDown(() => AppColors.setBrightness(Brightness.light));

  test('tokens resolve per brightness; brand colours are shared', () {
    AppColors.setBrightness(Brightness.light);
    expect(AppColors.surfaceCard, AppColorsLight.surfaceCard);
    expect(AppColors.textPrimary, AppColorsLight.textPrimary);
    AppColors.setBrightness(Brightness.dark);
    expect(AppColors.surfaceCard, AppColorsDark.surfaceCard);
    expect(AppColors.textPrimary, AppColorsDark.textPrimary);
    expect(AppColors.backgroundApp, AppColorsDark.backgroundApp);
    expect(AppColors.tealPrimary, AppColorsLight.tealPrimary);
    expect(AppColors.emergencyRed, AppColorsLight.emergencyRed);
  });

  test('dark text has readable contrast on dark surfaces', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    expect(contrast(AppColorsDark.textPrimary, AppColorsDark.surfaceCard),
        greaterThan(7), reason: 'primary text AAA');
    expect(contrast(AppColorsDark.textSecondary, AppColorsDark.surfaceCard),
        greaterThan(4.5), reason: 'secondary text AA');
    expect(contrast(AppColorsDark.textMuted, AppColorsDark.backgroundApp),
        greaterThan(3), reason: 'muted text/large');
  });

  testWidgets('switching theme repaints const subtrees with new colours',
      (tester) async {
    final mode = ValueNotifier(ThemeMode.light);
    addTearDown(mode.dispose);
    await tester.pumpWidget(ValueListenableBuilder<ThemeMode>(
      valueListenable: mode,
      builder: (_, m, __) {
        AppColors.setBrightness(effectiveBrightness(m));
        return MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: m,
          builder: (_, child) => ThemeBrightnessSync(child: child!),
          home: const Scaffold(body: _Card()),
        );
      },
    ));
    Color cardColor() =>
        tester.widget<Container>(find.byKey(const Key('card'))).color!;
    Color textColor() => tester.widget<Text>(find.text('Ward note')).style!.color!;

    expect(cardColor(), AppColorsLight.surfaceCard);

    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(cardColor(), AppColorsDark.surfaceCard);
    expect(textColor(), AppColorsDark.textPrimary);

    mode.value = ThemeMode.light;
    await tester.pumpAndSettle();
    expect(cardColor(), AppColorsLight.surfaceCard);
    expect(textColor(), AppColorsLight.textPrimary);
  });
}
