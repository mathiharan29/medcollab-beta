import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';

/// Standard API envelope from the MedCollab backend.
///
/// Success: `{ success: true, message, data }`
/// Error:   `{ success: false, message, errors }`
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors = const [],
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json)? dataParser,
  ) {
    final rawData = json['data'];
    T? parsedData;

    if (rawData != null && dataParser != null) {
      final map = asJsonMap(rawData);
      if (map != null) {
        parsedData = dataParser(map);
      }
    } else if (rawData == null && dataParser == null) {
      parsedData = null;
    }

    final rawErrors = json['errors'];
    final errors = rawErrors is List
        ? rawErrors
            .whereType<Map<String, dynamic>>()
            .map(ApiFieldError.fromJson)
            .toList()
        : <ApiFieldError>[];

    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: parsedData,
      errors: errors,
    );
  }

  final bool success;
  final String message;
  final T? data;
  final List<ApiFieldError> errors;

  /// Throws [AppException] when `success` is false.
  T requireData() {
    if (!success || data == null) {
      if (errors.isNotEmpty) {
        throw ValidationException(message, errors: errors);
      }
      throw UnknownException(
        message.isNotEmpty ? message : 'Request failed',
      );
    }
    return data as T;
  }
}
