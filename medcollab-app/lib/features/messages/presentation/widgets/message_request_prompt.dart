import 'package:flutter/material.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';

/// Shared dialog: send a DM request (used from Start DM + group member sheet).
Future<bool> promptAndSendMessageRequest(
  BuildContext context, {
  required String toUserId,
  String? peerName,
}) async {
  final intro = await showMessageRequestIntroDialog(
    context,
    title: peerName == null || peerName.isEmpty
        ? 'Send message request'
        : 'Message request to $peerName',
    explanation: 'Chat opens when they accept. They will see your name and '
        'this note.',
    hintText: 'Optional — e.g. ICU R2 from AIIMS, need a consult',
  );
  if (intro == null || !context.mounted) return false;

  try {
    await AppDependencies.instance.messageRequestRepository.sendRequest(
      toUserId: toUserId,
      introMessage: intro.isEmpty ? null : intro,
    );
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request sent — waiting for them to accept'),
      ),
    );
    return true;
  } on AppException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
    return false;
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not send request')),
    );
    return false;
  }
}

/// Shows the intro-note dialog for a message request.
///
/// Returns the trimmed note (possibly empty) when the user taps
/// "Send request", or `null` when the dialog is cancelled or dismissed.
///
/// The text controller is owned by the dialog's [State] so it is disposed
/// only after the route (including its exit animation) is fully removed.
/// Disposing it right after `showDialog` returns crashed with
/// "TextEditingController was used after being disposed".
Future<String?> showMessageRequestIntroDialog(
  BuildContext context, {
  required String title,
  required String explanation,
  required String hintText,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => MessageRequestIntroDialog(
      title: title,
      explanation: explanation,
      hintText: hintText,
    ),
  );
}

class MessageRequestIntroDialog extends StatefulWidget {
  const MessageRequestIntroDialog({
    super.key,
    required this.title,
    required this.explanation,
    required this.hintText,
  });

  final String title;
  final String explanation;
  final String hintText;

  @override
  State<MessageRequestIntroDialog> createState() =>
      _MessageRequestIntroDialogState();
}

class _MessageRequestIntroDialogState extends State<MessageRequestIntroDialog> {
  final _introController = TextEditingController();

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.explanation,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _introController,
            maxLength: 140,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _introController.text.trim()),
          child: const Text('Send request'),
        ),
      ],
    );
  }
}
