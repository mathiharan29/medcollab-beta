// Issue 7 (beta 11-14): inline Reply from the notification shade was stuck
// because the plugin's action receiver was never declared, so Android
// dropped every Reply / Mark-as-read broadcast.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification action receiver is declared (shade Reply works)', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest,
      contains(
          'com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver'),
    );
  });

  test('speech queries are declared (Needl Voice / voice bot on Android 11+)',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.speech.RecognitionService'));
  });
}
