import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_cubit.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';

/// Opens the voice assistant (issue 14). [create] builds the cubit so the
/// app wires real services and tests wire fakes.
Future<void> showVoiceBotSheet(
  BuildContext context, {
  required VoiceBotCubit Function() create,
  bool listenImmediately = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceCard,
    builder: (_) => BlocProvider<VoiceBotCubit>(
      create: (_) {
        final c = create();
        if (listenImmediately) unawaited(c.startListening());
        return c;
      },
      child: const VoiceBotPanel(),
    ),
  );
}

class VoiceBotPanel extends StatefulWidget {
  const VoiceBotPanel({super.key});

  @override
  State<VoiceBotPanel> createState() => _VoiceBotPanelState();
}

class _VoiceBotPanelState extends State<VoiceBotPanel> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VoiceBotCubit>();
    return BlocBuilder<VoiceBotCubit, VoiceBotState>(
      builder: (context, s) {
        final listening = s.phase == VoiceBotPhase.listening;
        final busy = s.phase == VoiceBotPhase.thinking || s.phase == VoiceBotPhase.working;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, color: AppColors.tealDark),
                    const SizedBox(width: 8),
                    Text('Vocle Assistant', style: AppTextStyles.screenTitle.copyWith(fontSize: 17)),
                    const Spacer(),
                    if (s.usedAi)
                      Tooltip(
                        message: 'Understood with AI via Vocle\'s server. You confirm every action.',
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('AI', style: AppTextStyles.badge),
                          avatar: Icon(Icons.auto_awesome, size: 14, color: AppColors.tealDark),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: _MicOrb(
                    key: const Key('voicebot-mic'),
                    active: listening,
                    level: s.level,
                    busy: busy,
                    onTap: listening ? cubit.stopListening : cubit.startListening,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  switch (s.phase) {
                    VoiceBotPhase.listening => s.heard.isEmpty ? 'Listening…' : s.heard,
                    VoiceBotPhase.thinking => '“${s.heard}”',
                    VoiceBotPhase.idle => 'Tap the mic and say what you need',
                    _ => s.heard.isEmpty ? '' : '“${s.heard}”',
                  },
                  key: const Key('voicebot-heard'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: s.phase == VoiceBotPhase.listening && s.heard.isEmpty
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
                if (busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                for (final p in s.proposals) ...[
                  const SizedBox(height: 12),
                  _ProposalCard(action: p),
                ],
                if (s.message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('voicebot-message'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: s.phase == VoiceBotPhase.error ? AppColors.statusWarnTint : AppColors.tealTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(s.message, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  key: const Key('voicebot-typed'),
                  controller: _typed,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Or type: “Tell Arjun bed 7 is stable”',
                    suffixIcon: IconButton(
                      tooltip: 'Send request',
                      icon: const Icon(Icons.arrow_upward_rounded),
                      onPressed: () {
                        final t = _typed.text;
                        _typed.clear();
                        cubit.handleText(t);
                      },
                    ),
                  ),
                  onSubmitted: (t) {
                    _typed.clear();
                    cubit.handleText(t);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MicOrb extends StatelessWidget {
  const _MicOrb({
    required this.active,
    required this.level,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final bool active;
  final double level;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double ring = 88.0 + (active ? 28.0 * level : 0.0);
    return Semantics(
      button: true,
      label: active ? 'Stop listening' : 'Start voice command',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: ring,
                height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealDark.withValues(alpha: active ? 0.18 : 0.08),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.statusError : AppColors.tealDark,
                ),
                child: Icon(
                  active ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalCard extends StatefulWidget {
  const _ProposalCard({required this.action});
  final VoiceAction action;

  @override
  State<_ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends State<_ProposalCard> {
  TextEditingController? _text;

  @override
  void initState() {
    super.initState();
    final a = widget.action;
    if (a is SendMessageAction) _text = TextEditingController(text: a.text);
  }

  @override
  void dispose() {
    _text?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VoiceBotCubit>();
    final a = widget.action;
    final to = switch (a) {
      SendMessageAction(:final to) || OpenChatAction(:final to) || HandoffAction(:final to) => to,
      _ => null,
    };
    if (a is ClarifyAction) {
      return Container(
        key: const Key('voicebot-clarify'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.question, style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
            if (a.choices.isNotEmpty) const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in a.choices)
                  ActionChip(
                    key: Key('voicebot-choice-${c.id}'),
                    avatar: AppAvatar(name: c.name, size: 22),
                    label: Text(
                      [c.name, if (c.speciality != null) c.speciality!].join(' · '),
                      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                    ),
                    onPressed: () => cubit.choose(a, c),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      key: Key('voicebot-proposal-${a.runtimeType}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (to != null) ...[
                AppAvatar(name: to.name, size: 32),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(a.title, style: AppTextStyles.cardTitle.copyWith(fontSize: 14))),
            ],
          ),
          if (a is SendMessageAction) ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('voicebot-edit-text'),
              controller: _text,
              minLines: 1,
              maxLines: 4,
              onChanged: (t) => cubit.editText(a, t),
            ),
          ],
          if (a is HandoffAction) ...[
            const SizedBox(height: 6),
            Text(
              [
                '${a.shift[0].toUpperCase()}${a.shift.substring(1)} shift',
                if (a.patients.isNotEmpty) 'Beds ${a.patients.map((p) => p.bed).join(', ')}',
                'Opens as a draft for you to review',
              ].join(' · '),
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => cubit.dismiss(a), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('voicebot-confirm'),
                style: FilledButton.styleFrom(minimumSize: const Size(112, 44)),
                onPressed: () => cubit.confirm(a),
                child: Text(switch (a) {
                  SendMessageAction() => 'Send',
                  HandoffAction() => 'Create draft',
                  OpenChatAction() || NavigateAction() || SearchAction() => 'Open',
                  _ => 'Confirm',
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
