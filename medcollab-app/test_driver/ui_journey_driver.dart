import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Driver for integration_test/vocle_ui_journey_test.dart.
/// Writes per-step timings to build/ui_journey_report.json.
Future<void> main() async {
  await integrationDriver(
    timeout: const Duration(minutes: 12),
    responseDataCallback: (data) async {
      final out = File('build/ui_journey_report.json');
      await out.create(recursive: true);
      await out.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data ?? const {}),
      );
      stdout.writeln('UI journey report: ${out.path}');
    },
  );
}
