import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Picks images from gallery or camera, and documents (PDF etc.) for chat.
class MediaPickerService {
  MediaPickerService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<PickedAttachment?> pickFromGallery() async {
    try {
      final file = await _imagePicker.pickMedia(
        imageQuality: 85,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? _guessMediaMime(file.name);
      return PickedAttachment(
        bytes: bytes,
        fileName: file.name,
        mimeType: mime,
      );
    } on PlatformException {
      // Permission denial / cancel must leave the composer usable (FR-MED-08).
      return null;
    }
  }

  Future<PickedAttachment?> captureFromCamera() async {
    if (kIsWeb) return null;
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return PickedAttachment(
        bytes: bytes,
        fileName: file.name,
        mimeType: _guessImageMime(file.name),
      );
    } on PlatformException {
      // Synthetic/device camera denial must not crash the chat (FR-MED-08).
      return null;
    }
  }

  Future<PickedAttachment?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    return PickedAttachment(
      bytes: bytes,
      fileName: file.name,
      mimeType: _guessDocMime(file.name, file.extension),
    );
  }

  String _guessMediaMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.3gp')) return 'video/3gpp';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  String _guessImageMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _guessDocMime(String name, String? ext) {
    final lower = (ext ?? name).toLowerCase();
    if (lower.contains('pdf')) return 'application/pdf';
    if (lower.contains('docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.contains('doc')) return 'application/msword';
    if (lower.contains('txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}

class PickedAttachment {
  const PickedAttachment({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
}
