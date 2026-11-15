import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Generic driver for `flutter drive --profile` runs of integration tests.
/// Screenshots taken in the test with `binding.takeScreenshot(name)` are
/// written to `$VOCLE_SHOTS` (default `build/device-shots`) as PNGs — exact
/// frames, unlike host `adb screencap`, which lags behind the test.
Future<void> main() => integrationDriver(
      onScreenshot: (name, image, [args]) async {
        final dir = Directory(
            Platform.environment['VOCLE_SHOTS'] ?? 'build/device-shots');
        await dir.create(recursive: true);
        await File('${dir.path}${Platform.pathSeparator}$name.png')
            .writeAsBytes(image);
        return true;
      },
    );
