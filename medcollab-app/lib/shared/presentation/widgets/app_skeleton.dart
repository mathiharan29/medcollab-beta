import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_decorations.dart';
import 'package:medcollab_app/core/theme/app_design_system.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';

/// Static skeleton placeholders — no shimmer.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    this.width,
    this.height = 14,
    this.radius = AppSpacing.radiusSm,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: AppDecorations.skeleton(radius: radius),
    );
  }
}

class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({
    this.itemCount = 6,
    this.showLeading = true,
    super.key,
  });

  final int itemCount;
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => _SkeletonRow(showLeading: showLeading),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.showLeading});

  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (showLeading) ...[
            const AppSkeletonBox(
              width: AppDesignSystem.avatarMd,
              height: AppDesignSystem.avatarMd,
              radius: AppDesignSystem.avatarMd / 2,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 148, height: 14),
                SizedBox(height: AppSpacing.xs),
                AppSkeletonBox(width: 208, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppCardSkeleton extends StatelessWidget {
  const AppCardSkeleton({this.itemCount = 4, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeletonBox(width: 4, height: 76, radius: 2),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(width: 184, height: 14),
                  SizedBox(height: AppSpacing.xs),
                  AppSkeletonBox(width: 228, height: 12),
                  SizedBox(height: AppSpacing.xs),
                  AppSkeletonBox(width: 128, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppMessageSkeleton extends StatelessWidget {
  const AppMessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        _MessageSkeletonRow(alignEnd: false, widthFactor: 0.64),
        SizedBox(height: AppSpacing.sm),
        _MessageSkeletonRow(alignEnd: true, widthFactor: 0.5),
        SizedBox(height: AppSpacing.sm),
        _MessageSkeletonRow(alignEnd: false, widthFactor: 0.58),
        SizedBox(height: AppSpacing.sm),
        _MessageSkeletonRow(alignEnd: true, widthFactor: 0.72),
      ],
    );
  }
}

class _MessageSkeletonRow extends StatelessWidget {
  const _MessageSkeletonRow({
    required this.alignEnd,
    required this.widthFactor,
  });

  final bool alignEnd;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: alignEnd
                ? AppColors.primaryContainer
                : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: alignEnd
                  ? AppColors.bubbleBorderMine
                  : AppColors.border,
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonBox(width: double.infinity, height: 12),
              SizedBox(height: AppSpacing.xs),
              AppSkeletonBox(width: 124, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
