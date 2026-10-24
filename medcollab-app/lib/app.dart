import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/lifecycle/app_lifecycle_handler.dart';
import 'package:medcollab_app/core/notifications/fcm_service.dart';
import 'package:medcollab_app/core/notifications/push_notification_router.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/router/app_navigation_back_handler.dart';
import 'package:medcollab_app/core/theme/app_theme.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';
import 'package:medcollab_app/features/shell/presentation/cubit/nav_badges_cubit.dart';

class MedCollabApp extends StatefulWidget {
  const MedCollabApp({super.key});

  @override
  State<MedCollabApp> createState() => _MedCollabAppState();
}

class _MedCollabAppState extends State<MedCollabApp> {
  StreamSubscription<PushPayload>? _pushTapSub;
  final ThemeModeCubit _themeCubit = ThemeModeCubit();

  @override
  void initState() {
    super.initState();
    _themeCubit.load();
    final deps = AppDependencies.instance;
    _pushTapSub = deps.fcmService.onNotificationTap.listen((payload) {
      // Cold start: the navigator may not exist yet. The router holds the
      // target until auth finishes, then opens that chat instead of Home.
      PushNotificationRouter.open(payload);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      deps.navBadgesCubit.setUserId(deps.authBloc.state.user?.id);
    });
  }

  @override
  void dispose() {
    _pushTapSub?.cancel();
    _themeCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: deps.authBloc),
        BlocProvider<PresenceCubit>.value(value: deps.presenceCubit),
        BlocProvider<NotificationBadgeCubit>.value(
          value: deps.notificationBadgeCubit,
        ),
        BlocProvider<NavBadgesCubit>.value(value: deps.navBadgesCubit),
        BlocProvider<ThemeModeCubit>.value(value: _themeCubit),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (prev, next) => prev.user?.id != next.user?.id,
        listener: (_, state) {
          deps.navBadgesCubit.setUserId(state.user?.id);
        },
        child: AppLifecycleHandler(
          child: BlocBuilder<ThemeModeCubit, ThemeSettingsState>(
            builder: (context, themeState) => MaterialApp.router(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightFor(themeState.palette),
              darkTheme: AppTheme.darkFor(themeState.palette),
              themeMode: themeState.mode,
              routerConfig: deps.appRouter.router,
              builder: (context, child) => AppNavigationBackHandler(
                router: deps.appRouter.router,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
