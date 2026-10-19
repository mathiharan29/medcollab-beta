import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  try {
    await integrationDriver(
      timeout: const Duration(minutes: 3),
      writeResponseOnFailure: true,
    ).timeout(const Duration(minutes: 4));
  } catch (error) {
    // Covers connection/extension startup, which integrationDriver's request
    // timeout does not bound. This is infrastructure, never a passing case.
    stderr.writeln('DeviceInfrastructureError: driver setup/request failed (${error.runtimeType})');
    exitCode = 2;
    exit(2);
  }
}
