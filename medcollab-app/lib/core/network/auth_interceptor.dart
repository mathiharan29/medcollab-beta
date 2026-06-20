import 'package:dio/dio.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';

typedef SessionExpiredCallback = void Function();
typedef AccessTokenRefreshedCallback = Future<void> Function(String accessToken);
typedef TokenRefreshCallback = Future<String?> Function();

/// Attaches JWT to requests and silently refreshes on 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureStorageService storage,
    required Dio dio,
    required Future<String?> Function() refreshToken,
    this.onSessionExpired,
    this.onAccessTokenRefreshed,
  })  : _storage = storage,
        _dio = dio,
        _refreshToken = refreshToken;

  final SecureStorageService _storage;
  final Dio _dio;
  final Future<String?> Function() _refreshToken;
  final SessionExpiredCallback? onSessionExpired;
  final AccessTokenRefreshedCallback? onAccessTokenRefreshed;

  static const _skipAuthKey = 'skipAuth';
  static const _skipRefreshKey = 'skipRefresh';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra[_skipAuthKey] == true;
    if (!skipAuth) {
      try {
        final token = await _storage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {
        // Corrupt/missing storage — proceed without token; API returns 401.
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final skipRefresh = err.requestOptions.extra[_skipRefreshKey] == true;
    final isUnauthorized = err.response?.statusCode == 401;

    if (!isUnauthorized || skipRefresh) {
      return handler.next(err);
    }

    final newToken = await _refreshToken();
    if (newToken == null) {
      await _storage.clearSession();
      onSessionExpired?.call();
      return handler.next(err);
    }

    final retryOptions = err.requestOptions;
    retryOptions.headers['Authorization'] = 'Bearer $newToken';

    try {
      final response = await _dio.fetch<dynamic>(retryOptions);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }
}
