import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
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
  final _summaryController = TextEditingController();
  List<SpaceMemberModel> _members = const [];

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  Future<_FormBootstrap> _bootstrap() async {
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

  Future<void> _addPatient(BuildContext context) async {
    final cubit = context.read<HandoffFormCubit>();
    final patient = await PatientEditorSheet.show(context);
    if (patient == null) return;
    cubit.setPatients([...cubit.state.patients, patient]);
  }

  Future<void> _editPatient(
    BuildContext context,
    int index,
    HandoffPatientModel patient,
  ) async {
    final cubit = context.read<HandoffFormCubit>();
    final updated = await PatientEditorSheet.show(context, initial: patient);
    if (updated == null) return;
    final list = List<HandoffPatientModel>.from(cubit.state.patients);
    list[index] = updated;
    cubit.setPatients(list);
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;
    final currentUserId =
        context.read<AuthBloc>().state.user?.id ?? '';

    return FutureBuilder<_FormBootstrap>(
      future: _bootstrap(),
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

        final data = snapshot.data!;
        _members = data.members;

        if (data.existingHandoff != null &&
            _summaryController.text.isEmpty) {
          _summaryController.text = data.existingHandoff!.shiftSummary;
        }

        return BlocProvider(
          create: (_) => HandoffFormCubit(
            handoffRepository: deps.handoffRepository,
            spaceId: widget.spaceId,
            channelId: data.channelId,
            currentUserId: currentUserId,
            existing: data.existingHandoff,
          ),
          child: Builder(
            builder: (context) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    widget.handoffId == null
                        ? 'Create handoff'
                        : 'Edit handoff',
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
                                    context
                                        .read<HandoffFormCubit>()
                                        .setAssignedDoctor(u);
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
                                    initialDate:
                                        state.shiftDate ?? DateTime.now(),
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null && context.mounted) {
                                    context
                                        .read<HandoffFormCubit>()
                                        .setShiftDate(picked);
                                  }
                                },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ShiftType>(
                          value: state.shiftType,
                          decoration:
                              const InputDecoration(labelText: 'Shift'),
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
                                    context
                                        .read<HandoffFormCubit>()
                                        .setShiftType(v);
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
                          onChanged: (v) => context
                              .read<HandoffFormCubit>()
                              .setShiftSummary(v),
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
                              onPressed: state.isSaving
                                  ? null
                                  : () => _addPatient(context),
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
                              onEdit: () => _editPatient(
                                context,
                                entry.key,
                                entry.value,
                              ),
                              onDelete: () {
                                final list = List<HandoffPatientModel>.from(
                                  state.patients,
                                )..removeAt(entry.key);
                                context
                                    .read<HandoffFormCubit>()
                                    .setPatients(list);
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
                                        final result = await context
                                            .read<HandoffFormCubit>()
                                            .saveDraft();
                                        if (result != null && context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('Draft saved'),
                                            ),
                                          );
                                          context.go(
                                            AppRoutes.spaceHandoffsPath(
                                              widget.spaceId,
                                            ),
                                            extra: result,
                                          );
                                        }
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
                                        final result = await context
                                            .read<HandoffFormCubit>()
                                            .submit();
                                        if (result != null && context.mounted) {
                                          context.go(
                                            AppRoutes.spaceHandoffsPath(
                                              widget.spaceId,
                                            ),
                                            extra: result,
                                          );
                                        }
                                      },
                                child: const Text('Submit'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ),
              );
            },
          ),
        );
      },
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
