import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/utils/handoff_priority_colors.dart';

/// Field length caps aligned with backend handoff.model.js + clinical practice:
/// bed labels are short, ward codes/names are brief, aliases avoid PHI names,
/// diagnosis stays concise for shift handoff cards.
abstract final class PatientFieldLimits {
  static const bedNumber = 20;
  static const ward = 50;
  static const clinicalAlias = 100;
  static const diagnosis = 200;
  static const notes = 2000;
  static const taskLine = 200;
}

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
  final List<String> _attachments = <String>[];

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
    final ward = _wardController.text.trim();
    final alias = _aliasController.text.trim();
    final diagnosis = _diagnosisController.text.trim();
    if (bed.isEmpty || alias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bed number and clinical alias required')),
      );
      return;
    }
    // Bed/ward: short clinical labels (no free-form noise).
    final bedOk = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/\s.]{0,19}$').hasMatch(bed);
    final wardOk =
        ward.isEmpty || RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/\s.]{0,49}$').hasMatch(ward);
    if (!bedOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bed: use letters, numbers, - / . (max 20)'),
        ),
      );
      return;
    }
    if (!wardOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ward: use letters, numbers, - / . (max 50)'),
        ),
      );
      return;
    }
    if (alias.length > PatientFieldLimits.clinicalAlias ||
        diagnosis.length > PatientFieldLimits.diagnosis ||
        bed.length > PatientFieldLimits.bedNumber ||
        ward.length > PatientFieldLimits.ward) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Some fields exceed the allowed length')),
      );
      return;
    }

    final tasks = _tasksController.text
        .split('\n')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map(
          (t) => t.length > PatientFieldLimits.taskLine
              ? t.substring(0, PatientFieldLimits.taskLine)
              : t,
        )
        .toList();

    Navigator.pop(
      context,
      HandoffPatientModel(
        id: widget.initial?.id,
        bedNumber: bed,
        ward: ward,
        clinicalAlias: alias,
        diagnosis: diagnosis,
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
                      hintText: '7 / ICU-12',
                      counterText: '',
                    ),
                    keyboardType: TextInputType.text,
                    maxLength: PatientFieldLimits.bedNumber,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        PatientFieldLimits.bedNumber,
                      ),
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9\-/\s.]'),
                      ),
                    ],
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
                      counterText: '',
                    ),
                    maxLength: PatientFieldLimits.ward,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(PatientFieldLimits.ward),
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9\-/\s.]'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: 'Clinical alias (no real names)',
                hintText: '65M with ACS',
                helperText: 'Age/sex + short problem — max 100 chars',
                counterText: '',
              ),
              maxLength: PatientFieldLimits.clinicalAlias,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  PatientFieldLimits.clinicalAlias,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                labelText: 'Diagnosis',
                hintText: 'NSTEMI, post-PCI',
                counterText: '',
              ),
              maxLength: PatientFieldLimits.diagnosis,
              maxLines: 2,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  PatientFieldLimits.diagnosis,
                ),
              ],
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
            Text('Attachment', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in _attachments)
                  InputChip(
                    avatar: const Icon(Icons.attach_file, size: 16),
                    label: Text(name),
                    onDeleted: () => setState(() => _attachments.remove(name)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.attach_file, size: 16),
                  label: const Text('Add attachment'),
                  onPressed: () => setState(
                    () => _attachments.add(
                      'Attachment ${_attachments.length + 1}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Clinical notes',
                counterText: '',
              ),
              minLines: 2,
              maxLines: 4,
              maxLength: PatientFieldLimits.notes,
              inputFormatters: [
                LengthLimitingTextInputFormatter(PatientFieldLimits.notes),
              ],
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
