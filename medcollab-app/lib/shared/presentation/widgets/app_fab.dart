import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_design_system.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';

/// MedCollab extended FAB — primary action on list screens.
class AppFab extends StatelessWidget {
  const AppFab({
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: Icon(icon, size: AppDesignSystem.iconMd),
      label: Text(label),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 0,
      highlightElevation: 0,
      extendedPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
      ),
    );
  }
}
