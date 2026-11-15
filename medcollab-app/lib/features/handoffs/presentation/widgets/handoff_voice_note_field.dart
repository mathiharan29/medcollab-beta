import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_voice_note.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/voice_note.dart';

/// Uploads a finished recording; returns the stored note.
typedef UploadHandoffVoice = Future<HandoffVoiceNote> Function(
  VoiceNoteRecording recording,
);

/// Record / play / re-record / remove one handoff voice note (issue 5).
///
/// Used for the whole-shift summary and for each patient. The recording is
/// uploaded as soon as it stops (like patient attachments), so the form
/// only ever holds a server URL; [onBusyChanged] lets the form block Save /
/// Send until the upload has finished.
class HandoffVoiceNoteField extends StatefulWidget {
  const HandoffVoiceNoteField({
    required this.value,
    required this.onChanged,
    required this.playbackId,
    this.label = 'Voice handover',
    this.hint = 'Speak the handover — the receiver can listen to it.',
    this.onBusyChanged,
    this.upload,
    this.recorder,
    super.key,
  });

  final HandoffVoiceNote? value;
  final ValueChanged<HandoffVoiceNote?> onChanged;

  /// Stable id for one-at-a-time playback (e.g. "handoff-shift").
  final String playbackId;
  final String label;
  final String hint;
  final ValueChanged<bool>? onBusyChanged;

  /// Test seams.
  final UploadHandoffVoice? upload;
  final VoiceRecorderController? recorder;

  static const maxDuration = Duration(minutes: 5);

  @override
  State<HandoffVoiceNoteField> createState() => _HandoffVoiceNoteFieldState();
}

class _HandoffVoiceNoteFieldState extends State<HandoffVoiceNoteField> {
  late final VoiceRecorderController _rec = widget.recorder ??
      VoiceRecorderController(maxDuration: HandoffVoiceNoteField.maxDuration);
  bool _uploading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    // 5-minute cap reached: keep what was said, don't lose it.
    _rec.onAutoStop = (r) => unawaited(_upload(r));
  }

  @override
  void dispose() {
    // Leaving the form mid-recording discards that recording.
    if (widget.recorder == null) _rec.dispose();
    super.dispose();
  }

  void _setBusy(bool busy) {
    if (_uploading == busy) return;
    setState(() => _uploading = busy);
    widget.onBusyChanged?.call(busy);
  }

  Future<HandoffVoiceNote> _defaultUpload(VoiceNoteRecording r) async {
    final res = await AppDependencies.instance.mediaRepository.uploadFile(
      bytes: r.bytes,
      fileName: r.fileName,
      mimeType: r.mimeType,
      context: 'handoff',
    );
    return HandoffVoiceNote(
      url: res.url,
      durationMs: r.duration.inMilliseconds,
      mimeType: r.mimeType,
      waveform: r.waveform,
    );
  }

  Future<void> _start() async {
    setState(() => _message = null);
    unawaited(VoiceNotePlayback.instance.stopAll());
    final ok = await _rec.start();
    if (!ok && mounted) {
      setState(() => _message =
          'Microphone permission is needed to record. Allow it in Settings.');
    }
  }

  Future<void> _stop() async {
    final r = await _rec.stop();
    if (r == null) {
      if (mounted) setState(() => _message = 'Too short — hold on a little longer.');
      return;
    }
    await _upload(r);
  }

  Future<void> _upload(VoiceNoteRecording r) async {
    _setBusy(true);
    try {
      final note = await (widget.upload ?? _defaultUpload)(r);
      if (!mounted) return;
      widget.onChanged(note);
      setState(() => _message = null);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Upload failed. Check the connection and record again.');
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove voice note?'),
        content: const Text('The receiver will no longer hear it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: AppColors.statusError)),
          ),
        ],
      ),
    );
    if (ok == true) {
      unawaited(VoiceNotePlayback.instance.stopAll());
      widget.onChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _rec,
      builder: (context, _) {
        final note = widget.value;
        final Widget body;
        if (_rec.isRecording) {
          body = VoiceRecordingBar(
            key: const Key('handoff-voice-recording'),
            controller: _rec,
            onCancel: () => _rec.cancel(),
            onSend: _stop,
          );
        } else if (_uploading) {
          body = Row(
            key: const Key('handoff-voice-uploading'),
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Saving voice note…', style: AppTextStyles.body),
            ],
          );
        } else if (note != null) {
          body = Row(
            key: const Key('handoff-voice-player'),
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                  decoration: BoxDecoration(
                    color: AppColors.tealTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: VoiceNoteBubble(
                    messageId: '${widget.playbackId}:${note.url}',
                    url: note.url,
                    isMine: false,
                    durationMs: note.durationMs,
                    waveform: note.waveform,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Record again',
                onPressed: _start,
                icon: Icon(Icons.mic_none_rounded, color: AppColors.tealDark),
              ),
              IconButton(
                tooltip: 'Remove voice note',
                onPressed: _remove,
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.statusError),
              ),
            ],
          );
        } else {
          body = OutlinedButton.icon(
            key: const Key('handoff-voice-record'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: AppColors.tealDark,
              side: BorderSide(color: AppColors.tealDark.withValues(alpha: 0.5)),
            ),
            onPressed: _start,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Record voice note'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.label, style: AppTextStyles.cardTitle),
            const SizedBox(height: 2),
            Text(widget.hint, style: AppTextStyles.caption),
            const SizedBox(height: 8),
            AnimatedSwitcher(duration: const Duration(milliseconds: 150), child: body),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _message!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.statusError),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Read-only player for the handoff detail page.
class HandoffVoiceNotePlayer extends StatelessWidget {
  const HandoffVoiceNotePlayer({
    required this.note,
    required this.playbackId,
    this.label,
    super.key,
  });

  final HandoffVoiceNote note;
  final String playbackId;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('voice-$playbackId'),
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 0, 0),
              child: Text(label!, style: AppTextStyles.sectionLabel),
            ),
          VoiceNoteBubble(
            messageId: '$playbackId:${note.url}',
            url: note.url,
            isMine: false,
            durationMs: note.durationMs,
            waveform: note.waveform,
          ),
        ],
      ),
    );
  }
}
