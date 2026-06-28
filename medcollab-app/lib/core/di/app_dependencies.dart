import 'package:medcollab_app/core/auth/msg91_otp_service.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/router/app_router.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/media/data/repositories/media_repository.dart';
import 'package:medcollab_app/features/members/data/repositories/member_repository.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/data/repositories/thread_repository.dart';
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
  late final ThreadRepository threadRepository;
  late final MediaRepository mediaRepository;
  late final ChannelRepository channelRepository;
  late final MemberRepository memberRepository;
  late final HandoffRepository handoffRepository;
  late final PresenceCubit presenceCubit;
  late final Msg91OtpService? msg91OtpService;
  late final AuthBloc authBloc;
  late final AppRouter appRouter;

  bool _initialized = false;

  void init() {
    if (_initialized) return;

    secureStorage = SecureStorageService();
    apiClient = ApiClient(storage: secureStorage);
    socketClient = SocketClient();
    authRepository = AuthRepository(
      apiClient: apiClient,
      storage: secureStorage,
      socketClient: socketClient,
    );
    userRepository = UserRepository(apiClient: apiClient);
    spaceRepository = SpaceRepository(apiClient: apiClient);
    messageRepository = MessageRepository(apiClient: apiClient);
    threadRepository = ThreadRepository(apiClient: apiClient);
    mediaRepository = MediaRepository(apiClient: apiClient);
    channelRepository = ChannelRepository(apiClient: apiClient);
    memberRepository = MemberRepository(apiClient: apiClient);
    handoffRepository = HandoffRepository(apiClient: apiClient);
    presenceCubit = PresenceCubit(socketClient: socketClient);

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
    presenceCubit.close();
    authBloc.close();
    socketClient.dispose();
  }
}
