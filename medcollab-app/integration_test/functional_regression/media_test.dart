import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:medcollab_app/features/media/data/services/document_open_service.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/channel_chat_cubit.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/mention_composer.dart';
import 'package:path_provider/path_provider.dart';
import 'support/device_harness.dart';
import 'support/provider_inputs.dart';

Future<void> attach(WidgetTester tester, String label) async {
  final attachButton = find.byWidgetPredicate((widget) =>
      widget is IconButton && widget.tooltip == 'Attach');
  await until(tester, () => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      'the native app resumes before opening the attachment menu');
  await until(tester, () => attachButton.hitTestable().evaluate().isNotEmpty &&
      tester.widget<IconButton>(attachButton).onPressed != null,
      'the attachment control is enabled');
  await tester.tap(attachButton);
  await until(tester, () => find.text(label).evaluate().isNotEmpty,
      'the attachment menu exposes $label');
  // A modal's text is built before its slide transition puts it on screen.
  // Settle that transition, then require a pointer-accessible target.
  await tester.pumpAndSettle();
  await until(tester, () => find.text(label).hitTestable().evaluate().isNotEmpty,
      'the attachment menu target is visible and hit-testable');
  await tester.tap(find.text(label));
  await tester.pump();
  checkFramework(tester);
}

void main() {
  deviceMain();
  if (devicePhase != 'media')
    throw DeviceInfrastructureError('Unknown media phase');
  deviceCase('FR-MED-08', (tester) async {
    await initializeDevice();
    await deviceStorage.clearAll();
    final images = DeviceImagePicker();
    final documents = DeviceFilePicker();
    ImagePickerPlatform.instance = images;
    FilePicker.platform = documents;
    await launch(tester, session: 'A', currentChat: true);
    final f = await fixture();
    final channel = chatId(f);
    await openChat(tester, channel);
    final before = await control('media-counts', {'channelId': channel});
    for (final label in ['Photos & videos', 'Camera', 'Document / PDF']) {
      if (label == 'Document / PDF') {
        documents.inputs.add(null);
      } else {
        images.inputs.add(null);
      }
      await attach(tester, label);
      await tester.pumpAndSettle();
    }
    final afterCancel = await control('media-counts', {'channelId': channel});
    expect(afterCancel['uploadRequests'], before['uploadRequests']);
    expect(afterCancel['messageCount'], before['messageCount']);
    final composer = tester.element(find.byType(MentionAwareComposer));
    final chat = composer.read<ChannelChatCubit>();
    expect(chat.state.isSending, false);

    // PDF bytes are a complete synthetic document from the test-owned control
    // fixture. Delivery and the native opener are independent of message policy.
    final fixtureBytes = await control('media-fixtures');
    final pdf = Uint8List.fromList(base64Decode(fixtureBytes['pdf'] as String));
    documents.inputs.add(PlatformFile(
        name: 'synthetic-device.pdf', size: pdf.length, bytes: pdf));
    await attach(tester, 'Document / PDF');
    await until(tester, () => !chat.state.isSending && chat.state.messages.any(
        (message) => message.content.fileName == 'synthetic-device.pdf'),
        'PDF send completes or exposes a typed failure');
    expect(find.text('synthetic-device.pdf'), findsWidgets,
        reason: 'Selected PDF has a visible preview/file entry');
    final uploaded = await deps.mediaRepository.uploadFile(
        bytes: pdf,
        fileName: 'synthetic-opener.pdf',
        mimeType: 'application/pdf');
    safeDeviceOrigin(Uri.parse(uploaded.url).origin);
    final downloaded = await Dio().get<List<int>>(uploaded.url,
        options: Options(responseType: ResponseType.bytes));
    expect(downloaded.data, orderedEquals(pdf));
    final observe = control('observe-opener');
    await DocumentOpenService.open(composer,
        url: uploaded.url,
        fileName: 'synthetic-opener.pdf',
        mimeType: 'application/pdf');
    final opened = await observe;
    expect(opened['externalActivityObserved'], true);
    expect(opened['localUriObserved'], true);
    final temporary = await getTemporaryDirectory();
    expect(
        await File('${temporary.path}/vocle_synthetic-opener.pdf')
            .readAsBytes(),
        orderedEquals(pdf));
    observations.add(
        'Picker cancellation caused zero upload/message requests; exact PDF delivery and native external activity were verified.');

    final png = Uint8List.fromList(base64Decode(fixtureBytes['png'] as String));
    final pngPath = '${temporary.path}/synthetic-device.png';
    await File(pngPath).writeAsBytes(png, flush: true);
    images.inputs.add(XFile(pngPath));
    await attach(tester, 'Photos & videos');
    await until(tester, () => !chat.state.isSending && chat.state.messages.any(
        (message) => message.content.fileName == 'synthetic-device.png'), 'image send terminates');
    expect(
        chat.state.messages.any(
            (message) => message.content.fileName == 'synthetic-device.png'),
        true);
    final image = chat.state.messages.firstWhere(
        (message) => message.content.fileName == 'synthetic-device.png');
    if (image.localOnly) {
      expect(chat.state.localMediaByMessageId[image.id], orderedEquals(png),
          reason: 'A local preview retains the exact selected bytes');
    } else {
      safeDeviceOrigin(Uri.parse(image.content.mediaUrl!).origin);
      final imageBytes = await Dio().get<List<int>>(image.content.mediaUrl!,
          options: Options(responseType: ResponseType.bytes));
      expect(imageBytes.data, orderedEquals(png));
    }

    final video =
        Uint8List.fromList(base64Decode(fixtureBytes['mp4'] as String));
    final videoPath = '${temporary.path}/synthetic-device.mp4';
    await File(videoPath).writeAsBytes(video, flush: true);
    images.inputs.add(XFile(videoPath));
    await attach(tester, 'Photos & videos');
    await until(tester, () => !chat.state.isSending && chat.state.messages.any(
        (message) => message.content.fileName == 'synthetic-device.mp4'), 'video send terminates');
    await until(tester, () => find.text('synthetic-device.mp4').evaluate().isNotEmpty,
        'the selected video preview is rendered');
    expect(find.text('synthetic-device.mp4'), findsWidgets);

    final unsupported =
        Uint8List.fromList('Synthetic unsupported document'.codeUnits);
    documents.inputs.add(PlatformFile(
        name: 'synthetic-unsupported.txt',
        size: unsupported.length,
        bytes: unsupported));
    await attach(tester, 'Document / PDF');
    await until(tester, () => !chat.state.isSending && chat.state.messages.any(
        (message) => message.content.fileName == 'synthetic-unsupported.txt'),
        'unsupported input does not hang the composer');
    expect(chat.state.error, isNotNull);
    expect(find.text('Failed to send'), findsWidgets);
    expect(
        (await storedMessages(channel)).where((message) =>
            message['content']['fileName'] == 'synthetic-unsupported.txt'),
        isEmpty);

    await control('camera-permission', {'granted': false});
    images.denied = true;
    await attach(tester, 'Camera');
    // Required recoverable UI: an unhandled permission exception is a FAIL.
    checkFramework(tester);
    expect(find.byType(TextField), findsWidgets);
    await control('camera-permission', {'granted': true});
    images.denied = false;
    images.inputs.add(XFile(pngPath));
    await attach(tester, 'Camera');
    await until(tester, () => !chat.state.isSending,
        'granted camera input is usable after denial');
    final delivered = await storedMessages(channel);
    observations.add(
        'Selected image/PDF/video entries and error recovery observed using real chat upload/send operations.');
    final missing = [
      'synthetic-device.png',
      'synthetic-device.pdf',
      'synthetic-device.mp4'
    ]
        .where((name) =>
            !delivered.any((message) => message['content']['fileName'] == name))
        .toList();
    await cleanupDevice(tester);
    if (missing.isNotEmpty)
      throw DeviceDecision(
          'Q5: actual local upload-to-message incompatibility for ${missing.join(', ')}; no fake-provider success substituted.');
  });
}
