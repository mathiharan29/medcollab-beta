import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/utils/handoff_priority_colors.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_widgets.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

class HandoffDetailPage extends StatefulWidget {
  const HandoffDetailPage({
    required this.spaceId,
    required this.handoffId,
    super.key,
  });

  final String spaceId;
  final String handoffId;

  @override
  State<HandoffDetailPage> createState() => _HandoffDetailPageState();
}

class _HandoffDetailPageState extends State<HandoffDetailPage> {
  final _repository = AppDependencies.instance.handoffRepository;
  late Future<HandoffModel> _handoffFuture;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _handoffFuture = _repository.getHandoffById(widget.handoffId);
    });
  }

  Future<void> _acknowledge(HandoffModel handoff) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final updated = await _repository.acknowledgeHandoff(handoff.id);
      if (mounted) context.pop(updated);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteDraft(HandoffModel handoff) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await _repository.deleteHandoff(handoff.id);
      if (mounted) context.pop();
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.read<AuthBloc>().state.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Handoff')),
      body: FutureBuilder<HandoffModel>(
        future: _handoffFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            final message = snapshot.error is AppException
                ? (snapshot.error as AppException).message
                : 'Handoff not found';
            return Center(child: Text(message));
          }

          final handoff = snapshot.data!;
          final isSender = handoff.fromUser.id == currentUserId;
          final isReceiver = handoff.toUser.id == currentUserId;
          final canEdit = handoff.isDraft && isSender;
          final canAcknowledge =
              handoff.status == HandoffStatus.submitted && isReceiver;
          final updated = handoff.lastUpdated;

          return Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ErrorBanner(message: _error!),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeaderCard(handoff: handoff),
                    const SizedBox(height: 16),
                    if (handoff.shiftSummary.isNotEmpty) ...[
                      Text(
                        'Shift summary',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(handoff.shiftSummary),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      '${handoff.patients.length} patient${handoff.patients.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...handoff.patients.map(
                      (p) => HandoffPatientCard(patient: p),
                    ),
                    if (updated != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Last updated ${DateFormat('d MMM yyyy, h:mm a').format(updated.toLocal())}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                    if (handoff.acknowledgementNote.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Acknowledgement: ${handoff.acknowledgementNote}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (canEdit) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isBusy
                                ? null
                                : () => context.push(
                                      AppRoutes.spaceHandoffEditPath(
                                        widget.spaceId,
                                        handoff.id,
                                      ),
                                    ),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _isBusy ? null : () => _deleteDraft(handoff),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ),
                      ],
                      if (canAcknowledge)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                _isBusy ? null : () => _acknowledge(handoff),
                            icon: _isBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('Acknowledge'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.handoff});

  final HandoffModel handoff;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        HandoffPriorityColors.handoffStatusColor(handoff.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${handoff.shiftType.value} shift',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    HandoffPriorityColors.handoffStatusLabel(handoff.status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (handoff.shiftDate != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMd().format(handoff.shiftDate!.toLocal()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const Divider(height: 24),
            _PersonRow(
              label: 'From',
              name: handoff.fromUser.displayName,
            ),
            const SizedBox(height: 8),
            _PersonRow(
              label: 'Assigned to',
              name: handoff.toUser.displayName,
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.label,
    required this.name,
    this.highlight = false,
  });

  final String label;
  final String name;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: highlight ? AppColors.primary : null,
                  fontWeight: highlight ? FontWeight.w600 : null,
                ),
          ),
        ),
      ],
    );
  }
}
