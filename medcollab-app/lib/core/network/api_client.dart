import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/network/api_response.dart';
import 'package:medcollab_app/core/network/auth_interceptor.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';

/// HTTP client for the MedCollab REST API.
///
/// All endpoints return the standard `{ success, message, data }` envelope.
class ApiClient {
  ApiClient({
    required SecureStorageService storage,
    Dio? dio,
  }) : _storage = storage {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: EnvConfig.apiBaseUrl,
            connectTimeout: AppConstants.connectTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    _dio.interceptors.clear();
    _dio.interceptors.add(
      AuthInterceptor(
        storage: _storage,
        dio: _dio,
        refreshToken: _refreshAccessToken,
      ),
    );

    if (EnvConfig.enableApiLogging && !EnvConfig.isProduction) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => developer.log('[Dio] $obj'),
        ),
      );
    }
  }

  final SecureStorageService _storage;
  late final Dio _dio;

  Dio get dio => _dio;

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic> json)? parser,
    Options? options,
  }) async {
    return _request(
      () => _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: options,
      ),
      parser: parser,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic> json)? parser,
    Options? options,
  }) async {
    return _request(
      () => _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      parser: parser,
    );
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic> json)? parser,
    Options? options,
  }) async {
    return _request(
      () => _dio.put<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      parser: parser,
    );
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic> json)? parser,
    Options? options,
  }) async {
    return _request(
      () => _dio.patch<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      parser: parser,
    );
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic> json)? parser,
    Options? options,
  }) async {
    return _request(
      () => _dio.delete<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      parser: parser,
    );
  }

  /// Multipart upload for `POST /api/media/upload`.
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required FormData formData,
    T Function(Map<String, dynamic> json)? parser,
    void Function(int, int)? onSendProgress,
  }) async {
    return _request(
      () => _dio.post<Map<String, dynamic>>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(contentType: 'multipart/form-data'),
      ),
      parser: parser,
    );
  }

  Future<ApiResponse<T>> _request<T>(
    Future<Response<Map<String, dynamic>>> Function() call, {
    T Function(Map<String, dynamic> json)? parser,
  }) async {
    try {
      final response = await call();
      final body = response.data;

      if (body == null) {
        throw const UnknownException('Empty response from server');
      }

      return ApiResponse.fromJson(body, parser);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  AppException _mapDioError(DioException error) {
    final response = error.response;
    final data = response?.data;

    if (data is Map<String, dynamic>) {
      final apiResponse = ApiResponse<dynamic>.fromJson(data, null);
      if (!apiResponse.success) {
        final status = response?.statusCode;
        if (status == 401) {
          return UnauthorizedException(apiResponse.message);
        }
        if (status == 404) {
          return NotFoundException(apiResponse.message);
        }
        if (status == 400 || status == 422) {
          return ValidationException(
            apiResponse.message,
            errors: apiResponse.errors,
          );
        }
        return ServerException(apiResponse.message);
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException('Connection timed out');
      case DioExceptionType.connectionError:
        return NetworkException(
          'Cannot reach the API at ${EnvConfig.apiBaseUrl}. '
          'Start the backend (npm run dev in medcollab-backend). '
          'On a physical phone, use your PC IP: '
          '--dart-define=API_BASE_URL=http://192.168.x.x:5000',
        );
      case DioExceptionType.cancel:
        return const NetworkException('Request cancelled');
      default:
        return NetworkException(
          error.message ?? 'Network request failed',
        );
    }
  }

  /// Called by [AuthInterceptor] on 401 — exchanges refresh token for new access token.
  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: const {'Authorization': ''},
          extra: const {'skipAuth': true, 'skipRefresh': true},
        ),
      );

      final body = response.data;
      if (body == null || body['success'] != true) return null;

      final data = body['data'] as Map<String, dynamic>?;
      final newToken = data?['accessToken'] as String?;
      if (newToken != null) {
        await _storage.saveAccessToken(newToken);
      }
      return newToken;
    } on DioException {
      return null;
    }
  }
}
