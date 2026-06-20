import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/cubit/handoff_form_cubit.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_widgets.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/patient_editor_sheet.dart';
import 'package:medcollab_app/features/members/data/models/space_member_model.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_bottom_bar.dart';
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
    final space = await deps.spaceRepository.getSpaceById(widget.spaceId);
    final members = await deps.memberRepository.getSpaceMembers(widget.spaceId);
    final channelId =
        space.channels.isNotEmpty ? space.channels.first.id : '';

    if (widget.handoffId != null) {
      final handoff =
          await deps.handoffRepository.getHandoffById(widget.handoffId!);
      return _FormBootstrap(
        space: space,
        members: members,
        channelId: handoff.channelId,
        existingHandoff: handoff,
      );
    }

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

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.handoffId == null ? 'Create handoff' : 'Edit handoff',
          ),
        ),
        body: BlocBuilder<HandoffFormCubit, HandoffFormState>(
          builder: (context, state) {
            final doctors = _members
                .map((m) => m.user)
                .where((u) => u.id != currentUserId)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ErrorBanner(message: state.error!),
                  ),
                DropdownButtonFormField<UserModel>(
                  value: state.assignedDoctor,
                  decoration: const InputDecoration(
                    labelText: 'Assigned doctor',
                  ),
                  items: doctors
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(u.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: state.isSaving
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
                          child: Text(s.value),
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
                    labelText: 'Shift summary (optional)',
                  ),
                  minLines: 2,
                  maxLines: 3,
                  onChanged: _cubit.setShiftSummary,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Patients',
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
                      'Add at least one patient before submitting.',
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
                const SizedBox(height: 80),
              ],
            );
          },
        ),
        bottomNavigationBar: AppBottomBar(
          child: BlocBuilder<HandoffFormCubit, HandoffFormState>(
            builder: (context, state) {
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: state.isSaving
                          ? null
                          : () async {
                              final result = await _cubit.saveDraft();
                              if (!mounted || result == null) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Draft saved'),
                                ),
                              );
                              context.pop(result);
                            },
                      child: state.isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Save draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: state.isSaving
                          ? null
                          : () async {
                              final result = await _cubit.submit();
                              if (!mounted || result == null) return;
                              context.pop(result);
                            },
                      child: const Text('Submit'),
                    ),
                  ),
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
