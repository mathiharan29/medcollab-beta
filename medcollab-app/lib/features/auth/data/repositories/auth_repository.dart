import 'dart:async';

import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/chat/chat_transcript_cache.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/storage/bookmark_service.dart';
import 'package:medcollab_app/core/storage/draft_message_service.dart';
import 'package:medcollab_app/core/storage/recent_items_service.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/models/auth_login_result.dart';
import 'package:medcollab_app/features/auth/data/models/auth_session_model.dart';
import 'package:medcollab_app/features/auth/data/models/refresh_token_response.dart';
import 'package:medcollab_app/features/auth/data/models/request_otp_request.dart';
import 'package:medcollab_app/features/auth/data/models/request_otp_response.dart';
import 'package:medcollab_app/features/auth/data/models/verify_msg91_token_request.dart';
import 'package:medcollab_app/features/auth/data/models/verify_otp_request.dart';
import 'package:medcollab_app/features/auth/data/models/verify_otp_response.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth API — mirrors backend `auth.controller.js`.
class AuthRepository extends BaseRepository {
  AuthRepository({
    required super.apiClient,
    required SecureStorageService storage,
    required SocketClient socketClient,
    DraftMessageService? draftMessageService,
    BookmarkService? bookmarkService,
    RecentItemsService? recentItemsService,
  })  : _storage = storage,
        _socketClient = socketClient,
        _draftMessageService = draftMessageService,
        _bookmarkService = bookmarkService,
        _recentItemsService = recentItemsService;

  final SecureStorageService _storage;
  final SocketClient _socketClient;
  final DraftMessageService? _draftMessageService;
  final BookmarkService? _bookmarkService;
  final RecentItemsService? _recentItemsService;

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
    unawaited(_connectSocketInBackground(session.accessToken));

    return AuthLoginResult(session: session, isNewUser: result.isNewUser);
  }

  /// `POST /api/auth/verify-msg91-token`
  ///
  /// Exchanges MSG91 widget access token for MedCollab JWT pair.
  Future<AuthLoginResult> verifyMsg91Token(
      VerifyMsg91TokenRequest request) async {
    final result = await execute(
      () => apiClient.post(
        ApiEndpoints.verifyMsg91Token,
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
    unawaited(_connectSocketInBackground(session.accessToken));

    return AuthLoginResult(session: session, isNewUser: result.isNewUser);
  }

  Future<void> _connectSocketInBackground(String accessToken) async {
    try {
      await _socketClient.connect(accessToken);
      _socketClient.syncSpaceRooms();
    } catch (_) {
      // Socket connects in background; chat/presence retry on resume.
    }
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
      await clearLocalSession();
    }
  }

  /// Drop socket + tokens without calling the logout API (expired refresh).
  Future<void> clearLocalSession() async {
    // Tokens first so session checks pass even if draft/prefs wipe hangs
    // under a stressed Android emulator (FR-JRN-05).
    await _storage.clearSession();
    try {
      await _socketClient.disconnect();
    } catch (_) {}
    final drafts = _draftMessageService;
    final bookmarks = _bookmarkService;
    final recentItems = _recentItemsService;
    await Future.wait([
      if (drafts != null) drafts.clearAll(),
      if (bookmarks != null) bookmarks.clearAll(),
      if (recentItems != null) recentItems.clearAll(),
      _clearSharedAccountCaches(),
    ]);
    ChatTranscriptCache.clearAll();
  }

  Future<void> _clearSharedAccountCaches() async {
    final preferences = await SharedPreferences.getInstance();
    const exactKeys = {
      'medcollab_bookmarks_v1',
      'medcollab_recent_spaces_v1',
      'medcollab_recent_channels_v1',
      'medcollab_pinned_home_v1',
      'medcollab_dashboard_widgets_v4',
      'vocle_feedback',
      'vocle_feature_requests',
      'vocle_support_bugs',
    };
    const prefixes = {'draft_msg_', 'vocle_notif_lines_'};
    final keys = preferences
        .getKeys()
        .where(
          (key) =>
              exactKeys.contains(key) ||
              prefixes.any((prefix) => key.startsWith(prefix)),
        )
        .toList();
    await Future.wait(keys.map(preferences.remove));
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
      // Resume refresh denied — drop local session and notify auth UI (FR-RT-06).
      try {
        await _socketClient.disconnect();
      } catch (_) {}
      await _storage.clearSession();
      apiClient.onSessionExpired?.call();
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
