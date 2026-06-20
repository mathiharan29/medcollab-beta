import 'package:equatable/equatable.dart';

/// `POST /api/media/upload` response payload.
class MediaUploadResult extends Equatable {
  const MediaUploadResult({
    required this.url,
    this.thumbnailUrl,
    required this.publicId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.width,
    this.height,
  });

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      publicId: json['publicId'] as String,
      fileName: json['fileName'] as String? ?? 'file',
      fileSize: json['fileSize'] as int? ?? 0,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  final String url;
  final String? thumbnailUrl;
  final String publicId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final int? width;
  final int? height;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  @override
  List<Object?> get props =>
      [url, thumbnailUrl, publicId, fileName, fileSize, mimeType, width, height];
}
