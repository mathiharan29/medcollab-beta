import 'package:flutter/material.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';

/// Creates a space; injectable for tests.
typedef CreateSpaceAction = Future<void> Function({
  required String name,
  required SpaceType type,
});

/// "Create space" dialog shared by My Groups and the Messages → Groups tab.
class CreateSpaceDialog extends StatefulWidget {
  const CreateSpaceDialog({super.key, this.createSpace});

  /// Defaults to [SpaceRepository.createSpace].
  final CreateSpaceAction? createSpace;

  /// Returns `true` when a space was created.
  static Future<bool> show(
    BuildContext context, {
    CreateSpaceAction? createSpace,
  }) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => CreateSpaceDialog(createSpace: createSpace),
    );
    return created == true;
  }

  @override
  State<CreateSpaceDialog> createState() => _CreateSpaceDialogState();
}

class _CreateSpaceDialogState extends State<CreateSpaceDialog> {
  // Owned by the State so it is disposed only after the dialog route,
  // including its exit animation, is gone (back/cancel/outside tap).
  final _nameController = TextEditingController();
  var _type = SpaceType.department;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (_saving || name.length < 2) return;
    setState(() => _saving = true);
    try {
      final create = widget.createSpace ??
          ({required String name, required SpaceType type}) => AppDependencies
              .instance.spaceRepository
              .createSpace(name: name, type: type);
      await create(name: name, type: _type);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppException ? e.message : 'Failed to create'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create space'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Space name',
              hintText: 'e.g. Medicine PG 2024',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SpaceType>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: SpaceType.values
                .map(
                  (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _type = v ?? _type),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
