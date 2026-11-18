import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';

/// Full-screen square crop (WhatsApp-style) before uploading avatar.
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({required this.imageBytes, super.key});

  final Uint8List imageBytes;

  static Future<Uint8List?> open(
    BuildContext context, {
    required Uint8List imageBytes,
  }) {
    return Navigator.of(context, rootNavigator: true).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => AvatarCropPage(imageBytes: imageBytes),
        fullscreenDialog: true,
      ),
    );
  }

  /// Pick from gallery or camera then crop; returns image bytes or null.
  static Future<Uint8List?> pickAndCrop(
    BuildContext context, {
    ImageSource source = ImageSource.gallery,
  }) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (file == null || !context.mounted) return null;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return null;
    return open(context, imageBytes: bytes);
  }

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final _cropController = CropController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust photo'),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() => _busy = true);
                    _cropController.crop();
                  },
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Done',
                    style: TextStyle(
                      color: AppColors.tealPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: _cropController,
              aspectRatio: 1,
              withCircleUi: true,
              interactive: true,
              baseColor: Colors.black,
              maskColor: Colors.black.withValues(alpha: 0.55),
              onCropped: (cropped) {
                if (!mounted) return;
                Navigator.of(context).pop(cropped);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              'Drag and pinch to fill the circle — like WhatsApp profile photos.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
