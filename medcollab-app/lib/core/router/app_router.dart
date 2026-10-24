import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/router/go_router_refresh_stream.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/auth/presentation/pages/otp_verification_page.dart';
import 'package:medcollab_app/features/auth/presentation/pages/phone_entry_page.dart';
import 'package:medcollab_app/features/auth/presentation/pages/profile_setup_page.dart';
import 'package:medcollab_app/features/auth/presentation/pages/splash_page.dart';
import 'package:medcollab_app/features/bookmarks/presentation/pages/bookmarks_page.dart';
import 'package:medcollab_app/features/dev/presentation/pages/developer_mode_page.dart';
import 'package:medcollab_app/features/handoffs/presentation/pages/handoff_detail_page.dart';
import 'package:medcollab_app/features/handoffs/presentation/pages/handoff_form_page.dart';
import 'package:medcollab_app/features/handoffs/presentation/pages/handoffs_list_page.dart';
import 'package:medcollab_app/features/members/presentation/pages/space_members_page.dart';
import 'package:medcollab_app/features/messages/presentation/pages/channel_chat_page.dart';
import 'package:medcollab_app/features/messages/presentation/pages/start_dm_page.dart';
import 'package:medcollab_app/features/messages/presentation/pages/thread_page.dart';
import 'package:medcollab_app/features/notifications/presentation/pages/notification_settings_page.dart';
import 'package:medcollab_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:medcollab_app/features/search/presentation/pages/global_search_page.dart';
import 'package:medcollab_app/features/shell/presentation/pages/main_shell_page.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/presentation/pages/join_invite_page.dart';
import 'package:medcollab_app/features/spaces/presentation/pages/scan_invite_qr_page.dart';
import 'package:medcollab_app/features/spaces/presentation/pages/space_detail_page.dart';
import 'package:medcollab_app/features/spaces/presentation/pages/spaces_home_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/contact_team_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/feature_request_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/feedback_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/help_faq_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/legal_document_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/report_bug_page.dart';
import 'package:medcollab_app/core/constants/legal_copy.dart';

class AppRouter {
  AppRouter({required AuthBloc authBloc}) : _authBloc = authBloc {
    _refreshListenable = GoRouterRefreshStream(_authBloc.stream);
  }

  final AuthBloc _authBloc;
  late final GoRouterRefreshStream _refreshListenable;
  final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  late final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: _refreshListenable,
    redirect: (context, state) {
      // Only rewrite known invite deep-link shapes — never rewrite app tab paths.
      final uri = state.uri;
      final host = uri.host.toLowerCase();
      final path = uri.path;
      final scheme = uri.scheme.toLowerCase();

      // medcollab://join/CODE  → path is /CODE, host is join
      if (host == 'join') {
        final code = path.replaceAll('/', '').trim().toUpperCase();
        if (RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(code)) {
          return AppRoutes.joinInvitePath(code);
        }
      }

      // medcollab:///join/CODE already matches /join/:code — leave as-is.
      // Avoid hijacking normal GoRouter locations (HOME, HELP, etc.).
      if (scheme == 'medcollab' &&
          path.startsWith('/join/') == false &&
          path != '/join') {
        final bare = path.replaceAll('/', '').trim().toUpperCase();
        if (RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(bare)) {
          return AppRoutes.joinInvitePath(bare);
        }
      }

      return _redirect(context, state);
    },
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellPage(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => ShellTabPages.home,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                builder: (context, state) => ShellTabPages.messages,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.handoffs,
                builder: (context, state) => ShellTabPages.handoffs,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notifications,
                builder: (context, state) => ShellTabPages.notifications,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => ShellTabPages.profile,
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.spacesList,
        builder: (context, state) => const SpacesHomePage(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const GlobalSearchPage(),
      ),
      GoRoute(
        path: AppRoutes.bookmarks,
        builder: (context, state) => const BookmarksPage(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (context, state) => const HelpFaqPage(),
      ),
      GoRoute(
        path: AppRoutes.reportBug,
        builder: (context, state) => const ReportBugPage(),
      ),
      GoRoute(
        path: AppRoutes.featureRequest,
        builder: (context, state) => const FeatureRequestPage(),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        builder: (context, state) => const FeedbackPage(),
      ),
      GoRoute(
        path: AppRoutes.contact,
        builder: (context, state) => const ContactTeamPage(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const LegalDocumentPage(
          title: 'Privacy policy',
          body: LegalCopy.privacyBody,
          lastUpdated: LegalCopy.lastUpdated,
        ),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const LegalDocumentPage(
          title: 'Terms of use',
          body: LegalCopy.termsBody,
          lastUpdated: LegalCopy.lastUpdated,
        ),
      ),
      GoRoute(
        path: AppRoutes.developerMode,
        redirect: (context, state) {
          if (!EnvConfig.enableDeveloperTools) return AppRoutes.home;
          return null;
        },
        builder: (context, state) => const DeveloperModePage(),
      ),
      GoRoute(
        path: AppRoutes.startDm,
        builder: (context, state) => const StartDmPage(),
      ),
      GoRoute(
        path: AppRoutes.dm,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId']!;
          final channel = state.extra as ChannelModel?;
          return ChannelChatPage(
            spaceId: null,
            channelId: channelId,
            channel: channel,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.dmThread,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId']!;
          final messageId = state.pathParameters['messageId']!;
          final args = state.extra;
          final routeArgs = args is ThreadRouteArgs ? args : null;
          return ThreadPage(
            spaceId: null,
            channelId: channelId,
            rootMessageId: messageId,
            channel: routeArgs?.channel,
            initialRoot: routeArgs?.rootMessage,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.joinInvite,
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return JoinInvitePage(code: code);
        },
      ),
      GoRoute(
        path: AppRoutes.scanInviteQr,
        builder: (context, state) => const ScanInviteQrPage(),
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
        path: AppRoutes.spaceHandoffs,
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return HandoffsListPage(spaceId: spaceId);
        },
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) {
              final spaceId = state.pathParameters['spaceId']!;
              return HandoffFormPage(spaceId: spaceId);
            },
          ),
          GoRoute(
            path: ':handoffId',
            builder: (context, state) {
              final spaceId = state.pathParameters['spaceId']!;
              final handoffId = state.pathParameters['handoffId']!;
              return HandoffDetailPage(
                key: ValueKey('handoff-detail-$handoffId'),
                spaceId: spaceId,
                handoffId: handoffId,
              );
            },
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final spaceId = state.pathParameters['spaceId']!;
                  final handoffId = state.pathParameters['handoffId']!;
                  return HandoffFormPage(
                    spaceId: spaceId,
                    handoffId: handoffId,
                  );
                },
              ),
            ],
          ),
        ],
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
    // Prefer full path so deep links are not lost when matchedLocation is empty.
    final location = state.uri.path.isNotEmpty
        ? state.uri.path
        : state.matchedLocation;

    // Pending invite while not fully signed in — remember and resume after auth.
    if (location.startsWith('/join/')) {
      _pendingJoinLocation = location;
    }

    switch (auth.status) {
      case AuthStatus.unknown:
        return location == AppRoutes.splash ? null : AppRoutes.splash;

      case AuthStatus.loading:
        if (location == AppRoutes.splash ||
            location == AppRoutes.phoneEntry ||
            location == AppRoutes.otpVerification ||
            location == AppRoutes.profileSetup ||
            _isAuthenticatedRoute(location)) {
          return null;
        }
        return AppRoutes.splash;

      case AuthStatus.unauthenticated:
        if (location == AppRoutes.phoneEntry ||
            _isPublicLegalRoute(location)) {
          return null;
        }
        return AppRoutes.phoneEntry;

      case AuthStatus.otpSent:
        if (location == AppRoutes.otpVerification) return null;
        return AppRoutes.otpVerification;

      case AuthStatus.needsProfile:
        if (location == AppRoutes.profileSetup) return null;
        return AppRoutes.profileSetup;

      case AuthStatus.authenticated:
        final pendingNotif = _pendingNotificationRoute;
        if (pendingNotif != null && pendingNotif.startsWith('/')) {
          _pendingNotificationRoute = null;
          if (location != pendingNotif) return pendingNotif;
        }
        final pending = _pendingJoinLocation;
        if (pending != null &&
            pending.startsWith('/join/') &&
            location != pending) {
          // Consume once — do not re-set from the same evaluation.
          if (!location.startsWith('/join/')) {
            _pendingJoinLocation = null;
            return pending;
          }
        }
        if (_isAuthenticatedRoute(location)) return null;
        // Splash / unknown auth-shell paths after login.
        if (location == AppRoutes.splash || location == '/') {
          return AppRoutes.home;
        }
        if (location == AppRoutes.phoneEntry ||
            location == AppRoutes.otpVerification ||
            location == AppRoutes.profileSetup) {
          return AppRoutes.home;
        }
        return AppRoutes.home;
    }
  }

  String? _pendingJoinLocation;
  String? _pendingNotificationRoute;

  /// Cold-start notification taps arrive before auth/router are ready.
  /// Remember the chat path and open it once the session is authenticated.
  void rememberNotificationRoute(String route) {
    if (route.isEmpty) return;
    _pendingNotificationRoute = route;
    _refreshListenable.refresh();
  }

  bool _isPublicLegalRoute(String location) =>
      location == AppRoutes.privacy ||
      location == AppRoutes.terms ||
      location == AppRoutes.help;

  bool _isAuthenticatedRoute(String location) {
    if (AppRoutes.shellPaths.contains(location)) return true;
    if (location.startsWith('/spaces')) return true;
    if (location.startsWith('/dm')) return true;
    if (location.startsWith('/join')) return true;
    if (location.startsWith('/profile')) return true;
    if (location == AppRoutes.scanInviteQr) return true;
    if (location == AppRoutes.search ||
        location == AppRoutes.bookmarks ||
        location == AppRoutes.notificationSettings ||
        location == AppRoutes.help ||
        location == AppRoutes.reportBug ||
        location == AppRoutes.featureRequest ||
        location == AppRoutes.feedback ||
        location == AppRoutes.contact ||
        location == AppRoutes.privacy ||
        location == AppRoutes.terms) {
      return true;
    }
    if (location == AppRoutes.developerMode &&
        EnvConfig.enableDeveloperTools) {
      return true;
    }
    return false;
  }

  void dispose() {
    _refreshListenable.dispose();
  }
}
