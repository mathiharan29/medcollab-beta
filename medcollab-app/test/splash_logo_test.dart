// Issue 12 (beta 11-14): the logo on the loading screen had a white box.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/branding_assets.dart';

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<int> _alphaAt(ui.Image img, int x, int y) async {
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return data.getUint8((y * img.width + x) * 4 + 3);
}

void main() {
  test('splash / sign-in logo is a transparent PNG (no white box)', () async {
    expect(BrandingAssets.logo, endsWith('.png'));
    final bytes = File(BrandingAssets.logo).readAsBytesSync();
    expect(bytes[25], 6, reason: 'PNG colour type 6 = RGBA (has alpha)');
    final img = await _decode(BrandingAssets.logo);
    for (final (x, y) in [(0, 0), (img.width - 1, 0), (0, img.height - 1), (img.width - 1, img.height - 1)]) {
      expect(await _alphaAt(img, x, y), 0, reason: 'corner ($x,$y) must be clear');
    }
    // and the wordmark itself is solid (scan a row through "VOCLE")
    final y = (img.height * 0.85).round();
    var solid = 0;
    for (var x = 0; x < img.width; x += 3) {
      if (await _alphaAt(img, x, y) > 200) solid++;
    }
    expect(solid, greaterThan(20));
  });

  test('Android launch images are transparent too', () async {
    for (final p in [
      'android/app/src/main/res/drawable-nodpi/launch_logo.png',
      'android/app/src/main/res/drawable-nodpi/splash_icon.png',
    ]) {
      final img = await _decode(p);
      expect(await _alphaAt(img, 0, 0), 0, reason: p);
    }
    final v31 = File('android/app/src/main/res/values-v31/styles.xml').readAsStringSync();
    expect(v31, contains('windowSplashScreenAnimatedIcon'));
    expect(v31, contains('@color/splash_background'));
  });

  testWidgets('splash shows the logo directly on the page (no white card)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: Image.asset(BrandingAssets.logo))),
    ));
    final src = File('lib/features/auth/presentation/pages/splash_page.dart')
        .readAsStringSync();
    expect(src.contains('color: Colors.white'), isFalse);
  });
}
