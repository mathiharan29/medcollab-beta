import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  try {
    final seconds = int.tryParse(
            Platform.environment['VOCLE_DEVICE_DRIVER_SECONDS'] ?? '') ??
        180;
    await integrationDriver(
      timeout: Duration(seconds: seconds),
      writeResponseOnFailure: true,
    ).timeout(Duration(seconds: seconds + 60));
  } catch (error) {
    // Covers connection/extension startup, which integrationDriver's request
    // timeout does not bound. This is infrastructure, never a passing case.
    stderr.writeln(
        'DeviceInfrastructureError: driver setup/request failed (${error.runtimeType})');
    exitCode = 2;
    exit(2);
  }
}
