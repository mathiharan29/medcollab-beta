import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_bot_repository.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';

/// Runs a CONFIRMED voice action (issue 14) through the normal,
/// permission-checked APIs — the bot gets no extra powers. Returns a short
/// result line (shown and spoken).
abstract class VoiceActionExecutor {
  Future<String> execute(VoiceAction action);
}

class AppVoiceActionExecutor implements VoiceActionExecutor {
  AppVoiceActionExecutor({
    required this.router,
    required this.channels,
    required this.messages,
    required this.handoffs,
    required this.notifications,
    required this.badge,
    required this.users,
    required this.directory,
  });

  final GoRouter router;
  final ChannelRepository channels;
  final MessageRepository messages;
  final HandoffRepository handoffs;
  final NotificationRepository notifications;
  final NotificationBadgeCubit badge;
  final UserRepository users;
  final VoiceDirectoryLoader directory;

  @override
  Future<String> execute(VoiceAction action) async {
    try {
      switch (action) {
        case SendMessageAction(:final to, :final text):
          final channelId = to.isPerson ? (await channels.createOrGetDM(to.rawId)).id : to.rawId;
          await messages.sendTextMessage(channelId: channelId, text: text);
          return 'Sent to ${to.name}.';
        case OpenChatAction(:final to):
          if (to.isPerson) {
            final dm = await channels.createOrGetDM(to.rawId);
            router.push(AppRoutes.dmPath(dm.id), extra: dm);
          } else if (to.kind == 'group' && to.spaceId != null) {
            router.push(AppRoutes.channelPath(to.spaceId!, to.rawId));
          } else {
            router.push(AppRoutes.dmPath(to.rawId));
          }
          return 'Opening ${to.name}.';
        case HandoffAction(:final to, :final shift, :final summary, :final patients):
          final groups = directory.sharedGroups[to.rawId] ?? const [];
          if (groups.isEmpty) {
            return 'You and ${to.name} are not in a group together, so a handoff can\'t be created.';
          }
          final g = groups.first;
          final draft = await handoffs.createHandoff(
            spaceId: g.spaceId,
            channelId: g.channelId,
            toUserId: to.rawId,
            shiftDate: DateTime.now(),
            shiftType: ShiftType.values.firstWhere((s) => s.value == shift, orElse: () => ShiftType.night),
            shiftSummary: summary,
            patients: [
              for (final p in patients)
                HandoffPatientModel(
                  bedNumber: p.bed,
                  clinicalAlias: p.alias.isEmpty ? 'Bed ${p.bed}' : p.alias,
                  notes: p.notes,
                  pendingTasks: p.tasks,
                ),
            ],
          );
          // Always a DRAFT: the doctor reviews and sends it themselves.
          router.push(AppRoutes.spaceHandoffEditPath(g.spaceId, draft.id));
          return 'Draft handoff to ${to.name} is ready — review it and tap Submit.';
        case MarkAlertsReadAction():
          await notifications.markAllAsRead();
          badge.clear();
          return 'All alerts marked as read.';
        case SetAvailabilityAction(:final status):
          await users.updateAvailability(status: AvailabilityStatus.fromString(status));
          return 'Status set to ${status.replaceAll('_', ' ')}.';
        case SearchAction():
          router.push(AppRoutes.search);
          return 'Opening search.';
        case NavigateAction(:final tab):
          router.go(switch (tab) {
            'messages' => AppRoutes.messages,
            'handoffs' => AppRoutes.handoffs,
            'alerts' => AppRoutes.notifications,
            'profile' => AppRoutes.profile,
            _ => AppRoutes.home,
          });
          return 'Opening $tab.';
        case ClarifyAction(:final question):
          return question;
      }
    } on ForbiddenException {
      return 'You need an accepted message request before messaging them.';
    } on AppException catch (e) {
      return 'Could not do that: ${e.message}';
    }
  }
}
