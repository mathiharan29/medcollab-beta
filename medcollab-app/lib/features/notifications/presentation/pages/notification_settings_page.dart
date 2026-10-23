import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/features/auth/data/models/notification_preferences_model.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/clinical_card.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  NotificationPreferencesModel? _prefs;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authUser = context.read<AuthBloc>().state.user;
      if (authUser != null) {
        setState(() {
          _prefs = authUser.notifications;
          _loading = false;
        });
        return;
      }
      final user = await AppDependencies.instance.userRepository.getMe();
      if (!mounted) return;
      setState(() {
        _prefs = user.notifications;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load notification settings';
      });
    }
  }

  Future<void> _save(NotificationPreferencesModel updated) async {
    setState(() {
      _prefs = updated;
      _saving = true;
      _error = null;
    });
    try {
      final user = await AppDependencies.instance.userRepository
          .updateNotificationPreferences(updated);
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthUserUpdated(user));
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings saved')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save settings';
      });
    }
  }

  String _quietHoursLabel() {
    final start = _prefs?.quietHoursStart;
    final end = _prefs?.quietHoursEnd;
    if (start == null && end == null) return 'Not set';
    if (start != null && end != null) return '$start – $end';
    if (start != null) return 'From $start';
    return 'Until $end';
  }

  Future<void> _editQuietHours() async {
    if (_prefs == null || _saving) return;

    var start = _parseTime(_prefs!.quietHoursStart) ??
        const TimeOfDay(hour: 22, minute: 0);
    var end =
        _parseTime(_prefs!.quietHoursEnd) ?? const TimeOfDay(hour: 7, minute: 0);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickStart() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: start,
                helpText: 'Quiet hours start',
              );
              if (picked != null) setSheetState(() => start = picked);
            }

            Future<void> pickEnd() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: end,
                helpText: 'Quiet hours end',
              );
              if (picked != null) setSheetState(() => end = picked);
            }

            String fmt(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Quiet hours',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mute non-emergency notifications in this window.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Starts'),
                      trailing: Text(
                        fmt(start),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealDark,
                        ),
                      ),
                      onTap: pickStart,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ends'),
                      trailing: Text(
                        fmt(end),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealDark,
                        ),
                      ),
                      onTap: pickEnd,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Save quiet hours'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    await _save(
      _prefs!.copyWith(
        quietHoursStart: fmt(start),
        quietHoursEnd: fmt(end),
      ),
    );
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || !value.contains(':')) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notification settings'),
        backgroundColor: AppColors.background,
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppListSkeleton(itemCount: 5),
            )
          : _prefs == null
              ? Center(child: Text(_error ?? 'Settings unavailable'))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.emergency,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _SettingsSectionTitle('Alerts'),
                    ClinicalCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Emergency alerts'),
                            subtitle: const Text('Critical ward announcements'),
                            value: _prefs!.emergencyAlerts,
                            onChanged: _saving
                                ? null
                                : (v) => _save(
                                      _prefs!.copyWith(emergencyAlerts: v),
                                    ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Mentions'),
                            subtitle: const Text('@you in channels and threads'),
                            value: _prefs!.mentions,
                            onChanged: _saving
                                ? null
                                : (v) => _save(_prefs!.copyWith(mentions: v)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('New messages'),
                            subtitle: const Text('Channel activity'),
                            value: _prefs!.newMessages,
                            onChanged: _saving
                                ? null
                                : (v) =>
                                    _save(_prefs!.copyWith(newMessages: v)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Handoffs'),
                            subtitle: const Text('Shift handover updates'),
                            value: _prefs!.handoffs,
                            onChanged: _saving
                                ? null
                                : (v) => _save(_prefs!.copyWith(handoffs: v)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Read receipts (Seen by)'),
                            subtitle: const Text(
                              'Show when others read your DMs, and share yours',
                            ),
                            value: _prefs!.readReceiptsEnabled,
                            onChanged: _saving
                                ? null
                                : (v) => _save(
                                      _prefs!
                                          .copyWith(readReceiptsEnabled: v),
                                    ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Text(
                              'When off, your Seen receipts are hidden from '
                              'others in 1:1 DMs. Existing ticks may remain '
                              'until both parties refresh.',
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SettingsSectionTitle('Messaging privacy'),
                    ClinicalCard(
                      padding: EdgeInsets.zero,
                      child: SwitchListTile(
                        title: const Text('Allow message requests from anyone'),
                        subtitle: const Text(
                          'On: doctors who find your number can ask to chat. '
                          'Off: only colleagues who already share a Vocle group with you can send a request. '
                          'Chat never opens until you accept.',
                        ),
                        value: _prefs!.allowMessageRequestsFromAnyone,
                        onChanged: _saving
                            ? null
                            : (v) => _save(
                                  _prefs!.copyWith(
                                    allowMessageRequestsFromAnyone: v,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SettingsSectionTitle('Quiet hours'),
                    ClinicalCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text('Quiet hours'),
                            subtitle: Text(_quietHoursLabel()),
                            trailing: const Icon(Icons.schedule),
                            onTap: _saving ? null : _editQuietHours,
                          ),
                          if (_prefs!.quietHoursStart != null ||
                              _prefs!.quietHoursEnd != null) ...[
                            const Divider(height: 1),
                            ListTile(
                              title: const Text('Clear quiet hours'),
                              trailing: const Icon(Icons.clear),
                              onTap: _saving
                                  ? null
                                  : () => _save(
                                        _prefs!.copyWith(
                                          clearQuietHoursStart: true,
                                          clearQuietHoursEnd: true,
                                        ),
                                      ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
