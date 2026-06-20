import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/models/auth_login_result.dart';
import 'package:medcollab_app/features/auth/data/models/auth_session_model.dart';
import 'package:medcollab_app/features/auth/data/models/refresh_token_response.dart';
import 'package:medcollab_app/features/auth/data/models/request_otp_request.dart';
import 'package:medcollab_app/features/auth/data/models/request_otp_response.dart';
import 'package:medcollab_app/features/auth/data/models/verify_otp_request.dart';
import 'package:medcollab_app/features/auth/data/models/verify_otp_response.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

/// Auth API — mirrors backend `auth.controller.js`.
class AuthRepository extends BaseRepository {
  AuthRepository({
    required super.apiClient,
    required SecureStorageService storage,
    required SocketClient socketClient,
  })  : _storage = storage,
        _socketClient = socketClient;

  final SecureStorageService _storage;
  final SocketClient _socketClient;

  /// `POST /api/auth/request-otp`
  Future<RequestOtpResponse> requestOtp(RequestOtpRequest request) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.requestOtp,
        data: request.toJson(),
        parser: RequestOtpResponse.fromJson,
      ),
    );
  }

  /// `POST /api/auth/verify-otp`
  ///
  /// Persists tokens and connects the socket on success.
  Future<AuthLoginResult> verifyOtp(VerifyOtpRequest request) async {
    final result = await execute(
      () => apiClient.post(
        ApiEndpoints.verifyOtp,
        data: request.toJson(),
        parser: VerifyOtpResponse.fromJson,
      ),
    );

    final session = AuthSessionModel(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      user: result.user,
    );

    await _persistSession(session);
    await _socketClient.connect(session.accessToken);

    return AuthLoginResult(session: session, isNewUser: result.isNewUser);
  }

  /// `POST /api/auth/refresh`
  Future<String> refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      throw const UnauthorizedException();
    }

    final response = await execute(
      () => apiClient.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
        parser: RefreshTokenResponse.fromJson,
      ),
    );

    await _storage.saveAccessToken(response.accessToken);
    return response.accessToken;
  }

  /// `POST /api/auth/logout`
  Future<void> logout({String? fcmToken}) async {
    try {
      await apiClient.post(
        ApiEndpoints.logout,
        data: fcmToken != null ? {'fcmToken': fcmToken} : null,
      );
    } finally {
      await _socketClient.disconnect();
      await _storage.clearSession();
    }
  }

  Future<bool> hasSession() => _storage.hasSession();

  Future<String?> getAccessToken() => _storage.getAccessToken();

  /// Reconnect socket using stored access token (app resume).
  Future<void> restoreSocketConnection() async {
    await ensureSocketConnected();
  }

  /// Connect socket, refreshing the JWT first if the stored token is stale.
  Future<void> ensureSocketConnected() async {
    var token = await getAccessToken();
    if (token == null) return;

    if (_socketClient.isConnected) {
      _socketClient.syncSpaceRooms();
      return;
    }

    await _socketClient.connect(token);
    if (_socketClient.isConnected) {
      _socketClient.syncSpaceRooms();
      return;
    }

    try {
      final refreshed = await refreshAccessToken();
      await _socketClient.updateAccessToken(refreshed);
      _socketClient.syncSpaceRooms();
    } catch (_) {
      // Session may have expired — AuthBloc handles via API interceptor.
    }
  }

  Future<void> _persistSession(AuthSessionModel session) {
    return _storage.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      userId: session.user.id,
    );
  }
}
