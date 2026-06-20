import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/router/go_router_refresh_stream.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/auth/presentation/pages/otp_verification_page.dart';
import 'package:medcollab_app/features/auth/presentation/pages/phone_entry_page.dart';
import 'package:medcollab_app/features/auth/presentation/pages/profile_setup_page.dart';
import 'package:medcollab_app/features/auth/presentation/pages/splash_page.dart';
import 'package:medcollab_app/features/messages/presentation/pages/channel_chat_page.dart';
import 'package:medcollab_app/features/messages/presentation/pages/thread_page.dart';
import 'package:medcollab_app/features/members/presentation/pages/space_members_page.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/presentation/pages/space_detail_page.dart';
import 'package:medcollab_app/features/spaces/presentation/pages/spaces_home_page.dart';

class AppRouter {
  AppRouter({required AuthBloc authBloc}) : _authBloc = authBloc {
    _refreshListenable = GoRouterRefreshStream(_authBloc.stream);
  }

  final AuthBloc _authBloc;
  late final GoRouterRefreshStream _refreshListenable;

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: _refreshListenable,
    redirect: _redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.phoneEntry,
        builder: (context, state) => const PhoneEntryPage(),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        builder: (context, state) => const OtpVerificationPage(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const SpacesHomePage(),
      ),
      GoRoute(
        path: AppRoutes.spaceDetail,
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return SpaceDetailPage(spaceId: spaceId);
        },
      ),
      GoRoute(
        path: AppRoutes.channel,
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          final channelId = state.pathParameters['channelId']!;
          final channel = state.extra as ChannelModel?;
          return ChannelChatPage(
            spaceId: spaceId,
            channelId: channelId,
            channel: channel,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.spaceMembers,
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return SpaceMembersPage(spaceId: spaceId);
        },
      ),
      GoRoute(
        path: AppRoutes.thread,
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          final channelId = state.pathParameters['channelId']!;
          final messageId = state.pathParameters['messageId']!;
          final args = state.extra;
          final routeArgs = args is ThreadRouteArgs ? args : null;
          return ThreadPage(
            spaceId: spaceId,
            channelId: channelId,
            rootMessageId: messageId,
            channel: routeArgs?.channel,
            initialRoot: routeArgs?.rootMessage,
          );
        },
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final auth = _authBloc.state;
    final location = state.matchedLocation;

    switch (auth.status) {
      case AuthStatus.unknown:
        return location == AppRoutes.splash ? null : AppRoutes.splash;

      case AuthStatus.loading:
        // Stay on the current auth screen while saving OTP / profile, etc.
        if (location == AppRoutes.splash ||
            location == AppRoutes.phoneEntry ||
            location == AppRoutes.otpVerification ||
            location == AppRoutes.profileSetup ||
            location == AppRoutes.home ||
            location.startsWith('/spaces')) {
          return null;
        }
        return AppRoutes.splash;

      case AuthStatus.unauthenticated:
        if (location == AppRoutes.phoneEntry) return null;
        return AppRoutes.phoneEntry;

      case AuthStatus.otpSent:
        if (location == AppRoutes.otpVerification) return null;
        return AppRoutes.otpVerification;

      case AuthStatus.needsProfile:
        if (location == AppRoutes.profileSetup) return null;
        return AppRoutes.profileSetup;

      case AuthStatus.authenticated:
        if (location == AppRoutes.home || location.startsWith('/spaces')) {
          return null;
        }
        return AppRoutes.home;
    }
  }

  void dispose() {
    _refreshListenable.dispose();
  }
}
