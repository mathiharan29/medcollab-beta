import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/dm_navigation.dart';
import 'package:medcollab_app/features/messages/data/models/user_lookup_result.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_request_prompt.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

/// What [startConversation] ended up doing.
enum StartConversationOutcome {
  opened,
  requestSent,
  requestPending,
  cancelled,
  failed,
}

/// Seams for tests; production uses [AppDependencies].
typedef OpenDm = Future<ChannelModel> Function(String userId);
typedef LoadRelationship = Future<UserLookupResult> Function(String userId);
typedef AcceptRequest = Future<ChannelModel?> Function(String requestId);

/// One flow for every "Message" button (Search, Start DM, group members,
/// profile cards) — REQ 11.
///
/// 1. Try to open the 1:1 chat.
/// 2. Not allowed yet → ask the server why and do the right thing:
///    send a request, say it is pending, or accept theirs and open the chat.
///
/// Before this, Search showed "Could not start conversation" for anyone the
/// doctor had no chat with yet, and a parsing error anywhere showed the same
/// dead-end message.
Future<StartConversationOutcome> startConversation(
  BuildContext context, {
  required String userId,
  String? peerName,
  bool replaceRoute = false,
  OpenDm? openDm,
  LoadRelationship? loadRelationship,
  AcceptRequest? acceptRequest,
}) async {
  final deps = AppDependencies.instance;
  final open = openDm ?? deps.channelRepository.createOrGetDM;
  final relation = loadRelationship ?? deps.userRepository.getRelationship;
  final accept = acceptRequest ??
      (id) async =>
          (await deps.messageRequestRepository.acceptRequest(id)).channel;

  void snack(String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  try {
    final channel = await open(userId);
    if (!context.mounted) return StartConversationOutcome.opened;
    await openDmChat(context,
        channelId: channel.id, channel: channel, replace: replaceRoute);
    return StartConversationOutcome.opened;
  } on ForbiddenException {
    // Expected for someone you have not chatted with: fall through.
  } on AppException catch (e) {
    snack(e.message);
    return StartConversationOutcome.failed;
  } catch (e, st) {
    developer.log('startConversation: open failed', error: e, stackTrace: st);
    snack('Could not open the chat. Please try again.');
    return StartConversationOutcome.failed;
  }

  UserLookupResult info;
  try {
    info = await relation(userId);
  } on NotFoundException catch (e) {
    // Server without the relationship endpoint (older deploy): the 403 above
    // already said a request is needed, so offer it instead of failing.
    if (!e.message.toLowerCase().contains('route not found')) {
      snack(e.message);
      return StartConversationOutcome.failed;
    }
    if (!context.mounted) return StartConversationOutcome.cancelled;
    final sent = await promptAndSendMessageRequest(
      context,
      toUserId: userId,
      peerName: peerName,
    );
    return sent
        ? StartConversationOutcome.requestSent
        : StartConversationOutcome.cancelled;
  } on AppException catch (e) {
    snack(e.message);
    return StartConversationOutcome.failed;
  } catch (e, st) {
    developer.log('startConversation: relationship failed',
        error: e, stackTrace: st);
    snack('Could not reach Vocle. Please try again.');
    return StartConversationOutcome.failed;
  }
  if (!context.mounted) return StartConversationOutcome.cancelled;

  final pending = info.pendingRequest;
  if (pending != null && pending.isReceived) {
    final name = peerName ?? info.user.displayName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name sent you a request'),
        content: Text(
          pending.introMessage?.isNotEmpty == true
              ? '"${pending.introMessage}"\n\nAccept to start chatting.'
              : 'Accept to start chatting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept & chat'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return StartConversationOutcome.cancelled;
    }
    try {
      final channel = await accept(pending.id) ?? await open(userId);
      if (!context.mounted) return StartConversationOutcome.opened;
      await openDmChat(context,
        channelId: channel.id, channel: channel, replace: replaceRoute);
      return StartConversationOutcome.opened;
    } on AppException catch (e) {
      snack(e.message);
      return StartConversationOutcome.failed;
    }
  }

  if (pending != null && pending.isSent) {
    snack('Request already sent — the chat opens when they accept');
    return StartConversationOutcome.requestPending;
  }

  if (info.canMessage) {
    // Became allowed in the meantime (e.g. they just accepted).
    try {
      final channel = await open(userId);
      if (!context.mounted) return StartConversationOutcome.opened;
      await openDmChat(context,
        channelId: channel.id, channel: channel, replace: replaceRoute);
      return StartConversationOutcome.opened;
    } on AppException catch (e) {
      snack(e.message);
      return StartConversationOutcome.failed;
    }
  }

  if (info.canRequest) {
    final sent = await promptAndSendMessageRequest(
      context,
      toUserId: userId,
      peerName: peerName ?? info.user.displayName,
    );
    return sent
        ? StartConversationOutcome.requestSent
        : StartConversationOutcome.cancelled;
  }

  snack('Messaging is not available with this doctor');
  return StartConversationOutcome.failed;
}
