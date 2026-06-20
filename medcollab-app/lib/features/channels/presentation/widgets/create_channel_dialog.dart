import 'package:flutter/material.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

/// Dialog for creating a custom channel with name and description.
class CreateChannelDialog extends StatefulWidget {
  const CreateChannelDialog({
    required this.spaceId,
    required this.onCreated,
    super.key,
  });

  final String spaceId;
  final ValueChanged<ChannelModel> onCreated;

  static Future<void> show(
    BuildContext context, {
    required String spaceId,
    required ValueChanged<ChannelModel> onCreated,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => CreateChannelDialog(
        spaceId: spaceId,
        onCreated: onCreated,
      ),
    );
  }

  @override
  State<CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<CreateChannelDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isPrivate = false;
  bool _isSubmitting = false;
  String? _error;

  late final ChannelRepository _channelRepository =
      AppDependencies.instance.channelRepository;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Channel name is required');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final channel = await _channelRepository.createChannel(
        spaceId: widget.spaceId,
        name: name,
        description: _descController.text.trim(),
        isPrivate: _isPrivate,
      );
      if (!mounted) return;
      widget.onCreated(channel);
      Navigator.of(context).pop();
    } on AppException catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create channel'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. cardiology-rounds',
                prefixText: '# ',
              ),
              textCapitalization: TextCapitalization.none,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What is this channel for?',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private channel'),
              subtitle: const Text('Only invited members can see it'),
              value: _isPrivate,
              onChanged: _isSubmitting
                  ? null
                  : (v) => setState(() => _isPrivate = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
