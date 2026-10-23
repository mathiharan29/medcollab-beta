import 'package:flutter/material.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';

/// "Create space" dialog shared by My Groups and the Messages → Groups tab.
class CreateSpaceDialog {
  const CreateSpaceDialog._();

  /// Returns `true` when a space was created.
  static Future<bool> show(BuildContext context) async {
    final nameController = TextEditingController();
    var type = SpaceType.department;
    final spaceRepository = AppDependencies.instance.spaceRepository;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create space'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Space name',
                  hintText: 'e.g. Medicine PG 2024',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SpaceType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: SpaceType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => type = v ?? type),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().length < 2) return;
                try {
                  await spaceRepository.createSpace(
                    name: nameController.text.trim(),
                    type: type,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          e is AppException ? e.message : 'Failed to create',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    return created == true;
  }
}
