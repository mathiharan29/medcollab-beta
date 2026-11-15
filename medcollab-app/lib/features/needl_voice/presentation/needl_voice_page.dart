import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/voice_note.dart';
import 'package:medcollab_app/features/needl_voice/presentation/needl_voice_cubit.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';

/// Route extra for [NeedlVoicePage].
class NeedlVoiceArgs {
  const NeedlVoiceArgs({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
}

/// Needl Voice (issue 13): voice-only, to-and-fro conversation for a chat.
class NeedlVoicePage extends StatelessWidget {
  const NeedlVoicePage({
    required this.channelId,
    this.title = 'Needl Voice',
    this.subtitle,
    super.key,
  });

  final String channelId;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;
    final me = context.read<AuthBloc>().state.user?.id ?? '';
    return BlocProvider(
      create: (_) => NeedlVoiceCubit(
        channelId: channelId,
        currentUserId: me,
        messages: deps.messageRepository,
        media: deps.mediaRepository,
        socket: deps.socketClient,
        speech: deps.speechService,
      ),
      child: NeedlVoiceView(
        title: title,
        subtitle: subtitle,
        currentUserId: me,
        // Opened before the chat knew its name (tapped right away): look it up.
        resolveTitle: isPlaceholderTitle(title)
            ? () async {
                final c = (await deps.channelRepository.getChannelById(channelId)).channel;
                if (c.isGroupDm) return c.displayName;
                final peer = c.peer ?? c.members.where((m) => m.id != me).firstOrNull;
                final name = peer?.displayName.trim() ?? '';
                return name.isNotEmpty ? name : c.displayName;
              }
            : null,
      ),
    );
  }
}

/// Titles a chat shows before it has loaded.
bool isPlaceholderTitle(String t) {
  final s = t.trim().toLowerCase();
  return s.isEmpty || s == 'chat' || s == 'needl voice' || s == 'channel' ||
      s == 'direct message';
}

class NeedlVoiceView extends StatefulWidget {
  const NeedlVoiceView({
    required this.title,
    required this.currentUserId,
    this.subtitle,
    this.recorder,
    this.resolveTitle,
    super.key,
  });

  final String title;
  final Future<String> Function()? resolveTitle;
  final String? subtitle;
  final String currentUserId;

  /// Test seam.
  final VoiceRecorderController? recorder;

  @override
  State<NeedlVoiceView> createState() => _NeedlVoiceViewState();
}

class _NeedlVoiceViewState extends State<NeedlVoiceView> {
  late final VoiceRecorderController _rec = widget.recorder ??
      VoiceRecorderController(
        maxDuration: const Duration(minutes: 2),
        // 16 kHz WAV: what the on-device recognizer transcribes.
        format: VoiceRecordFormat.wav16k,
      );
  final _scroll = ScrollController();
  double _dragDx = 0, _dragDy = 0;
  bool _locked = false;

  static const _cancelDx = -110.0;
  static const _lockDy = -90.0;

  late String _title = widget.title;

  @override
  void initState() {
    super.initState();
    final resolve = widget.resolveTitle;
    if (resolve != null) {
      resolve().then((t) {
        if (mounted && t.trim().isNotEmpty) setState(() => _title = t);
      }).catchError((Object _) {});
    }
    _rec.onAutoStop = (r) => context.read<NeedlVoiceCubit>().send(r);
  }

  @override
  void dispose() {
    if (widget.recorder == null) _rec.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final cubit = context.read<NeedlVoiceCubit>();
    if (!await _rec.start()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allow microphone access to talk in Needl Voice')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    cubit.recordingStarted();
    setState(() {
      _dragDx = 0;
      _dragDy = 0;
      _locked = false;
    });
  }

  Future<void> _finish() async {
    final cubit = context.read<NeedlVoiceCubit>();
    if (!_rec.isRecording) return;
    if (_dragDx <= _cancelDx) {
      await _rec.cancel();
      cubit.recordingCancelled();
      HapticFeedback.lightImpact();
    } else {
      final r = await _rec.stop();
      if (r == null) {
        cubit.recordingCancelled();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hold the button while you talk')),
          );
        }
      } else {
        HapticFeedback.selectionClick();
        unawaited(cubit.send(r));
      }
    }
    if (mounted) setState(() => _locked = false);
  }

  void _openTranscript(MessageModel m, String senderName) {
    final status = m.content.transcriptStatus;
    final text = m.content.transcript?.trim() ?? '';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      builder: (ctx) => SafeArea(
        child: Padding(
          key: const Key('needl-voice-transcript'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.subject_rounded, color: AppColors.tealDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Transcript · $senderName',
                        style: AppTextStyles.screenTitle.copyWith(fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Made on the speaker\'s phone. Check against the voice message before acting on it.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              if (text.isNotEmpty)
                SelectableText(text, style: AppTextStyles.bodyLarge)
              else
                Text(
                  status == 'pending' || status == null && m.localOnly
                      ? 'Transcribing…'
                      : 'No transcript for this voice message (not supported on the sender\'s phone, or no clear speech).',
                  style: AppTextStyles.body,
                ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transcript copied')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                    TextButton.icon(
                      onPressed: () => AppDependencies.instance.speechService.speak(text),
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: const Text('Read aloud'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NeedlVoiceCubit>();
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        backgroundColor: AppColors.chrome,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, size: 13, color: AppColors.tealPrimary),
                const SizedBox(width: 4),
                Text(widget.subtitle ?? 'Needl Voice',
                    style: AppTextStyles.caption.copyWith(color: AppColors.tealPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          BlocBuilder<NeedlVoiceCubit, NeedlVoiceState>(
            buildWhen: (a, b) => a.autoplay != b.autoplay,
            builder: (context, s) => IconButton(
              key: const Key('needl-voice-autoplay'),
              tooltip: s.autoplay ? 'Auto-play on' : 'Auto-play off',
              onPressed: () => cubit.setAutoplay(!s.autoplay),
              icon: Icon(
                s.autoplay ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: s.autoplay ? AppColors.tealPrimary : Colors.white70,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _LiveBanner(currentUserId: widget.currentUserId),
          Expanded(
            child: BlocConsumer<NeedlVoiceCubit, NeedlVoiceState>(
              listenWhen: (a, b) => a.clips.length != b.clips.length || a.error != b.error,
              listener: (context, s) {
                if (s.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!)));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                  }
                });
              },
              builder: (context, s) {
                if (s.loading) return const Center(child: CircularProgressIndicator());
                if (s.clips.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No voice messages yet.\nHold the button below and talk — '
                        'everyone in this chat hears it, with a transcript.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                    ),
                  );
                }
                final clips = s.clips.reversed.toList();
                return ListView.builder(
                  key: const Key('needl-voice-list'),
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: clips.length,
                  itemBuilder: (context, i) {
                    final m = clips[i];
                    final mine = m.sender.id == widget.currentUserId;
                    final name = mine ? 'You' : m.sender.displayName;
                    return _VoiceCard(
                      key: Key('needl-voice-clip-${m.id}'),
                      message: m,
                      mine: mine,
                      senderName: name,
                      onTranscript: () => _openTranscript(m, name),
                    );
                  },
                );
              },
            ),
          ),
          _TalkBar(
            recorder: _rec,
            locked: _locked,
            dragDx: _dragDx,
            onStart: _start,
            onRelease: () {
              if (!_locked) _finish();
            },
            onDrag: (offset) {
              if (!_rec.isRecording || _locked) return;
              setState(() {
                _dragDx = offset.dx.clamp(-200.0, 0.0);
                _dragDy = offset.dy.clamp(-200.0, 0.0);
                if (_dragDy <= _lockDy && _dragDx > _cancelDx) {
                  _locked = true;
                  HapticFeedback.mediumImpact();
                }
              });
            },
            onSendLocked: _finish,
            onCancelLocked: () async {
              await _rec.cancel();
              cubit.recordingCancelled();
              if (mounted) setState(() => _locked = false);
            },
          ),
        ],
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.currentUserId});
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NeedlVoiceCubit, NeedlVoiceState>(
      buildWhen: (a, b) => a.recordingPeers != b.recordingPeers || a.clips != b.clips,
      builder: (context, s) {
        return ListenableBuilder(
          listenable: VoiceNotePlayback.instance,
          builder: (context, _) {
            final p = VoiceNotePlayback.instance;
            String? line;
            IconData icon = Icons.mic_rounded;
            if (s.recordingPeers.isNotEmpty) {
              line = '${s.recordingPeers.join(', ')} ${s.recordingPeers.length == 1 ? 'is' : 'are'} recording…';
            } else if (p.isPlaying && (p.currentId ?? '').startsWith('needl-voice:')) {
              final id = p.currentId!.substring('needl-voice:'.length);
              final clip = s.clips.where((c) => c.id == id).firstOrNull;
              if (clip != null) {
                line = 'Playing ${clip.sender.id == currentUserId ? 'your message' : clip.sender.displayName}';
                icon = Icons.volume_up_rounded;
              }
            }
            return AnimatedSize(
              duration: const Duration(milliseconds: 150),
              child: line == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      key: const Key('needl-voice-live'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppColors.tealTint,
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: AppColors.tealDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(line,
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.message,
    required this.mine,
    required this.senderName,
    required this.onTranscript,
    super.key,
  });

  final MessageModel message;
  final bool mine;
  final String senderName;
  final VoidCallback onTranscript;

  @override
  Widget build(BuildContext context) {
    final c = message.content;
    final time = message.createdAt == null ? '' : DateFormat.jm().format(message.createdAt!.toLocal());
    final status = c.transcriptStatus;
    final hasText = (c.transcript ?? '').trim().isNotEmpty;
    final card = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: mine ? AppColors.tealTint : AppColors.surfaceCard,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
        border: Border.all(color: AppColors.borderDefault, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(senderName,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text(time, style: AppTextStyles.timestamp),
            ],
          ),
          const SizedBox(height: 4),
          VoiceNoteBubble(
            messageId: NeedlVoiceCubit.playbackId(message.id),
            url: c.mediaUrl,
            isMine: false,
            durationMs: c.durationMs,
            waveform: c.waveform,
            sending: message.localOnly,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasText ? Icons.subject_rounded : (status == 'pending' ? Icons.more_horiz : Icons.subtitles_off_outlined),
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                hasText
                    ? 'Hold for transcript'
                    : status == 'pending' || message.localOnly
                        ? 'Transcribing…'
                        : 'No transcript',
                style: AppTextStyles.timestamp,
              ),
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            AppAvatar(name: senderName, imageUrl: message.sender.avatarUrl, size: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Semantics(
              label: 'Voice message from $senderName. Long press for transcript.',
              child: GestureDetector(
                onLongPress: onTranscript,
                onDoubleTap: onTranscript,
                child: card,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TalkBar extends StatelessWidget {
  const _TalkBar({
    required this.recorder,
    required this.locked,
    required this.dragDx,
    required this.onStart,
    required this.onRelease,
    required this.onDrag,
    required this.onSendLocked,
    required this.onCancelLocked,
  });

  final VoiceRecorderController recorder;
  final bool locked;
  final double dragDx;
  final VoidCallback onStart;
  final VoidCallback onRelease;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onSendLocked;
  final VoidCallback onCancelLocked;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final rec = recorder.isRecording;
        final levels = recorder.liveLevels;
        final cancelling = dragDx <= -110;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border(top: BorderSide(color: AppColors.borderDefault, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child: rec
                        ? Row(
                            children: [
                              Text(
                                formatVoiceDuration(recorder.elapsed),
                                key: const Key('needl-voice-timer'),
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.statusError,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomPaint(
                                  size: const Size(double.infinity, 28),
                                  painter: WaveformPainter(
                                    levels: levels.length > 48 ? levels.sublist(levels.length - 48) : levels,
                                    progress: 1,
                                    played: AppColors.tealDark,
                                    remaining: AppColors.tealDark,
                                    alignEnd: true,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Text(
                              'Hold to talk · slide ← to cancel · slide ↑ to lock',
                              style: AppTextStyles.caption,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  if (locked)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onCancelLocked,
                          icon: Icon(Icons.delete_outline_rounded, color: AppColors.statusError),
                          label: const Text('Discard'),
                        ),
                        FilledButton.icon(
                          key: const Key('needl-voice-send-locked'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(140, 52),
                            backgroundColor: AppColors.tealDark,
                          ),
                          onPressed: onSendLocked,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send'),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: rec ? 1 : 0,
                          child: Row(
                            children: [
                              Icon(Icons.chevron_left_rounded,
                                  color: cancelling ? AppColors.statusError : AppColors.textMuted),
                              Text(cancelling ? 'Release to cancel' : 'Cancel',
                                  style: AppTextStyles.caption.copyWith(
                                      color: cancelling ? AppColors.statusError : AppColors.textMuted)),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Hold to talk',
                          child: GestureDetector(
                            key: const Key('needl-voice-talk'),
                            onLongPressStart: (_) => onStart(),
                            // Absolute offset from where the finger went down.
                            onLongPressMoveUpdate: (d) => onDrag(d.localOffsetFromOrigin),
                            onLongPressEnd: (_) => onRelease(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: rec ? 92 : 80,
                              height: rec ? 92 : 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: rec ? (cancelling ? AppColors.statusError : AppColors.tealDark) : AppColors.tealDark,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.tealDark.withValues(alpha: rec ? 0.45 : 0.25),
                                    blurRadius: rec ? 24 : 12,
                                  ),
                                ],
                              ),
                              child: Icon(rec ? Icons.mic_rounded : Icons.mic_none_rounded, color: Colors.white, size: 38),
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: rec ? 1 : 0,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.tealDark),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
