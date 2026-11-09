import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/back_guard.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/cubit/handoff_form_cubit.dart';
import 'package:medcollab_app/features/handoffs/presentation/utils/handoff_doctor_options.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_widgets.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/patient_editor_sheet.dart';
import 'package:medcollab_app/features/members/data/models/space_member_model.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

class HandoffFormPage extends StatefulWidget {
  const HandoffFormPage({
    required this.spaceId,
    this.handoffId,
    super.key,
  });

  final String spaceId;
  final String? handoffId;

  @override
  State<HandoffFormPage> createState() => _HandoffFormPageState();
}

class _HandoffFormPageState extends State<HandoffFormPage> {
  late final Future<_FormBootstrap> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _loadBootstrap();
  }

  Future<_FormBootstrap> _loadBootstrap() async {
    final deps = AppDependencies.instance;
    final spaceFuture = deps.spaceRepository.getSpaceById(widget.spaceId);
    final membersFuture =
        deps.memberRepository.getSpaceMembers(widget.spaceId);

    if (widget.handoffId != null) {
      final results = await Future.wait([
        spaceFuture,
        membersFuture,
        deps.handoffRepository.getHandoffById(widget.handoffId!),
      ]);
      final space = results[0] as SpaceModel;
      final members = results[1] as List<SpaceMemberModel>;
      final handoff = results[2] as HandoffModel;
      return _FormBootstrap(
        space: space,
        members: members,
        channelId: handoff.channelId,
        existingHandoff: handoff,
      );
    }

    final results = await Future.wait([spaceFuture, membersFuture]);
    final space = results[0] as SpaceModel;
    final members = results[1] as List<SpaceMemberModel>;
    final channelId =
        space.channels.isNotEmpty ? space.channels.first.id : '';

    return _FormBootstrap(
      space: space,
      members: members,
      channelId: channelId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FormBootstrap>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          final message = snapshot.error is AppException
              ? (snapshot.error as AppException).message
              : 'Could not load handoff form';
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(message)),
          );
        }

        return _HandoffFormBody(
          spaceId: widget.spaceId,
          handoffId: widget.handoffId,
          bootstrap: snapshot.data!,
        );
      },
    );
  }
}

class _HandoffFormBody extends StatefulWidget {
  const _HandoffFormBody({
    required this.spaceId,
    required this.handoffId,
    required this.bootstrap,
  });

  final String spaceId;
  final String? handoffId;
  final _FormBootstrap bootstrap;

  @override
  State<_HandoffFormBody> createState() => _HandoffFormBodyState();
}

class _HandoffFormBodyState extends State<_HandoffFormBody> {
  late final HandoffFormCubit _cubit;
  late final TextEditingController _summaryController;
  late final List<SpaceMemberModel> _members;
  late final HandoffFormState _initial;
  bool _saved = false;

  /// F7: unsaved edits (anything differs from what the form opened with).
  bool get _dirty =>
      !_saved && _cubit.state.copyWith(isSaving: false) != _initial;

  Future<bool> _confirmDiscard() async {
    if (!_dirty || !mounted) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your handoff changes have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  void _leaveWith(HandoffModel result) {
    _saved = true;
    context.pop(result);
  }

  @override
  void initState() {
    super.initState();
    BackGuard.register(_confirmDiscard);
    final deps = AppDependencies.instance;
    final currentUserId =
        context.read<AuthBloc>().state.user?.id ?? '';

    _members = widget.bootstrap.members;
    _summaryController = TextEditingController(
      text: widget.bootstrap.existingHandoff?.shiftSummary ?? '',
    );
    _cubit = HandoffFormCubit(
      handoffRepository: deps.handoffRepository,
      spaceId: widget.spaceId,
      channelId: widget.bootstrap.channelId,
      currentUserId: currentUserId,
      existing: widget.bootstrap.existingHandoff,
    );
    _initial = _cubit.state;
  }

  @override
  void dispose() {
    BackGuard.unregister(_confirmDiscard);
    _cubit.close();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _addPatient() async {
    final patient = await PatientEditorSheet.show(context);
    if (patient == null) return;
    _cubit.setPatients([..._cubit.state.patients, patient]);
  }

  Future<void> _editPatient(int index, HandoffPatientModel patient) async {
    final updated = await PatientEditorSheet.show(context, initial: patient);
    if (updated == null) return;
    final list = List<HandoffPatientModel>.from(_cubit.state.patients);
    list[index] = updated;
    _cubit.setPatients(list);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.read<AuthBloc>().state.user?.id ?? '';

    return BlocProvider.value(
      value: _cubit,
      // F7: the app-bar back arrow asks before discarding unsaved changes
      // (system back is covered by BackGuard).
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _confirmDiscard() && mounted) {
            _saved = true;
            context.pop();
          }
        },
        child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.handoffId == null ? 'Create handoff' : 'Edit handoff',
          ),
          actions: [
            BlocBuilder<HandoffFormCubit, HandoffFormState>(
              bloc: _cubit,
              builder: (context, state) {
                return TextButton(
                  onPressed: state.isSaving
                      ? null
                      : () async {
                          final result = await _cubit.submit();
                          if (!mounted || result == null) return;
                          _leaveWith(result);
                        },
                  child: state.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          state.isSent ? 'Save' : 'Submit',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<HandoffFormCubit, HandoffFormState>(
          builder: (context, state) {
            final options = handoffDoctorOptions(
              _members.map((m) => m.user),
              state.assignedDoctor,
            );
            final doctors = options.doctors;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ErrorBanner(message: state.error!),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Handoffs are for patients and tasks that must not be missed '
                    '— sick, unstable, or cross-cover cases. They are not meant '
                    'to replace your full ward-round notebook for stable patients.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (state.isSent) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusWarnTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.status == HandoffStatus.acknowledged
                          ? 'Already acknowledged by '
                              '${state.assignedDoctor?.displayName ?? 'the receiver'}. '
                              'Saving changes notifies them and asks them to '
                              'acknowledge again.'
                          : 'Already sent to '
                              '${state.assignedDoctor?.displayName ?? 'the receiver'}. '
                              'Saving changes notifies them. To hand over to '
                              'someone else, use Reassign on the handoff.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<UserModel>(
                  value: options.selected,
                  decoration: const InputDecoration(
                    labelText: 'Assigned doctor',
                  ),
                  items: doctors
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u.id == currentUserId
                                ? '${u.displayName} (you)'
                                : u.displayName,
                          ),
                        ),
                      )
                      .toList(),
                  // A sent handoff changes hands only via Reassign (audited).
                  onChanged: state.isSaving || state.isSent
                      ? null
                      : (u) {
                          if (u != null) {
                            _cubit.setAssignedDoctor(u);
                          }
                        },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Shift date'),
                  subtitle: Text(
                    state.shiftDate != null
                        ? MaterialLocalizations.of(context)
                            .formatMediumDate(state.shiftDate!)
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: state.isSaving
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: state.shiftDate ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null && mounted) {
                            _cubit.setShiftDate(picked);
                          }
                        },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ShiftType>(
                  value: state.shiftType,
                  decoration: const InputDecoration(labelText: 'Shift'),
                  items: ShiftType.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          // "Morning", not the raw API value "morning".
                          child: Text(
                            s.value.isEmpty
                                ? s.value
                                : '${s.value[0].toUpperCase()}'
                                    '${s.value.substring(1)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: state.isSaving
                      ? null
                      : (v) {
                          if (v != null) {
                            _cubit.setShiftType(v);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Shift note (optional)',
                    hintText: 'e.g. Ward 3 stable except bed 12 — needs repeat Hb',
                    counterText: '',
                  ),
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 2000,
                  onChanged: _cubit.setShiftSummary,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Patients to hand over',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: state.isSaving ? null : _addPatient,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (state.patients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Add only patients that need explicit handover — '
                      'critical, unstable, or cross-cover. Skip stable ward-list entries.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...state.patients.asMap().entries.map((entry) {
                    return HandoffPatientCard(
                      patient: entry.value,
                      onEdit: () => _editPatient(entry.key, entry.value),
                      onDelete: () {
                        final list = List<HandoffPatientModel>.from(
                          state.patients,
                        )..removeAt(entry.key);
                        _cubit.setPatients(list);
                      },
                    );
                  }),
                const SizedBox(height: 24),
                if (state.isSent)
                  FilledButton(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                            final result = await _cubit.saveChanges();
                            if (!mounted || result == null) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Changes saved — receiver notified'),
                              ),
                            );
                            _leaveWith(result);
                          },
                    child: const Text('Save changes'),
                  )
                else
                  OutlinedButton(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                            final result = await _cubit.saveDraft();
                            if (!mounted || result == null) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Draft saved')),
                            );
                            _leaveWith(result);
                          },
                    child: const Text('Save draft'),
                  ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
      ),
    );
  }
}

class _FormBootstrap {
  const _FormBootstrap({
    required this.space,
    required this.members,
    required this.channelId,
    this.existingHandoff,
  });

  final SpaceModel space;
  final List<SpaceMemberModel> members;
  final String channelId;
  final HandoffModel? existingHandoff;
}
