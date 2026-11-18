import 'dart:async';

import 'package:medcollab_app/core/chat/chat_transcript_cache.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/notifications/fcm_service.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';

/// Routes a tapped push notification into one chat.
///
/// Rapid taps keep only the latest target, and that target replaces the
/// current route so Back does not walk through earlier chats.
abstract final class PushNotificationRouter {
  static Timer? _debounce;
  static String? _queuedRoute;

  static void open(PushPayload payload) {
    final targetRoute = _routeFor(payload);
    final channelId = payload.channelId;
    if (channelId != null && channelId.isNotEmpty && !payload.voiceMode) {
      unawaited(_prefetch(channelId));
    }

    final auth = AppDependencies.instance.authBloc.state.status;
    if (auth != AuthStatus.authenticated) {
      AppDependencies.instance.appRouter.rememberNotificationRoute(targetRoute);
      return;
    }

    _queuedRoute = targetRoute;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      final route = _queuedRoute;
      if (route == null || route.isEmpty) return;
      final status = AppDependencies.instance.authBloc.state.status;
      if (status != AuthStatus.authenticated) {
        AppDependencies.instance.appRouter.rememberNotificationRoute(route);
        return;
      }
      AppDependencies.instance.appRouter.router.go(route);
    });
  }

  static String _routeFor(PushPayload payload) {
    final type = payload.type.toLowerCase();
    if (payload.handoffId != null &&
        payload.handoffId!.isNotEmpty &&
        payload.spaceId != null &&
        payload.spaceId!.isNotEmpty) {
      return AppRoutes.spaceHandoffDetailPath(
        payload.spaceId!,
        payload.handoffId!,
      );
    }
    if (payload.voiceMode && payload.channelId != null && payload.channelId!.isNotEmpty) {
      return AppRoutes.needlVoicePath(payload.channelId!);
    }
    if (payload.channelId != null && payload.channelId!.isNotEmpty) {
      final spaceId = payload.spaceId;
      if (spaceId != null && spaceId.isNotEmpty && spaceId != 'null') {
        return AppRoutes.channelPath(spaceId, payload.channelId!);
      }
      return AppRoutes.dmPath(payload.channelId!);
    }
    if (type.contains('handoff')) return AppRoutes.handoffs;
    return AppRoutes.notifications;
  }

  static Future<void> _prefetch(String channelId) async {
    if (ChatTranscriptCache.messagesFor(channelId) != null) return;
    try {
      final page = await AppDependencies.instance.messageRepository
          .getMessages(channelId);
      ChatTranscriptCache.save(
        channelId,
        page.messages,
        hasMore: page.hasMore,
      );
    } catch (_) {}
  }
}
