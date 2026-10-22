import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/features/home/data/dashboard_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FR-HOME-01 widget order and visibility survive reload, merge and reset', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final service = DashboardPreferencesService(preferences: storage);
    final defaults = await service.load();
    final custom = [
      defaults.firstWhere((item) => item.id == DashboardWidgetId.quickActions).copyWith(isVisible: false),
      defaults.firstWhere((item) => item.id == DashboardWidgetId.emergency),
    ];
    await service.save(custom);

    final reopened = DashboardPreferencesService(preferences: storage);
    final restored = await reopened.load();
    expect(restored.take(2).map((item) => item.id).toList(), [
      DashboardWidgetId.quickActions, DashboardWidgetId.emergency,
    ]);
    expect(restored.first.isVisible, isFalse);
    expect(restored.map((item) => item.id).toSet(), DashboardWidgetId.values.toSet());

    await reopened.reset();
    final reset = await DashboardPreferencesService(preferences: storage).load();
    expect(reset.map((item) => item.id).toList(),
        DashboardPreferencesService.defaultPreferences.map((item) => item.id).toList());
    expect(reset.firstWhere((item) => item.id == DashboardWidgetId.quickActions).isVisible, isTrue);

    await storage.setString('medcollab_dashboard_widgets_v4', '{corrupt');
    final recovered = await DashboardPreferencesService(preferences: storage).load();
    expect(recovered.map((item) => item.id).toList(),
        DashboardPreferencesService.defaultPreferences.map((item) => item.id).toList());
  });
}
