import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_design_system.dart';

/// MedCollab search bar — 48px touch target, bordered surface.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      hintText: hintText,
      leading: const Icon(
        Icons.search,
        size: AppDesignSystem.iconMd,
        color: AppColors.textTertiary,
      ),
      onChanged: onChanged,
      trailing: [
        if (controller.text.isNotEmpty && onClear != null)
          IconButton(
            icon: const Icon(Icons.close, size: AppDesignSystem.iconSm),
            onPressed: onClear,
            color: AppColors.textTertiary,
          ),
      ],
    );
  }
}
