import 'package:dio/dio.dart';
import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/features/media/data/models/media_upload_result.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

/// Media upload API — mirrors backend `media.controller.js`.
class MediaRepository extends BaseRepository {
  MediaRepository({required super.apiClient});

  /// `POST /api/media/upload` (multipart)
  Future<MediaUploadResult> uploadFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String context = 'message',
    void Function(int sent, int total)? onProgress,
  }) {
    return execute(
      () => apiClient.upload(
        ApiEndpoints.uploadMedia,
        formData: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: fileName),
          'context': context,
        }),
        parser: MediaUploadResult.fromJson,
        onSendProgress: onProgress,
      ),
    );
  }
}
