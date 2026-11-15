import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/analytics/analytics_policy.dart';
import 'package:medcollab_app/core/config/app_version.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/shared/presentation/widgets/clinical_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug / beta-only utilities. Route is gated by [EnvConfig.enableDeveloperTools].
class DeveloperModePage extends StatefulWidget {
  const DeveloperModePage({super.key});

  static const unlockedPrefsKey = 'vocle_dev_tools_unlocked';
  static const unlockPin = '2468';

  static Future<bool> isUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(unlockedPrefsKey) ?? false;
  }

  static Future<void> setUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(unlockedPrefsKey, value);
  }

  @override
  State<DeveloperModePage> createState() => _DeveloperModePageState();
}

class _DeveloperModePageState extends State<DeveloperModePage> {
  bool _unlocked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final unlocked = await DeveloperModePage.isUnlocked();
    if (!mounted) return;
    setState(() {
      _unlocked = unlocked;
      _loading = false;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleUnlocked(bool value) async {
    await DeveloperModePage.setUnlocked(value);
    if (!mounted) return;
    setState(() => _unlocked = value);
    _toast(value ? 'Dev tools unlocked' : 'Dev tools locked');
  }

  Future<void> _seedNotifications() async {
    try {
      await AppDependencies.instance.apiClient
          .post<dynamic>('/api/dev/seed-notifications');
      if (!mounted) return;
      _toast('Seeded sample notifications');
    } catch (_) {
      if (!mounted) return;
      _toast('Seed failed — enable ENABLE_DEV_TOOLS on API or use local backend');
    }
  }

  Future<void> _generateSampleHandoff() async {
    try {
      await AppDependencies.instance.apiClient
          .post<dynamic>('/api/dev/seed-handoff');
      if (!mounted) return;
      _toast('Seeded draft handoff — check Handoffs → Drafts');
    } catch (_) {
      try {
        final spaces =
            await AppDependencies.instance.spaceRepository.getMySpaces();
        if (!mounted) return;
        if (spaces.isEmpty) {
          _toast('Join a space first');
          return;
        }
        context.push(AppRoutes.spaceHandoffCreatePath(spaces.first.id));
      } catch (_) {
        if (!mounted) return;
        _toast('Could not seed or open handoff form');
      }
    }
  }

  Future<void> _resetLocalPrefs() async {
    try {
      final deps = AppDependencies.instance;
      await deps.draftMessageService.clearAll();
      await deps.bookmarkService.clearAll();
      await deps.dashboardPreferencesService.reset();
      if (!mounted) return;
      _toast('Local drafts, bookmarks, and dashboard prefs reset');
    } catch (_) {
      if (!mounted) return;
      _toast('Could not reset local prefs');
    }
  }

  Future<void> _seedConversation() async {
    try {
      await AppDependencies.instance.apiClient
          .post<dynamic>('/api/dev/seed-conversation');
      if (!mounted) return;
      _toast('Seeded demo conversation message');
    } catch (_) {
      if (!mounted) return;
      _toast('Seed conversation unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Developer Mode'),
        backgroundColor: AppColors.backgroundApp,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Beta / debug tools. Actions use client APIs where possible.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 16),
                ClinicalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Release checks',
                        style: AppTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'App ${AppVersion.label}',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'FCM client: ${AppDependencies.instance.fcmService.isReady ? "ready" : "not ready"}',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Analytics: ${AnalyticsPolicy.statusLabel}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ClinicalCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Dev tools unlocked',
                      style: AppTextStyles.cardTitle,
                    ),
                    subtitle: Text(
                      'Persisted on this device',
                      style: AppTextStyles.caption,
                    ),
                    value: _unlocked,
                    activeColor: AppColors.tealPrimary,
                    onChanged: _toggleUnlocked,
                  ),
                ),
                const SizedBox(height: 12),
                ClinicalCard(
                  child: Column(
                    children: [
                      _DevAction(
                        icon: Icons.notifications_outlined,
                        label: 'Seed sample notifications',
                        onTap: _seedNotifications,
                      ),
                      Divider(height: 1, color: AppColors.borderLight),
                      _DevAction(
                        icon: Icons.assignment_outlined,
                        label: 'Generate sample handoff',
                        onTap: _generateSampleHandoff,
                      ),
                      Divider(height: 1, color: AppColors.borderLight),
                      _DevAction(
                        icon: Icons.chat_bubble_outline,
                        label: 'Open Start DM',
                        onTap: () => context.push(AppRoutes.startDm),
                      ),
                      Divider(height: 1, color: AppColors.borderLight),
                      _DevAction(
                        icon: Icons.forum_outlined,
                        label: 'Seed demo conversation',
                        onTap: _seedConversation,
                      ),
                      Divider(height: 1, color: AppColors.borderLight),
                      _DevAction(
                        icon: Icons.cleaning_services_outlined,
                        label: 'Reset local drafts / bookmarks',
                        onTap: _resetLocalPrefs,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DevAction extends StatelessWidget {
  const _DevAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(label, style: AppTextStyles.cardTitle),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textMuted,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
