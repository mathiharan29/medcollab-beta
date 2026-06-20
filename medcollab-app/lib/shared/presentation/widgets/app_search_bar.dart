import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_decorations.dart';
import 'package:medcollab_app/core/theme/app_design_system.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';

/// MedCollab search field — stable TextField (avoids SearchBar web hit-test bugs).
class AppSearchBar extends StatefulWidget {
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
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _handleClear() {
    widget.controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final showClear =
        widget.controller.text.isNotEmpty && widget.onClear != null;

    return SizedBox(
      height: AppDesignSystem.searchBarHeight,
      child: DecoratedBox(
        decoration: AppDecorations.searchField(),
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          style: AppTextStyles.bodyMedium,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: AppDesignSystem.iconMd,
              color: AppColors.textTertiary,
            ),
            suffixIcon: showClear
                ? IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: AppDesignSystem.iconSm,
                    ),
                    color: AppColors.textTertiary,
                    onPressed: _handleClear,
                    tooltip: 'Clear',
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
