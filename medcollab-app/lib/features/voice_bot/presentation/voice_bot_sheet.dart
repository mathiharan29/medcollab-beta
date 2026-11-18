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
  List<VoiceTurn> initialTurns = const [],
  void Function(List<VoiceTurn> turns)? onClosed,
  Future<void> Function()? openSettings,
}) async {
  VoiceBotCubit? cubit;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceCard,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
    builder: (_) => BlocProvider<VoiceBotCubit>(
      create: (_) {
        final c = cubit = create();
        if (initialTurns.isNotEmpty) c.restoreConversation(initialTurns);
        if (listenImmediately) unawaited(c.startListening());
        return c;
      },
      child: VoiceBotPanel(openSettings: openSettings),
    ),
  );
  final c = cubit;
  if (c != null) onClosed?.call(c.state.turns);
}

class VoiceBotPanel extends StatefulWidget {
  const VoiceBotPanel({this.openSettings, super.key});
  final Future<void> Function()? openSettings;

  @override
  State<VoiceBotPanel> createState() => _VoiceBotPanelState();
}

class _VoiceBotPanelState extends State<VoiceBotPanel> {
  final _typed = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _typed.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VoiceBotCubit>();
    return BlocConsumer<VoiceBotCubit, VoiceBotState>(
      listenWhen: (a, b) => a.turns.length != b.turns.length || a.proposals != b.proposals,
      listener: (_, __) => _toBottom(),
      builder: (context, s) {
        final listening = s.phase == VoiceBotPhase.listening;
        final busy = s.phase == VoiceBotPhase.thinking || s.phase == VoiceBotPhase.working;
        // Earlier turns are shown as a conversation; the current request is
        // the big "heard" line under the mic.
        final earlier = s.turns.length > 2 && !listening
            ? s.turns.sublist(0, s.turns.length - (s.proposals.isNotEmpty || s.message.isNotEmpty ? 2 : 1))
            : listening
                ? s.turns
                : const <VoiceTurn>[];
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
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
                  if (s.turns.isNotEmpty)
                    IconButton(
                      key: const Key('voicebot-new'),
                      tooltip: 'New conversation',
                      icon: const Icon(Icons.restart_alt_rounded),
                      onPressed: cubit.newConversation,
                    ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final t in earlier) _TurnBubble(turn: t),
                      if (earlier.isNotEmpty) const SizedBox(height: 8),
                      Center(
                        child: _MicOrb(
                          key: const Key('voicebot-mic'),
                          active: listening,
                          level: s.level,
                          busy: busy,
                          onTap: listening ? cubit.stopListening : cubit.startListening,
                          onHoldStart: listening ? null : cubit.startListening,
                          onHoldEnd: cubit.stopListening,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listening
                            ? 'Tap to finish · or hold the mic while you speak'
                            : 'Tap to speak · hold to talk',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
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
                      for (final n in s.notes) ...[
                        const SizedBox(height: 8),
                        _Note(text: n),
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
                      if (s.mic == MicAccess.blocked && widget.openSettings != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('voicebot-open-settings'),
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: const Text('Open settings'),
                          onPressed: () => widget.openSettings!(),
                        ),
                      ],
                      for (final p in s.proposals) ...[
                        const SizedBox(height: 12),
                        _ProposalCard(action: p),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              TextField(
                key: const Key('voicebot-typed'),
                controller: _typed,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Type a request or a question',
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
        );
      },
    );
  }
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn});
  final VoiceTurn turn;

  @override
  Widget build(BuildContext context) {
    final mine = turn.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: mine ? AppColors.tealTint : AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(turn.text, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontSize: 13)),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('voicebot-note'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.statusWarnTint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hearing_rounded, size: 16, color: AppColors.statusWarning),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary))),
          ],
        ),
      );
}

class _MicOrb extends StatelessWidget {
  const _MicOrb({
    required this.active,
    required this.level,
    required this.busy,
    required this.onTap,
    this.onHoldStart,
    this.onHoldEnd,
    super.key,
  });

  final bool active;
  final double level;
  final bool busy;
  final VoidCallback onTap;

  /// Hold-to-talk: listening only while the finger is down — a clear
  /// boundary in a noisy ward (field finding 3).
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final double ring = 88.0 + (active ? 28.0 * level : 0.0);
    return Semantics(
      button: true,
      label: active ? 'Stop listening' : 'Start voice command',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        onLongPressStart: busy || onHoldStart == null ? null : (_) => onHoldStart!(),
        onLongPressEnd: busy || onHoldEnd == null ? null : (_) => onHoldEnd!(),
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
            if (a.unmatched && a.rebuild != null) ...[
              const SizedBox(height: 4),
              Text('I won\'t guess a name that only sounds similar.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 6),
              TextButton.icon(
                key: const Key('voicebot-pick'),
                icon: const Icon(Icons.person_search_outlined, size: 18),
                label: const Text('Choose from your colleagues'),
                onPressed: () async {
                  final options = await cubit.pickable(peopleOnly: a.peopleOnly);
                  if (!context.mounted) return;
                  final picked = await _pickTarget(context, options);
                  if (picked != null) cubit.choose(a, picked);
                },
              ),
            ],
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
    final working = context.select((VoiceBotCubit c) => c.state.phase == VoiceBotPhase.working);
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
            const SizedBox(height: 8),
            // Every field the draft will contain, spelled out — the doctor
            // checks the bed and summary, not just the recipient.
            _Field(label: 'To', value: a.to.name),
            _Field(label: 'Shift', value: '${a.shift[0].toUpperCase()}${a.shift.substring(1)}'),
            _Field(
              key: const Key('voicebot-handoff-beds'),
              label: 'Beds',
              value: a.patients.isEmpty ? 'None heard — add in the draft' : a.patients.map((p) => p.bed).join(', '),
              missing: a.patients.isEmpty,
            ),
            _Field(
              key: const Key('voicebot-handoff-summary'),
              label: 'Summary',
              value: a.summary.isEmpty ? 'None — add in the draft' : a.summary,
              missing: a.summary.isEmpty,
            ),
            for (final u in a.unclear) ...[
              const SizedBox(height: 6),
              _Note(text: u),
            ],
            const SizedBox(height: 4),
            Text('Opens as a draft for you to review', style: AppTextStyles.caption),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: working ? null : () => cubit.dismiss(a), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('voicebot-confirm'),
                style: FilledButton.styleFrom(minimumSize: const Size(112, 44)),
                // Disabled while an action runs: one tap, one write.
                onPressed: working
                    ? null
                    : () {
                        // Actions that take the doctor somewhere close the
                        // assistant first, so it never lingers over (or
                        // under) the screen it opened.
                        final navigates = a is OpenChatAction ||
                            a is NavigateAction ||
                            a is SearchAction ||
                            a is HandoffAction;
                        final route = ModalRoute.of(context);
                        final run = cubit.confirm(a);
                        if (navigates && route is ModalBottomSheetRoute && route.isActive) {
                          Navigator.of(context).removeRoute(route);
                        }
                        unawaited(run);
                      },
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

/// Explicit selection from the doctor's own colleagues and chats.
Future<VoiceTarget?> _pickTarget(BuildContext context, List<VoiceTarget> options) {
  return showDialog<VoiceTarget>(
    context: context,
    builder: (ctx) {
      var query = '';
      return StatefulBuilder(
        builder: (ctx, setState) {
          final q = query.trim().toLowerCase();
          final shown = q.isEmpty
              ? options
              : options.where((o) => o.name.toLowerCase().contains(q) || (o.username ?? '').toLowerCase().contains(q)).toList();
          return AlertDialog(
            title: const Text('Who did you mean?'),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            content: SizedBox(
              width: 360,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    key: const Key('voicebot-pick-search'),
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Search name', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final o = shown[i];
                        return ListTile(
                          key: Key('voicebot-pick-${o.id}'),
                          dense: true,
                          leading: AppAvatar(name: o.name, size: 30),
                          title: Text(o.name),
                          subtitle: Text(
                            [if (!o.isPerson) 'Chat', if (o.speciality != null) o.speciality!].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(ctx, o),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
          );
        },
      );
    },
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.missing = false, super.key});
  final String label;
  final String value;
  final bool missing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  color: missing ? AppColors.textMuted : AppColors.textPrimary,
                  fontStyle: missing ? FontStyle.italic : FontStyle.normal,
                  fontWeight: missing ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
