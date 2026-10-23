import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/core/utils/clinical_formatters.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';

/// Availability picker shared by Profile and Home (shift card pill).
Future<void> showAvailabilitySheet(
  BuildContext context,
  AvailabilityStatus current,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Availability',
                style: AppTextStyles.screenTitle.copyWith(fontSize: 16),
              ),
            ),
            ...AvailabilityStatus.values.map((status) {
              final color = availabilityColor(status);
              final selected = status == current;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: Icon(Icons.circle, size: 12, color: color),
                title: Text(
                  availabilityLabel(status),
                  style: AppTextStyles.cardTitle,
                ),
                subtitle: Text(
                  availabilitySubtitle(status),
                  style: AppTextStyles.caption,
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: AppColors.tealPrimary)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final deps = AppDependencies.instance;
                  final userId =
                      context.read<AuthBloc>().state.user?.id ?? '';
                  try {
                    final availability = await deps.userRepository
                        .updateAvailability(status: status);
                    if (!context.mounted) return;
                    context
                        .read<AuthBloc>()
                        .add(AuthAvailabilityUpdated(availability));
                    deps.presenceCubit.applyLocal(
                      userId: userId,
                      status: status,
                      isOnline: deps.socketClient.isConnected,
                    );
                    if (deps.socketClient.isConnected) {
                      deps.socketClient
                          .updateAvailability(status: status.value);
                    }
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not update availability'),
                      ),
                    );
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
