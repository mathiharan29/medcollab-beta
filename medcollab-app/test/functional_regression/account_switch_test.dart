import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/core/network/api_response.dart';
import 'package:medcollab_app/core/storage/bookmark_service.dart';
import 'package:medcollab_app/core/storage/draft_message_service.dart';
import 'package:medcollab_app/core/storage/recent_items_service.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'fakes/chat_fakes.dart';

class _LocalLogoutApi extends ApiClient {
  _LocalLogoutApi(SecureStorageService storage) : super(storage: storage);
  int logoutCalls = 0;

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic> json)? parser,
    Options? options,
  }) async {
    expect(path, ApiEndpoints.logout);
    logoutCalls++;
    return ApiResponse<T>(success: true, message: 'Synthetic logout');
  }
}

class _LogoutSocket extends FakeSocketClient {
  int disconnectCalls = 0;
  @override
  Future<void> disconnect() async { disconnectCalls++; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FR-OFF-06: account switch captures local data exposure [NEEDS_DECISION Q11]', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final secure = SecureStorageService(storage: const FlutterSecureStorage());
    final api = _LocalLogoutApi(secure);
    final socket = _LogoutSocket();
    final auth = AuthRepository(apiClient: api, storage: secure, socketClient: socket);
    final drafts = DraftMessageService();
    final bookmarks = BookmarkService(prefs: preferences);
    final recent = RecentItemsService(prefs: preferences);

    await secure.saveSession(
      accessToken: 'synthetic-access-a',
      refreshToken: 'synthetic-refresh-a',
      userId: 'doctor-a',
    );
    await drafts.saveDraft('channel-a', 'Doctor A synthetic draft');
    await bookmarks.save(BookmarkItem(
      id: 'message-a',
      type: BookmarkType.message,
      title: 'Doctor A bookmark',
      subtitle: 'Synthetic',
      savedAt: DateTime.utc(2026, 10, 10),
      channelId: 'channel-a',
      messageId: 'message-a',
    ));
    await recent.recordChannelVisit(
      spaceId: 'space-a',
      channelId: 'channel-a',
      channelName: 'Doctor A channel',
      spaceName: 'Synthetic space',
    );

    await auth.logout();
    expect(api.logoutCalls, 1);
    expect(socket.disconnectCalls, 1);
    expect(await secure.hasSession(), isFalse);
    expect(await secure.getUserId(), isNull);
    await secure.saveSession(
      accessToken: 'synthetic-access-b',
      refreshToken: 'synthetic-refresh-b',
      userId: 'doctor-b',
    );
    expect(await secure.getUserId(), 'doctor-b');
    expect(await secure.getAccessToken(), 'synthetic-access-b');
    expect(await secure.getRefreshToken(), 'synthetic-refresh-b');

    // Capture current behavior. Q11 decides whether these should be cleared,
    // retained with an account key, or otherwise hidden from Doctor B.
    final exposedDraft = await DraftMessageService().getDraft('channel-a');
    final exposedBookmarks = await BookmarkService(prefs: preferences).getAll();
    final exposedRecent = await RecentItemsService(prefs: preferences).getRecentChannels();
    expect(exposedDraft, 'Doctor A synthetic draft');
    expect(exposedBookmarks.map((item) => item.id), ['message-a']);
    expect(exposedRecent.map((item) => item.channelId), ['channel-a']);
    await socket.disposeFake();
  });
}
