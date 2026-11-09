import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for integration_test/vocle_screen_tour_test.dart.
/// Screenshots → build/tour/*.png, timings + errors → build/tour/report.json.
Future<void> main() async {
  final dir = Directory('build/tour');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('build/tour/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      final out = File('build/tour/report.json');
      final clean = Map<String, dynamic>.from(data ?? const {})
        ..remove('screenshots');
      await out.writeAsString(const JsonEncoder.withIndent('  ').convert(clean));
      stdout.writeln('Screen tour report: ${out.path}');
    },
  );
}
