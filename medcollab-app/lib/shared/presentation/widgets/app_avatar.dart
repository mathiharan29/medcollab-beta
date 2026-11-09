import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_design_system.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';

const _honorifics = {'dr', 'prof', 'mr', 'mrs', 'ms', 'miss', 'sr', 'sri', 'smt'};

/// Avatar initials: up to two letters (first + last name), skipping titles.
/// "Dr Asha Rao" → "AR". Previously every doctor showed "D" (sanity F4).
String avatarInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  final meaningful =
      words.where((w) => !_honorifics.contains(w.toLowerCase())).toList();
  final parts = meaningful.isNotEmpty ? meaningful : words;
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) return first;
  return first + parts.last.characters.first.toUpperCase();
}

/// Vocle avatar — navy circle, white initials.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.imageUrl,
    this.size = AppDesignSystem.avatarMd,
    this.showPresence = false,
    this.isOnline = false,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool showPresence;
  final bool isOnline;
  final Color? backgroundColor;
  final Color? foregroundColor;

  String get _initial => avatarInitials(name);

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? VocleColors.navy,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorWidget: (_, __, ___) => _Initials(
                initial: _initial,
                size: size,
                color: foregroundColor ?? Colors.white,
              ),
            )
          : _Initials(
              initial: _initial,
              size: size,
              color: foregroundColor ?? Colors.white,
            ),
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
  const _Initials({
    required this.initial,
    required this.size,
    required this.color,
  });

  final String initial;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          color: color,
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
