import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medcollab_app/app.dart';
import 'package:medcollab_app/core/config/app_version.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initial chrome until the first frame: the bottom tab bar is navy in both
  // themes, so the system navigation bar matches it with light icons
  // (REQ 6). ThemeBrightnessSync keeps it in step afterwards.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0D1B3E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  AppDependencies.instance.init();
  // F9: real installed version for Profile / Developer screens (not awaited).
  unawaited(AppVersion.load());

  // Draw the first frame immediately (REQ 13). Push setup (Firebase init,
  // background-message engine, channels, launch notification) used to be
  // awaited here and kept the app blank for several seconds. It now starts
  // once the doctor is signed in (FcmService.registerTokenWithBackend), so
  // the phone/OTP screens are never interrupted by the permission dialog.
  // Notification taps that arrive first are buffered and replayed.
  runApp(const MedCollabApp());
}
