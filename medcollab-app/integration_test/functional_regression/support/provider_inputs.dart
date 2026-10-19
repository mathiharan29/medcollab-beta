// Test-owned provider inputs. Native secure storage, preferences, local
// notifications and file opening are intentionally real in this device lane.
import 'dart:async';
import 'dart:collection';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class DeviceFirebase extends FirebasePlatform {
  final FirebaseAppPlatform _app = FirebaseAppPlatform(
      '[DEFAULT]',
      const FirebaseOptions(
          apiKey: 'synthetic-no-provider',
          appId: 'synthetic-device',
          messagingSenderId: 'synthetic',
          projectId: 'vocle-regression-local'));
  @override
  List<FirebaseAppPlatform> get apps => [_app];
  @override
  FirebaseAppPlatform app([String name = '[DEFAULT]']) => _app;
  @override
  Future<FirebaseAppPlatform> initializeApp(
          {String? name, FirebaseOptions? options}) async =>
      _app;
}

class DeviceMessaging extends FirebaseMessagingPlatform {
  String? token;
  bool granted = false;
  RemoteMessage? initialMessage;
  final refresh = StreamController<String>.broadcast();
  final permissionStates = <AuthorizationStatus>[];
  int initialReads = 0;
  int tokenDeletes = 0;
  @override
  FirebaseMessagingPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  bool get isAutoInitEnabled => false;
  @override
  void registerBackgroundMessageHandler(BackgroundMessageHandler handler) {}
  @override
  Future<String?> getToken(
          {String? vapidKey, String? serviceWorkerScriptPath}) async =>
      granted ? token : null;
  @override
  Future<void> deleteToken() async {
    tokenDeletes++;
    token = null;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<RemoteMessage?> getInitialMessage() async {
    initialReads++;
    final result = initialMessage;
    initialMessage = null;
    return result;
  }

  @override
  Future<NotificationSettings> requestPermission(
      {bool alert = true,
      bool announcement = false,
      bool badge = true,
      bool carPlay = false,
      bool criticalAlert = false,
      bool providesAppNotificationSettings = false,
      bool provisional = false,
      bool sound = true}) async {
    final status =
        granted ? AuthorizationStatus.authorized : AuthorizationStatus.denied;
    permissionStates.add(status);
    return NotificationSettings(
        alert: AppleNotificationSetting.enabled,
        announcement: AppleNotificationSetting.disabled,
        authorizationStatus: status,
        badge: AppleNotificationSetting.enabled,
        carPlay: AppleNotificationSetting.disabled,
        lockScreen: AppleNotificationSetting.enabled,
        notificationCenter: AppleNotificationSetting.enabled,
        showPreviews: AppleShowPreviewSetting.always,
        timeSensitive: AppleNotificationSetting.disabled,
        criticalAlert: AppleNotificationSetting.disabled,
        sound: AppleNotificationSetting.enabled,
        providesAppNotificationSettings: AppleNotificationSetting.disabled);
  }
}

class DeviceImagePicker extends ImagePickerPlatform {
  final inputs = Queue<XFile?>();
  bool denied = false;
  int selections = 0;
  XFile? _next() {
    selections++;
    if (denied)
      throw PlatformException(
          code: 'camera_access_denied', message: 'Synthetic permission denial');
    if (inputs.isEmpty) throw StateError('Missing test-owned picker input');
    return inputs.removeFirst();
  }

  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async {
    final value = _next();
    return value == null ? [] : [value];
  }

  @override
  Future<XFile?> getImageFromSource(
          {required ImageSource source,
          ImagePickerOptions options = const ImagePickerOptions()}) async =>
      _next();
}

class DeviceFilePicker extends FilePicker {
  final inputs = Queue<PlatformFile?>();
  @override
  Future<FilePickerResult?> pickFiles(
      {String? dialogTitle,
      String? initialDirectory,
      FileType type = FileType.any,
      List<String>? allowedExtensions,
      Function(FilePickerStatus)? onFileLoading,
      bool allowCompression = true,
      int compressionQuality = 30,
      bool allowMultiple = false,
      bool withData = false,
      bool withReadStream = false,
      bool lockParentWindow = false,
      bool readSequential = false}) async {
    if (inputs.isEmpty) throw StateError('Missing test-owned document input');
    final file = inputs.removeFirst();
    return file == null ? null : FilePickerResult([file]);
  }
}

class DeviceCamera extends CameraPlatform {
  bool denied = true;
  String? frame;
  final initialized = StreamController<CameraInitializedEvent>.broadcast();
  @override
  Future<List<CameraDescription>> availableCameras() async {
    if (denied)
      throw CameraException(
          'CameraAccessDenied', 'Synthetic denied camera input');
    return [
      const CameraDescription(
          name: 'synthetic',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0)
    ];
  }

  @override
  Future<int> createCamera(
          CameraDescription description, ResolutionPreset? preset,
          {bool enableAudio = false}) async =>
      42;
  @override
  Future<void> initializeCamera(int cameraId,
      {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {
    initialized.add(CameraInitializedEvent(
        cameraId, 400, 400, ExposureMode.auto, true, FocusMode.auto, true));
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      initialized.stream;
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => const Stream.empty();
  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) =>
      const Stream.empty();
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<XFile> takePicture(int cameraId) async => XFile(frame!);
  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose(int cameraId) async {}
}
