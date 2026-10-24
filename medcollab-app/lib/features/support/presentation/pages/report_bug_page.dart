import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/shared/presentation/widgets/clinical_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportBugPage extends StatefulWidget {
  const ReportBugPage({super.key});

  @override
  State<ReportBugPage> createState() => _ReportBugPageState();
}

class _ReportBugPageState extends State<ReportBugPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  bool _submitting = false;

  static const _supportEmail = AppConstants.supportEmail;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);

    final payload = {
      'type': 'bug',
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'steps': _stepsController.text.trim(),
      'submittedAt': DateTime.now().toIso8601String(),
    };

    var delivered = false;
    try {
      await AppDependencies.instance.apiClient.post<dynamic>(
        '/api/support/bug',
        data: payload,
      );
      delivered = true;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final existing = prefs.getStringList('vocle_support_bugs') ?? [];
        existing.add(payload.toString());
        await prefs.setStringList('vocle_support_bugs', existing);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          delivered
              ? 'Thanks — Vocle beta team received your report'
              : 'Could not submit — check your connection and try again. '
                  'Draft kept on this screen. Email $_supportEmail if urgent.',
        ),
      ),
    );
    // Keep inputs on API failure so the user can retry (FR-SUP-04).
    if (delivered) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Report a bug'),
        backgroundColor: AppColors.backgroundApp,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Reports go to the Vocle beta team (product owners for this pilot). '
              'You can also email $_supportEmail.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: _supportEmail),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email copied')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy support email'),
              ),
            ),
            const SizedBox(height: 8),
            ClinicalCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Short summary',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'Add a title' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'What happened vs what you expected',
                      alignLabelWithHint: true,
                    ),
                    minLines: 4,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'Add a short description'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stepsController,
                    decoration: const InputDecoration(
                      labelText: 'Steps to reproduce (optional)',
                      hintText: '1. Open…\n2. Tap…',
                      alignLabelWithHint: true,
                    ),
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}
