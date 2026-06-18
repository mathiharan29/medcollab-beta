/// Typed application errors mapped from API and network failures.
sealed class AppException implements Exception {
  const AppException(this.message, {this.errors = const []});

  final String message;
  final List<ApiFieldError> errors;

  @override
  String toString() => 'AppException: $message';
}

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.errors});
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException(
      [super.message = 'Session expired. Please log in again.',]);
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {super.errors});
}

final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Resource not found']);
}

final class ServerException extends AppException {
  const ServerException([super.message = 'Server error. Please try again.']);
}

final class UnknownException extends AppException {
  const UnknownException([super.message = 'Something went wrong']);
}

/// Validation error item from `{ field, message }` in API errors array.
class ApiFieldError {
  const ApiFieldError({required this.field, required this.message});

  factory ApiFieldError.fromJson(Map<String, dynamic> json) {
    return ApiFieldError(
      field: json['field'] as String? ?? json['path'] as String? ?? '',
      message: json['message'] as String? ?? 'Invalid value',
    );
  }

  final String field;
  final String message;
}
