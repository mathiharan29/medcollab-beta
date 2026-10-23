import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/clinical_profile_options.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/data/models/update_profile_request.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/profile/presentation/widgets/profile_details_form.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _specialityController;
  late final TextEditingController _institutionController;
  late final TextEditingController _customRoleController;
  late final TextEditingController _usernameController;
  late UserRole _role;
  String? _pgPrepSubject;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user!;
    _nameController = TextEditingController(text: user.name);
    _institutionController = TextEditingController(text: user.institution ?? '');
    _customRoleController = TextEditingController();
    _usernameController =
        TextEditingController(text: user.vocleUsername ?? '');
    _role = user.role;

    final spec = user.speciality ?? '';
    if (_role == UserRole.intern &&
        spec.isNotEmpty &&
        ClinicalProfileOptions.neetPgSubjects.contains(spec)) {
      _pgPrepSubject = spec;
      _specialityController = TextEditingController();
    } else {
      _specialityController = TextEditingController(text: spec);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialityController.dispose();
    _institutionController.dispose();
    _customRoleController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);

    final speciality = ProfileDetailsFormHelper.resolveSpeciality(
      role: _role,
      specialityController: _specialityController,
      customRoleController: _customRoleController,
      pgPrepSubject: _pgPrepSubject,
    );

    try {
      final updated = await AppDependencies.instance.userRepository.updateMe(
        UpdateProfileRequest(
          name: _nameController.text.trim(),
          role: _role,
          speciality: speciality,
          institution: _institutionController.text.trim(),
          vocleUsername: _usernameController.text.trim(),
        ),
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthUserUpdated(updated));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      context.pop();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Edit profile'),
        backgroundColor: AppColors.backgroundApp,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Update your role when you move from intern to PG resident, '
              'or change college after exams.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
            const SizedBox(height: 16),
            ProfileDetailsForm(
              nameController: _nameController,
              institutionController: _institutionController,
              specialityController: _specialityController,
              customRoleController: _customRoleController,
              role: _role,
              enabled: !_submitting,
              pgPrepSubject: _pgPrepSubject,
              onPgPrepSubjectChanged: (v) => _pgPrepSubject = v,
              onRoleChanged: (role) {
                setState(() {
                  _role = role;
                  if (ClinicalProfileOptions.skipSpeciality(role) ||
                      (!ClinicalProfileOptions.showClinicalSpeciality(role) &&
                          !ClinicalProfileOptions.showFreeTextSpeciality(
                            role,
                          ) &&
                          !ClinicalProfileOptions.showPgPrepSubject(role))) {
                    _specialityController.clear();
                  }
                  if (!ClinicalProfileOptions.showPgPrepSubject(role)) {
                    _pgPrepSubject = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              enabled: !_submitting,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
                LengthLimitingTextInputFormatter(30),
              ],
              decoration: const InputDecoration(
                labelText: 'Vocle username',
                hintText: 'e.g. dr_anita',
                prefixText: '@',
                helperText: 'Letters, numbers and underscore (min 3)',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                // Optional until the backend field ships for all users, but
                // when provided it must be a valid handle.
                if (v.isEmpty) return null;
                if (v.length < 3) return 'Use at least 3 characters';
                if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(v)) {
                  return 'Only letters, numbers and underscore';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
