import 'package:flutter/material.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/utils/handoff_priority_colors.dart';

/// Add or edit a single patient entry in a handoff draft.
class PatientEditorSheet extends StatefulWidget {
  const PatientEditorSheet({
    this.initial,
    super.key,
  });

  final HandoffPatientModel? initial;

  static Future<HandoffPatientModel?> show(
    BuildContext context, {
    HandoffPatientModel? initial,
  }) {
    return showModalBottomSheet<HandoffPatientModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PatientEditorSheet(initial: initial),
    );
  }

  @override
  State<PatientEditorSheet> createState() => _PatientEditorSheetState();
}

class _PatientEditorSheetState extends State<PatientEditorSheet> {
  late final _bedController =
      TextEditingController(text: widget.initial?.bedNumber ?? '');
  late final _wardController =
      TextEditingController(text: widget.initial?.ward ?? '');
  late final _aliasController =
      TextEditingController(text: widget.initial?.clinicalAlias ?? '');
  late final _diagnosisController =
      TextEditingController(text: widget.initial?.diagnosis ?? '');
  late final _notesController =
      TextEditingController(text: widget.initial?.notes ?? '');
  late final _tasksController = TextEditingController(
    text: widget.initial?.pendingTasks.join('\n') ?? '',
  );
  late PatientStatus _status = widget.initial?.status ?? PatientStatus.stable;
  late bool _isFlagged = widget.initial?.isFlagged ?? false;

  @override
  void dispose() {
    _bedController.dispose();
    _wardController.dispose();
    _aliasController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    _tasksController.dispose();
    super.dispose();
  }

  void _save() {
    final bed = _bedController.text.trim();
    final alias = _aliasController.text.trim();
    if (bed.isEmpty || alias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bed number and clinical alias required')),
      );
      return;
    }

    final tasks = _tasksController.text
        .split('\n')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    Navigator.pop(
      context,
      HandoffPatientModel(
        id: widget.initial?.id,
        bedNumber: bed,
        ward: _wardController.text.trim(),
        clinicalAlias: alias,
        diagnosis: _diagnosisController.text.trim(),
        status: _status,
        notes: _notesController.text.trim(),
        pendingTasks: tasks,
        isFlagged: _isFlagged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'Add patient' : 'Edit patient',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _bedController,
                    decoration: const InputDecoration(
                      labelText: 'Bed number',
                      hintText: '7',
                    ),
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _wardController,
                    decoration: const InputDecoration(
                      labelText: 'Ward',
                      hintText: 'CICU',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: 'Clinical alias (no names)',
                hintText: '65M with ACS',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                labelText: 'Diagnosis',
                hintText: 'Acute Coronary Syndrome',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PatientStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Current status'),
              items: PatientStatus.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(HandoffPriorityColors.statusLabel(s)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('High priority'),
              subtitle: const Text('Flag for incoming doctor'),
              value: _isFlagged,
              onChanged: (v) => setState(() => _isFlagged = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tasksController,
              decoration: const InputDecoration(
                labelText: 'Pending tasks',
                hintText: 'One task per line',
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Clinical notes',
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(widget.initial == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
