import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_design_system.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';

/// Standard avatar — clinical initials, optional presence ring.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.imageUrl,
    this.size = AppDesignSystem.avatarMd,
    this.showPresence = false,
    this.isOnline = false,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool showPresence;
  final bool isOnline;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: AppColors.bubbleBorderMine),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorWidget: (_, __, ___) =>
                  _Initials(initial: _initial, size: size),
            )
          : _Initials(initial: _initial, size: size),
    );

    if (!showPresence) return avatar;

    final dotSize = (size * 0.26).clamp(8.0, 12.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.success : AppColors.offDuty,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: AppColors.onPrimaryContainer,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Centered loading indicator.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({this.label, super.key});

  final String? label;

  static Widget centered({String? label}) {
    return AppLoadingIndicator(label: label);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(label!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
