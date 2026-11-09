import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

/// Opens a DM without stacking duplicate routes for the same channel.
///
/// Does **not** await route pop — awaiting `context.push` made Message taps
/// feel multi-second laggy until the user left the chat.
Future<void> openDmChat(
  BuildContext context, {
  required String channelId,
  ChannelModel? channel,
  bool replace = false,
}) async {
  final path = AppRoutes.dmPath(channelId);
  final current = GoRouterState.of(context).uri.path;
  if (current == path) return;
  // A snackbar from the previous screen ("Request sent…") would sit over
  // the new chat's message box for seconds.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

  if (replace) {
    context.pushReplacement(path, extra: channel);
  } else {
    context.push(path, extra: channel);
  }
}
