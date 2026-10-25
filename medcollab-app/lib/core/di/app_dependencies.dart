import 'package:medcollab_app/core/auth/msg91_otp_service.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/core/notifications/fcm_service.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/realtime/typing_presence.dart';
import 'package:medcollab_app/core/router/app_router.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/storage/bookmark_service.dart';
import 'package:medcollab_app/core/storage/draft_message_service.dart';
import 'package:medcollab_app/core/storage/recent_items_service.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/home/data/dashboard_preferences_service.dart';
import 'package:medcollab_app/features/media/data/repositories/media_repository.dart';
import 'package:medcollab_app/features/members/data/repositories/member_repository.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_request_repository.dart';
import 'package:medcollab_app/features/messages/data/repositories/thread_repository.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';
import 'package:medcollab_app/features/shell/presentation/cubit/nav_badges_cubit.dart';
import 'package:medcollab_app/features/search/data/repositories/search_repository.dart';
import 'package:medcollab_app/features/spaces/data/repositories/space_repository.dart';

class AppDependencies {
  AppDependencies._();

  static final AppDependencies instance = AppDependencies._();

  late final SecureStorageService secureStorage;
  late final ApiClient apiClient;
  late final SocketClient socketClient;
  late final AuthRepository authRepository;
  late final UserRepository userRepository;
  late final SpaceRepository spaceRepository;
  late final MessageRepository messageRepository;
  late final MessageRequestRepository messageRequestRepository;
  late final ThreadRepository threadRepository;
  late final MediaRepository mediaRepository;
  late final ChannelRepository channelRepository;
  late final MemberRepository memberRepository;
  late final HandoffRepository handoffRepository;
  late final DashboardPreferencesService dashboardPreferencesService;
  late final NotificationRepository notificationRepository;
  late final NotificationBadgeCubit notificationBadgeCubit;
  late final NavBadgesCubit navBadgesCubit;
  late final SearchRepository searchRepository;
  late final BookmarkService bookmarkService;
  late final RecentItemsService recentItemsService;
  late final DraftMessageService draftMessageService;
  late final PresenceCubit presenceCubit;
  late final FcmService fcmService;
  late final Msg91OtpService? msg91OtpService;
  late final AuthBloc authBloc;
  late final AppRouter appRouter;

  bool _initialized = false;

  void init() {
    if (_initialized) return;

    secureStorage = SecureStorageService();
    apiClient = ApiClient(storage: secureStorage);
    socketClient = SocketClient();
    TypingPresence.instance.attach(socketClient);
    bookmarkService = BookmarkService();
    recentItemsService = RecentItemsService();
    draftMessageService = DraftMessageService();
    authRepository = AuthRepository(
      apiClient: apiClient,
      storage: secureStorage,
      socketClient: socketClient,
      draftMessageService: draftMessageService,
      bookmarkService: bookmarkService,
      recentItemsService: recentItemsService,
    );
    userRepository = UserRepository(apiClient: apiClient);
    spaceRepository = SpaceRepository(apiClient: apiClient);
    messageRepository = MessageRepository(apiClient: apiClient);
    messageRequestRepository = MessageRequestRepository(apiClient: apiClient);
    threadRepository = ThreadRepository(apiClient: apiClient);
    mediaRepository = MediaRepository(apiClient: apiClient);
    channelRepository = ChannelRepository(apiClient: apiClient);
    memberRepository = MemberRepository(apiClient: apiClient);
    handoffRepository = HandoffRepository(apiClient: apiClient);
    dashboardPreferencesService = DashboardPreferencesService();
    notificationRepository = NotificationRepository(apiClient: apiClient);
    notificationBadgeCubit = NotificationBadgeCubit(
      repository: notificationRepository,
      socketClient: socketClient,
    );
    navBadgesCubit = NavBadgesCubit(
      notificationRepository: notificationRepository,
      handoffRepository: handoffRepository,
      notificationBadgeCubit: notificationBadgeCubit,
      socketClient: socketClient,
    );
    searchRepository = SearchRepository(apiClient: apiClient);
    presenceCubit = PresenceCubit(socketClient: socketClient);
    fcmService = FcmService(
      userRepository: userRepository,
      storage: secureStorage,
    );

    if (EnvConfig.useMsg91Widget) {
      msg91OtpService = Msg91OtpService()
        ..initialize(
          widgetId: EnvConfig.msg91WidgetId,
          tokenAuth: EnvConfig.msg91WidgetToken,
        );
    } else {
      msg91OtpService = null;
    }

    authBloc = AuthBloc(
      authRepository: authRepository,
      userRepository: userRepository,
      msg91OtpService: msg91OtpService,
      useMsg91Widget: EnvConfig.useMsg91Widget,
      fcmService: fcmService,
    );
    apiClient.onAccessTokenRefreshed = (token) async {
      await socketClient.updateAccessToken(token);
    };
    socketClient.onTokenRefreshNeeded = () async {
      try {
        return await authRepository.refreshAccessToken();
      } catch (_) {
        return authRepository.getAccessToken();
      }
    };
    apiClient.onSessionExpired = () {
      authBloc.add(const AuthSessionExpired());
    };
    appRouter = AppRouter(authBloc: authBloc);

    _initialized = true;
  }

  void dispose() {
    appRouter.dispose();
    navBadgesCubit.close();
    notificationBadgeCubit.close();
    presenceCubit.close();
    authBloc.close();
    socketClient.dispose();
    fcmService.dispose();
  }
}
