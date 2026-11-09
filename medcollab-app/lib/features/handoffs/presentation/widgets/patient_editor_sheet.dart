import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/media/data/services/media_picker_service.dart';
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

/// Picks a file for a patient attachment; null when cancelled.
typedef PickPatientAttachment = Future<PickedAttachment?> Function(
  BuildContext context,
);

/// Uploads a picked file and returns the stored attachment.
typedef UploadPatientAttachment = Future<HandoffAttachment> Function(
  PickedAttachment picked,
);

/// Add or edit a single patient entry in a handoff draft.
class PatientEditorSheet extends StatefulWidget {
  const PatientEditorSheet({
    this.initial,
    this.pickAttachment,
    this.uploadAttachment,
    super.key,
  });

  final HandoffPatientModel? initial;

  /// Defaults to a Camera / Photo / Document chooser ([MediaPickerService]).
  final PickPatientAttachment? pickAttachment;

  /// Defaults to [MediaRepository.uploadFile] with context `handoff`.
  final UploadPatientAttachment? uploadAttachment;

  static const maxAttachments = 5;

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
  // Real uploaded files (REQ 9). Previously a placeholder list that only
  // added fake "Attachment N" chips and was never saved.
  late final List<HandoffAttachment> _attachments = [
    ...?widget.initial?.attachments,
  ];
  bool _uploading = false;

  Future<PickedAttachment?> _defaultPick(BuildContext context) async {
    final picker = MediaPickerService();
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Document (PDF, report)'),
              onTap: () => Navigator.pop(ctx, 'document'),
            ),
          ],
        ),
      ),
    );
    return switch (source) {
      'camera' => picker.captureFromCamera(),
      'gallery' => picker.pickFromGallery(),
      'document' => picker.pickDocument(),
      _ => Future.value(null),
    };
  }

  Future<HandoffAttachment> _defaultUpload(PickedAttachment picked) async {
    // image_picker renames downscaled photos "scaled_<name>"; keep the
    // doctor's original file name.
    final name = picked.fileName.startsWith('scaled_')
        ? picked.fileName.substring('scaled_'.length)
        : picked.fileName;
    final upload = await AppDependencies.instance.mediaRepository.uploadFile(
      bytes: picked.bytes,
      fileName: name,
      mimeType: picked.mimeType,
      context: 'handoff',
    );
    return HandoffAttachment(
      url: upload.url,
      thumbnailUrl: upload.thumbnailUrl,
      fileName: name,
      mimeType: upload.mimeType.isNotEmpty ? upload.mimeType : picked.mimeType,
    );
  }

  Future<void> _addAttachment() async {
    if (_uploading ||
        _attachments.length >= PatientEditorSheet.maxAttachments) {
      return;
    }
    final PickedAttachment? picked;
    try {
      picked = await (widget.pickAttachment ?? _defaultPick)(context);
    } catch (_) {
      _snack('Could not open the picker. Check camera/storage permission.');
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final attachment =
          await (widget.uploadAttachment ?? _defaultUpload)(picked);
      if (!mounted) return;
      setState(() => _attachments.add(attachment));
    } catch (_) {
      _snack('Upload failed. Try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Explicit readable label colour. The app chip theme's badge style made
  /// these labels invisible on the chip background (sanity F3).
  TextStyle? _chipLabelStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w500);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

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
    if (_uploading) {
      _snack('Wait for the attachment to finish uploading');
      return;
    }
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
        attachments: List.unmodifiable(_attachments),
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
            Text(
              'Attachments (${_attachments.length}/${PatientEditorSheet.maxAttachments})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final attachment in _attachments)
                  InputChip(
                    key: ValueKey('attachment-${attachment.url}'),
                    avatar: Icon(
                      attachment.isImage
                          ? Icons.image_outlined
                          : Icons.description_outlined,
                      size: 16,
                    ),
                    label: Text(
                      attachment.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: _chipLabelStyle(context),
                    ),
                    deleteButtonTooltipMessage: 'Remove attachment',
                    onDeleted: _uploading
                        ? null
                        : () => setState(() => _attachments.remove(attachment)),
                  ),
                if (_attachments.length < PatientEditorSheet.maxAttachments)
                  ActionChip(
                    avatar: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file, size: 16),
                    label: Text(
                      _uploading ? 'Uploading…' : 'Add attachment',
                      style: _chipLabelStyle(context),
                    ),
                    onPressed: _uploading ? null : _addAttachment,
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
              onPressed: _uploading ? null : _save,
              child: Text(widget.initial == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
