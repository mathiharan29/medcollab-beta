import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/needl_voice/presentation/needl_voice_page.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';

/// Needl Voice — its own space, separate from text chat (beta feedback:
/// "don't mix voice chat with normal messages"). Lists the doctor's
/// conversations; recent voice activity first. Opening one starts the
/// voice-only view; nothing recorded here appears in the text chat.
class VoiceHubPage extends StatefulWidget {
  const VoiceHubPage({super.key});

  @override
  State<VoiceHubPage> createState() => _VoiceHubPageState();
}

class _VoiceHubPageState extends State<VoiceHubPage> {
  List<ChannelModel>? _chats;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final dms = await AppDependencies.instance.channelRepository.getMyDMs();
      if (!mounted) return;
      final sorted = [...dms]..sort((a, b) {
          final av = a.lastVoiceAt, bv = b.lastVoiceAt;
          if (av != null || bv != null) {
            if (av == null) return 1;
            if (bv == null) return -1;
            return bv.compareTo(av);
          }
          final at = a.lastMessage?.sentAt, bt = b.lastMessage?.sentAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
      setState(() {
        _chats = sorted;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load your conversations');
    }
  }

  String _title(ChannelModel c, String me) {
    if (c.isGroupDm) return c.displayName;
    final peer = c.peer ?? c.members.where((m) => m.id != me).firstOrNull;
    final name = peer?.displayName.trim() ?? '';
    return name.isNotEmpty ? name : c.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthBloc>().state.user?.id ?? '';
    final chats = _chats;
    final q = _query.trim().toLowerCase();
    final shown = chats == null
        ? null
        : q.isEmpty
            ? chats
            : chats.where((c) => _title(c, me).toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Needl Voice'),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.tealTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over_outlined, color: AppColors.tealDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Talk instead of type. Voice clips stay here — separate from your text chats — '
                      'and play one after another. Transcripts are made on your phone.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('voice-hub-search'),
              decoration: const InputDecoration(
                hintText: 'Find a person or Needl',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(_error!, style: AppTextStyles.body),
                    TextButton(onPressed: _load, child: const Text('Try again')),
                  ],
                ),
              )
            else if (shown == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  q.isEmpty ? 'Start a chat first — then you can talk in it here.' : 'No match',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                ),
              )
            else
              for (final c in shown)
                _VoiceChatTile(
                  key: Key('voice-hub-chat-${c.id}'),
                  title: _title(c, me),
                  isGroup: c.isGroupDm,
                  lastVoiceAt: c.lastVoiceAt,
                  lastVoiceSender: c.lastVoiceSender,
                  onTap: () => context.push(
                    AppRoutes.needlVoicePath(c.id),
                    extra: NeedlVoiceArgs(
                      title: _title(c, me),
                      subtitle: c.isGroupDm ? '${c.members.length} people' : null,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _VoiceChatTile extends StatelessWidget {
  const _VoiceChatTile({
    required this.title,
    required this.isGroup,
    required this.onTap,
    this.lastVoiceAt,
    this.lastVoiceSender,
    super.key,
  });

  final String title;
  final bool isGroup;
  final DateTime? lastVoiceAt;
  final String? lastVoiceSender;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final at = lastVoiceAt;
    final subtitle = at == null
        ? 'No voice clips yet'
        : '${lastVoiceSender ?? 'Someone'} · ${_when(at)}';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: AppColors.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.borderDefault),
      ),
      child: ListTile(
        onTap: onTap,
        leading: isGroup
            ? CircleAvatar(
                backgroundColor: AppColors.tealTint,
                child: const Icon(Icons.groups_2_outlined, color: AppColors.tealDark),
              )
            : AppAvatar(name: title, size: 40),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.cardTitle),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: at == null ? AppColors.textMuted : AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.mic_none_rounded, color: AppColors.tealDark),
      ),
    );
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    if (now.difference(t).inDays == 0 && now.day == t.day) return DateFormat.jm().format(t);
    if (now.difference(t).inDays < 7) return DateFormat.E().format(t);
    return DateFormat.MMMd().format(t);
  }
}
