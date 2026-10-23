import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medcollab_app/core/config/env_config.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';
import 'package:medcollab_app/core/utils/clinical_formatters.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:medcollab_app/features/dev/presentation/pages/developer_mode_page.dart';
import 'package:medcollab_app/features/profile/presentation/pages/avatar_crop_page.dart';
import 'package:medcollab_app/features/profile/presentation/widgets/availability_sheet.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state.user;
        final availability =
            user?.availability.status ?? AvailabilityStatus.available;
        final roleLine = [
          if (user?.role.label.isNotEmpty == true) user!.role.label,
          if (user?.speciality != null && user!.speciality!.isNotEmpty)
            user.speciality!,
        ].join(' · ');

        return Scaffold(
          backgroundColor: AppColors.backgroundApp,
          body: Column(
            children: [
              _ProfileHeader(
                name: user?.displayName ?? 'Doctor',
                roleLine: roleLine.isEmpty ? 'Doctor' : roleLine,
                imageUrl: user?.avatarUrl,
                availability: availability,
                onAvatarTap: user == null
                    ? null
                    : () => _openProfilePhotoSheet(context, user),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    const _SettingsSectionLabel('Workspace'),
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          icon: Icons.person_outline,
                          label: 'Edit profile',
                          subtitle: user?.institution?.isNotEmpty == true
                              ? user!.institution
                              : 'Name, role, college',
                          onTap: () => context.push(AppRoutes.editProfile),
                        ),
                        const _RowDivider(),
                        _SettingsRow(
                          icon: Icons.circle,
                          iconColor: availabilityColor(availability),
                          label: 'Availability',
                          subtitle: availabilityLabel(availability),
                          onTap: () =>
                              _showAvailabilitySheet(context, availability),
                        ),
                        const _RowDivider(),
                        _SettingsRow(
                          icon: Icons.bookmark_outline,
                          label: 'Bookmarks',
                          onTap: () => context.push(AppRoutes.bookmarks),
                        ),
                        const _RowDivider(),
                        _SettingsRow(
                          icon: Icons.grid_view_rounded,
                          label: 'My Groups',
                          onTap: () => context.push(AppRoutes.spacesList),
                        ),
                        const _RowDivider(),
                        _AppearanceRow(onTap: _showAppearanceSheet),
                        _SettingsRow(
                          icon: Icons.notifications_outlined,
                          label: 'Notification settings',
                          onTap: () =>
                              context.push(AppRoutes.notificationSettings),
                        ),
                        const _RowDivider(),
                        _SettingsRow(
                          icon: Icons.lock_outline,
                          label: 'Messaging privacy',
                        subtitle: user?.notifications
                                    .allowMessageRequestsFromAnyone ==
                                true
                            ? 'Anyone with your number can send a request'
                            : 'Only shared-group doctors can send a request',
                          onTap: () =>
                              context.push(AppRoutes.notificationSettings),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _SettingsSectionLabel('Support'),
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          icon: Icons.help_outline,
                          label: 'Help & FAQ',
                          onTap: () => context.push(AppRoutes.help),
                        ),
                        const _RowDivider(),
                        _SettingsRow(
                          icon: Icons.chat_bubble_outline,
                          label: 'Send feedback',
                          onTap: () => context.push(AppRoutes.feedback),
                        ),
                        const _RowDivider(),
                        _SettingsRow(
                          icon: Icons.bug_report_outlined,
                          label: 'Report a bug',
                          onTap: () => context.push(AppRoutes.reportBug),
                        ),
                        const _RowDivider(),
                        _SettingsRow(
                          icon: Icons.lightbulb_outline,
                          label: 'Feature request',
                          onTap: () => context.push(AppRoutes.featureRequest),
                        ),
                        const _RowDivider(),
                        _SettingsRow(
                          icon: Icons.mail_outline,
                          label: 'Contact team',
                          onTap: () => context.push(AppRoutes.contact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _SettingsSectionLabel('Legal'),
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy policy',
                          onTap: () => context.push(AppRoutes.privacy),
                        ),
                        const _RowDivider(),
                        _SettingsRow(
                          icon: Icons.description_outlined,
                          label: 'Terms of use',
                          onTap: () => context.push(AppRoutes.terms),
                        ),
                      ],
                    ),
                    if (EnvConfig.enableDeveloperTools) ...[
                      const SizedBox(height: 16),
                      const _DeveloperEntryCard(),
                    ],
                    const SizedBox(height: 16),
                    _SignOutCard(
                      enabled: !state.isLoading,
                      onTap: () => context
                          .read<AuthBloc>()
                          .add(const AuthLogoutRequested()),
                    ),
                    const SizedBox(height: 20),
                    const _VersionFooter(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openProfilePhotoSheet(
    BuildContext context,
    UserModel user,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (sheetContext) {
        final roleLine = [
          if (user.role.label.isNotEmpty) user.role.label,
          if (user.speciality != null && user.speciality!.isNotEmpty)
            user.speciality!,
        ].join(' · ');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAvatar(
                  name: user.displayName,
                  imageUrl: user.avatarUrl,
                  size: 120,
                  foregroundColor: AppColors.tealPrimary,
                ),
                const SizedBox(height: 14),
                Text(
                  user.displayName,
                  style: AppTextStyles.screenTitle.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                if (roleLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    roleLine,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (user.institution != null &&
                    user.institution!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.institution!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Change photo'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickCropAndUpload(context, ImageSource.gallery);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickCropAndUpload(context, ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCropAndUpload(
    BuildContext context,
    ImageSource source,
  ) async {
    final cropped = await AvatarCropPage.pickAndCrop(context, source: source);
    if (cropped == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading photo…')),
    );

    try {
      final deps = AppDependencies.instance;
      final upload = await deps.mediaRepository.uploadFile(
        bytes: cropped,
        fileName: 'avatar.jpg',
        mimeType: 'image/jpeg',
        context: 'avatar',
      );
      if (upload.url.isEmpty) throw StateError('No URL from upload');
      final user = await deps.userRepository.updateAvatarUrl(upload.url);
      if (!context.mounted) return;
      context.read<AuthBloc>().add(AuthUserUpdated(user));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile photo')),
      );
    }
  }

  Future<void> _showAvailabilitySheet(
    BuildContext context,
    AvailabilityStatus current,
  ) =>
      showAvailabilitySheet(context, current);

  Future<void> _showAppearanceSheet(BuildContext context) async {
    final cubit = context.read<ThemeModeCubit>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (ctx) => SafeArea(
        child: BlocBuilder<ThemeModeCubit, ThemeSettingsState>(
          bloc: cubit,
          builder: (ctx, themeState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Appearance',
                  style: AppTextStyles.screenTitle.copyWith(fontSize: 16),
                ),
              ),
              for (final mode in ThemeMode.values)
                ListTile(
                  leading: Icon(
                    switch (mode) {
                      ThemeMode.light => Icons.light_mode_outlined,
                      ThemeMode.dark => Icons.dark_mode_outlined,
                      ThemeMode.system => Icons.settings_suggest_outlined,
                    },
                    color: AppColors.textSecondary,
                  ),
                  title: Text(
                    _themeModeLabel(mode),
                    style: AppTextStyles.cardTitle,
                  ),
                  trailing: themeState.mode == mode
                      ? const Icon(Icons.check, color: AppColors.tealPrimary)
                      : null,
                  onTap: () {
                    cubit.setMode(mode);
                  },
                ),
              const Divider(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color theme',
                    style: AppTextStyles.screenTitle.copyWith(fontSize: 16),
                  ),
                ),
              ),
              for (final palette in ThemePalette.values)
                ListTile(
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: palette.primary,
                  ),
                  title: Text(palette.label, style: AppTextStyles.cardTitle),
                  trailing: themeState.palette == palette
                      ? Icon(Icons.check, color: palette.primary)
                      : null,
                  onTap: () {
                    cubit.setPalette(palette);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

String _themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System default',
    };

/// "Appearance" row (+ trailing divider). Hidden when no [ThemeModeCubit] is
/// provided above (e.g. isolated widget tests).
class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({required this.onTap});

  final Future<void> Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    ThemeModeCubit? cubit;
    try {
      cubit = context.read<ThemeModeCubit>();
    } catch (_) {
      cubit = null;
    }
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<ThemeModeCubit, ThemeSettingsState>(
      bloc: cubit,
      builder: (context, themeState) => Column(
        children: [
          _SettingsRow(
            icon: Icons.brightness_6_outlined,
            label: 'Appearance',
            subtitle: _themeModeLabel(themeState.mode),
            onTap: () => onTap(context),
          ),
          const _RowDivider(),
        ],
      ),
    );
  }
}

class _DeveloperEntryCard extends StatelessWidget {
  const _DeveloperEntryCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: DeveloperModePage.isUnlocked(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return _SettingsCard(
          children: [
            _SettingsRow(
              icon: Icons.developer_mode_outlined,
              label: 'Developer Mode',
              onTap: () => context.push(AppRoutes.developerMode),
            ),
          ],
        );
      },
    );
  }
}

class _VersionFooter extends StatefulWidget {
  const _VersionFooter();

  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  int _longPressCount = 0;

  Future<void> _onLongPress() async {
    if (!EnvConfig.enableDeveloperTools) return;

    _longPressCount++;
    if (_longPressCount >= 5) {
      await _unlockAndOpen();
      return;
    }

    final pinController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock Developer Mode'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PIN',
            hintText: 'Enter beta PIN',
          ),
          autofocus: true,
          onSubmitted: (_) {
            final match =
                pinController.text.trim() == DeveloperModePage.unlockPin;
            Navigator.pop(ctx, match);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final match =
                  pinController.text.trim() == DeveloperModePage.unlockPin;
              Navigator.pop(ctx, match);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (!mounted || ok == null) return;
    if (ok) {
      await _unlockAndOpen();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  Future<void> _unlockAndOpen() async {
    await DeveloperModePage.setUnlocked(true);
    _longPressCount = 0;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Developer Mode unlocked')),
    );
    context.push(AppRoutes.developerMode);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              'Vocle closed beta ${AppConstants.appVersionLabel}',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Clinical collaboration for hospital teams',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.roleLine,
    required this.availability,
    this.imageUrl,
    this.onAvatarTap,
  });

  final String name;
  final String roleLine;
  final String? imageUrl;
  final AvailabilityStatus availability;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final pillColor = availabilityColor(availability);

    return Container(
      width: double.infinity,
      color: AppColors.navyPrimary,
      padding: EdgeInsets.fromLTRB(16, top + 20, 16, 28),
      child: Column(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.tealPrimary, width: 2.5),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: AppAvatar(
                    name: name,
                    imageUrl: imageUrl,
                    size: 64,
                    foregroundColor: AppColors.tealPrimary,
                  ),
                ),
                if (onAvatarTap != null)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.tealPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.navyPrimary,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: AppColors.navyPrimary,
                    ),
                  ),
              ],
            ),
          ),
          if (onAvatarTap != null) ...[
            const SizedBox(height: 6),
            Text(
              'Tap photo to view profile',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            roleLine,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: pillColor.withValues(alpha: 0.18),
              borderRadius: AppRadius.pill,
              border: Border.all(color: pillColor.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: pillColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  availabilityLabel(availability),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: pillColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.sectionLabel.copyWith(
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderDefault, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: subtitle == null ? 52 : 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Icon(
                  icon,
                  size: icon == Icons.circle ? 12 : 18,
                  color: iconColor ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.cardTitle),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTextStyles.caption.copyWith(
                          color: iconColor ?? AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 58,
      color: AppColors.borderLight,
    );
  }
}

class _SignOutCard extends StatelessWidget {
  const _SignOutCard({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.card,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.emergencyBorder, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 18,
                color: enabled
                    ? AppColors.emergencyRed
                    : AppColors.emergencyRed.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Text(
                'Sign out',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? AppColors.emergencyRed
                      : AppColors.emergencyRed.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
