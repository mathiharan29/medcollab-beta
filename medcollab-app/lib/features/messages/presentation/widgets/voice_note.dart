import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// "1:05"
String formatVoiceDuration(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Squeeze any number of loudness samples into [bars] values (0–100).
List<int> downsampleWaveform(List<int> samples, {int bars = 40}) {
  if (samples.isEmpty) return const [];
  if (samples.length <= bars) return List<int>.from(samples);
  final out = <int>[];
  final step = samples.length / bars;
  for (var i = 0; i < bars; i++) {
    final start = (i * step).floor();
    final end = math.min(samples.length, ((i + 1) * step).ceil());
    var peak = 0;
    for (var j = start; j < end; j++) {
      peak = math.max(peak, samples[j]);
    }
    out.add(peak);
  }
  return out;
}

/// dBFS (−160…0) → 0–100 bar height; −50 dB and below is silence.
int levelFromDbfs(double dbfs) {
  if (dbfs.isNaN || dbfs.isInfinite) return 0;
  return (((dbfs + 50) / 50) * 100).clamp(0, 100).round();
}

/// A finished recording ready to upload.
class VoiceNoteRecording {
  const VoiceNoteRecording({
    required this.bytes,
    required this.duration,
    required this.waveform,
    this.fileName = 'voice-note.m4a',
    this.mimeType = 'audio/mp4',
  });

  final List<int> bytes;
  final Duration duration;
  final List<int> waveform;
  final String fileName;
  final String mimeType;
}

/// Thin seam over the `record` plugin so the UI can be tested.
abstract class VoiceRecorderEngine {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Stream<double> amplitudeDbfs();
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class RecordPluginEngine implements VoiceRecorderEngine {
  final AudioRecorder _rec = AudioRecorder();

  @override
  Future<bool> hasPermission() => _rec.hasPermission();

  @override
  Future<void> start(String path) => _rec.start(
        // AAC-LC mono 32 kbps: clear speech, ~240 KB per minute.
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: path,
      );

  @override
  Stream<double> amplitudeDbfs() => _rec
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => a.current);

  @override
  Future<String?> stop() => _rec.stop();

  @override
  Future<void> cancel() => _rec.cancel();

  @override
  Future<void> dispose() => _rec.dispose();
}

enum VoiceRecorderStatus { idle, recording, denied }

/// Recording state for the composer (REQ 12).
class VoiceRecorderController extends ChangeNotifier {
  VoiceRecorderController({
    VoiceRecorderEngine? engine,
    Future<String> Function()? tempDir,
  })  : _engine = engine ?? RecordPluginEngine(),
        _tempDir = tempDir ??
            (() async => (await getTemporaryDirectory()).path);

  final VoiceRecorderEngine _engine;
  final Future<String> Function() _tempDir;

  static const maxDuration = Duration(minutes: 15);
  static const minDuration = Duration(milliseconds: 700);

  VoiceRecorderStatus status = VoiceRecorderStatus.idle;
  Duration elapsed = Duration.zero;
  final List<int> _levels = [];
  List<int> get liveLevels => List.unmodifiable(_levels);

  StreamSubscription<double>? _ampSub;
  Timer? _ticker;
  DateTime? _startedAt;
  String? _path;
  bool _disposed = false;

  /// Called when the 15-minute cap stops recording on its own.
  void Function(VoiceNoteRecording recording)? onAutoStop;

  bool get isRecording => status == VoiceRecorderStatus.recording;

  Future<bool> start() async {
    if (isRecording) return true;
    if (!await _engine.hasPermission()) {
      status = VoiceRecorderStatus.denied;
      _notify();
      return false;
    }
    final dir = await _tempDir();
    _path =
        '$dir${Platform.pathSeparator}voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _engine.start(_path!);
    _levels.clear();
    elapsed = Duration.zero;
    _startedAt = DateTime.now();
    status = VoiceRecorderStatus.recording;
    _ampSub = _engine.amplitudeDbfs().listen((db) {
      _levels.add(levelFromDbfs(db));
      _notify();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      elapsed = DateTime.now().difference(_startedAt!);
      if (elapsed >= maxDuration) {
        unawaited(stop().then((r) {
          if (r != null) onAutoStop?.call(r);
        }));
      }
      _notify();
    });
    _notify();
    return true;
  }

  /// Stops and returns the note, or null if it was too short to keep.
  Future<VoiceNoteRecording?> stop() async {
    if (!isRecording) return null;
    final duration = DateTime.now().difference(_startedAt!);
    _teardown();
    final path = await _engine.stop() ?? _path;
    status = VoiceRecorderStatus.idle;
    _notify();
    if (path == null || duration < minDuration) {
      _deleteQuietly(path);
      return null;
    }
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    _deleteQuietly(path);
    return VoiceNoteRecording(
      bytes: bytes,
      duration: duration,
      waveform: downsampleWaveform(_levels),
      fileName: 'voice-${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
  }

  Future<void> cancel() async {
    if (!isRecording) return;
    _teardown();
    await _engine.cancel();
    _deleteQuietly(_path);
    status = VoiceRecorderStatus.idle;
    _notify();
  }

  void _teardown() {
    _ampSub?.cancel();
    _ampSub = null;
    _ticker?.cancel();
    _ticker = null;
  }

  void _deleteQuietly(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final wasRecording = isRecording;
    _teardown();
    if (wasRecording) {
      // Leaving mid-recording discards it (nothing is sent).
      final path = _path;
      unawaited(_engine.cancel().whenComplete(() {
        _deleteQuietly(path);
        return _engine.dispose();
      }));
    } else {
      unawaited(_engine.dispose());
    }
    super.dispose();
  }
}

/// Replaces the composer while recording: cancel · ● 0:07 ▂▅▇ · send.
class VoiceRecordingBar extends StatelessWidget {
  const VoiceRecordingBar({
    required this.controller,
    required this.onCancel,
    required this.onSend,
    super.key,
  });

  final VoiceRecorderController controller;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final levels = controller.liveLevels;
        final shown = levels.length > 48
            ? levels.sublist(levels.length - 48)
            : levels;
        return Row(
          children: [
            IconButton(
              tooltip: 'Cancel voice message',
              onPressed: onCancel,
              icon: Icon(Icons.delete_outline, color: AppColors.statusError),
            ),
            const _BlinkingDot(),
            const SizedBox(width: 8),
            Text(
              formatVoiceDuration(controller.elapsed),
              style: AppTextStyles.body.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 28,
                child: CustomPaint(
                  painter: WaveformPainter(
                    levels: shown,
                    progress: 1,
                    played: AppColors.tealDark,
                    remaining: AppColors.tealDark,
                    alignEnd: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Send voice message',
              child: Material(
                color: AppColors.tealPrimary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSend,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.emergencyRed,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Bars with the played part highlighted.
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.levels,
    required this.progress,
    required this.played,
    required this.remaining,
    this.alignEnd = false,
  });

  final List<int> levels;
  final double progress;
  final Color played;
  final Color remaining;
  final bool alignEnd;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 2.0;
    final maxBars = (size.width / (barWidth + gap)).floor();
    if (maxBars <= 0) return;
    final data = levels.isEmpty
        ? List<int>.filled(maxBars, 8)
        : downsampleWaveform(levels, bars: maxBars);
    final total = data.length;
    final offsetX =
        alignEnd ? size.width - total * (barWidth + gap) : 0.0;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    for (var i = 0; i < total; i++) {
      final h = math.max(3.0, size.height * (data[i] / 100));
      final x = offsetX + i * (barWidth + gap) + barWidth / 2;
      paint.color = (i + 0.5) / total <= progress ? played : remaining;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.progress != progress ||
      old.levels.length != levels.length ||
      old.played != played ||
      old.remaining != remaining;
}

/// Seam over just_audio for tests.
abstract class VoicePlayerEngine {
  Future<Duration?> load(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Stream<Duration> get positions;
  Stream<bool> get playing;
  Stream<bool> get completed;
  Future<void> stop();
}

class JustAudioEngine implements VoicePlayerEngine {
  final AudioPlayer _p = AudioPlayer();

  @override
  Future<Duration?> load(String url) => _p.setUrl(url);
  @override
  Future<void> play() => _p.play();
  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> seek(Duration position) => _p.seek(position);
  @override
  Future<void> setSpeed(double speed) => _p.setSpeed(speed);
  @override
  Stream<Duration> get positions => _p.positionStream;
  @override
  Stream<bool> get playing => _p.playingStream;
  @override
  Stream<bool> get completed => _p.processingStateStream
      .map((s) => s == ProcessingState.completed);
  @override
  Future<void> stop() => _p.stop();
}

/// One voice note plays at a time across the app (like WhatsApp).
class VoiceNotePlayback extends ChangeNotifier {
  VoiceNotePlayback({VoicePlayerEngine Function()? engineFactory})
      : _factory = engineFactory ?? JustAudioEngine.new;

  static VoiceNotePlayback instance = VoiceNotePlayback();

  final VoicePlayerEngine Function() _factory;
  VoicePlayerEngine? _engine;
  final List<StreamSubscription<Object?>> _subs = [];

  String? currentId;
  bool isPlaying = false;
  bool isLoading = false;
  Duration position = Duration.zero;
  Duration? duration;
  double speed = 1;
  String? error;

  VoicePlayerEngine get _e {
    final existing = _engine;
    if (existing != null) return existing;
    final created = _factory();
    _engine = created;
    _subs
      ..add(created.positions.listen((p) {
        position = p;
        notifyListeners();
      }))
      ..add(created.playing.listen((v) {
        isPlaying = v;
        notifyListeners();
      }))
      ..add(created.completed.listen((done) async {
        if (!done) return;
        isPlaying = false;
        position = Duration.zero;
        await created.pause();
        await created.seek(Duration.zero);
        notifyListeners();
      }));
    return created;
  }

  Future<void> toggle(String id, String url, {Duration? knownDuration}) async {
    final e = _e;
    error = null;
    if (currentId == id) {
      if (isPlaying) {
        await e.pause();
      } else {
        await e.play();
      }
      return;
    }
    currentId = id;
    position = Duration.zero;
    duration = knownDuration;
    isLoading = true;
    notifyListeners();
    try {
      await e.stop();
      final loaded = await e.load(url);
      duration = loaded ?? knownDuration;
      await e.setSpeed(speed);
      isLoading = false;
      notifyListeners();
      unawaited(e.play());
    } catch (_) {
      isLoading = false;
      error = 'Could not play this voice message';
      currentId = null;
      notifyListeners();
    }
  }

  Future<void> seekFraction(String id, double fraction) async {
    if (currentId != id) return;
    final d = duration;
    if (d == null) return;
    await _e.seek(d * fraction.clamp(0.0, 1.0));
  }

  Future<void> cycleSpeed() async {
    speed = speed == 1 ? 1.5 : speed == 1.5 ? 2 : 1;
    await _e.setSpeed(speed);
    notifyListeners();
  }

  /// Stop when leaving a chat.
  Future<void> stopAll() async {
    if (_engine == null) return;
    await _engine!.stop();
    currentId = null;
    isPlaying = false;
    position = Duration.zero;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _engine = null;
    currentId = null;
    isPlaying = false;
    position = Duration.zero;
    duration = null;
    speed = 1;
  }
}

/// Voice note inside a chat bubble: ▶ ▂▅▇▅▂ 0:12 · 1.5×
class VoiceNoteBubble extends StatelessWidget {
  const VoiceNoteBubble({
    required this.messageId,
    required this.url,
    required this.isMine,
    this.durationMs,
    this.waveform = const [],
    this.sending = false,
    super.key,
  });

  final String messageId;
  final String? url;
  final bool isMine;
  final int? durationMs;
  final List<int> waveform;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final playback = VoiceNotePlayback.instance;
    final fg = isMine ? Colors.white : AppColors.textPrimary;
    final accent = isMine ? Colors.white : AppColors.tealDark;
    final muted = isMine
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.textMuted.withValues(alpha: 0.5);
    final known =
        durationMs != null ? Duration(milliseconds: durationMs!) : null;

    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final active = playback.currentId == messageId;
        final playing = active && playback.isPlaying;
        final loading = active && playback.isLoading;
        final total = (active ? playback.duration : null) ?? known;
        final pos = active ? playback.position : Duration.zero;
        final progress = total == null || total.inMilliseconds == 0
            ? 0.0
            : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        final label = active && (playing || pos > Duration.zero)
            ? formatVoiceDuration(pos)
            : total != null
                ? formatVoiceDuration(total)
                : '0:00';

        return SizedBox(
          width: 230,
          child: Row(
            children: [
              Semantics(
                button: true,
                label: playing ? 'Pause voice message' : 'Play voice message',
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: sending || loading
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        )
                      : IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: url == null || url!.isEmpty
                              ? null
                              : () => playback.toggle(
                                    messageId,
                                    url!,
                                    knownDuration: known,
                                  ),
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: accent,
                            size: 30,
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Tap the waveform to jump (while this note plays).
                        onTapDown: (d) {
                          final w = constraints.maxWidth;
                          if (w <= 0) return;
                          playback.seekFraction(
                            messageId,
                            (d.localPosition.dx / w).clamp(0.0, 1.0),
                          );
                        },
                        child: SizedBox(
                          height: 26,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: WaveformPainter(
                              levels: waveform,
                              progress: progress,
                              played: accent,
                              remaining: muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.mic, size: 13, color: muted),
                        const SizedBox(width: 2),
                        Text(
                          label,
                          style: AppTextStyles.timestamp.copyWith(
                            color: fg.withValues(alpha: 0.8),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Spacer(),
                        if (active)
                          InkWell(
                            onTap: playback.cycleSpeed,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${playback.speed == playback.speed.roundToDouble() ? playback.speed.toInt() : playback.speed}×',
                                style: AppTextStyles.timestamp.copyWith(
                                  color: fg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (active && playback.error != null)
                      Text(
                        playback.error!,
                        style: AppTextStyles.timestamp
                            .copyWith(color: AppColors.statusError),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
