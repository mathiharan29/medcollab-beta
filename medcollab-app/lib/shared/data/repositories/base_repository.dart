import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/core/network/api_response.dart';

/// Base class for data-layer repositories.
///
/// Centralises API envelope parsing and error propagation so feature
/// repositories stay thin.
abstract class BaseRepository {
  BaseRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Executes a request and returns parsed data, throwing [AppException] on failure.
  Future<T> execute<T>(Future<ApiResponse<T>> Function() request) async {
    try {
      final response = await request();
      return response.requireData();
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  /// Parses a single nested key from the `data` object.
  T parseNested<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final nested = data[key];
    if (nested is! Map<String, dynamic>) {
      throw const UnknownException('Unexpected response format');
    }
    return fromJson(nested);
  }

  /// Parses a list nested under a key in `data`.
  List<T> parseNestedList<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final nested = data[key];
    if (nested is! List) return [];
    return nested.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }
}
