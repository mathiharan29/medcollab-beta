import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/utils/qr_decode_utils.dart';

/// Live camera preview that auto-detects QR codes (zxing2 on captured frames).
class LiveQrScanner extends StatefulWidget {
  const LiveQrScanner({
    required this.onCodeFound,
    super.key,
  });

  final ValueChanged<String> onCodeFound;

  @override
  State<LiveQrScanner> createState() => _LiveQrScannerState();
}

class _LiveQrScannerState extends State<LiveQrScanner> {
  CameraController? _controller;
  Timer? _scanTimer;
  bool _processing = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _initError = 'No camera found');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      _scanTimer = Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => _scanFrame(),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _initError = 'Camera unavailable');
      }
    }
  }

  Future<void> _scanFrame() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return;
    }
    if (controller.value.isTakingPicture) return;

    _processing = true;
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final raw = QrDecodeUtils.decodeFromBytes(bytes);
      if (raw != null && raw.isNotEmpty && mounted) {
        _scanTimer?.cancel();
        widget.onCodeFound(raw);
      }
    } catch (_) {
      // Ignore frame failures — next tick retries.
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _initError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.tealPrimary, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(24),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Point at the Vocle invite QR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
