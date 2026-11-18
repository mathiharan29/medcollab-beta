import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the phone can do with speech (issues 13 + 14).
class SpeechCapabilities {
  const SpeechCapabilities({
    this.available = false,
    this.onDevice = false,
    this.fileInput = false,
    this.tts = false,
  });

  /// A speech recognizer exists on this phone.
  final bool available;

  /// Recognition runs fully on the phone (Android 12+ on-device model).
  final bool onDevice;

  /// Can transcribe a recorded clip (Android 13+); else live only.
  final bool fileInput;

  /// Can speak replies (text-to-speech).
  final bool tts;
}

/// Live recognition events for the voice bot.
sealed class SpeechEvent {
  const SpeechEvent();
}

class SpeechPartial extends SpeechEvent {
  const SpeechPartial(this.text);
  final String text;
}

class SpeechFinal extends SpeechEvent {
  const SpeechFinal(this.text, {this.alternatives = const [], this.confidence, this.engine});
  final String text;

  /// The recogniser's other hypotheses, best first (excluding [text]).
  final List<String> alternatives;

  /// 0..1 when the recogniser reports one; null when it does not.
  final double? confidence;

  /// on_device | online — which recogniser produced the result.
  final String? engine;
}

class SpeechLevel extends SpeechEvent {
  const SpeechLevel(this.level);

  /// 0..1 loudness for the listening animation.
  final double level;
}

class SpeechError extends SpeechEvent {
  const SpeechError(this.code, this.message);

  /// no_match | timeout | stalled | no_permission | busy | network |
  /// language | unavailable | error
  final String code;
  final String message;
}

/// On-device speech, through the app's own Android bridge (`vocle/speech`):
/// Android's recognizer for live listening and for transcribing recorded
/// clips, and Android text-to-speech. No audio is sent to Vocle's server.
abstract class SpeechService {
  Future<SpeechCapabilities> capabilities();

  /// Transcribe a 16 kHz mono PCM16 WAV file. Null when not possible
  /// (old Android, no recognizer, no speech in the clip).
  Future<String?> transcribeFile(String wavPath, {String language});

  /// Start listening; events until [SpeechFinal] or [SpeechError].
  Stream<SpeechEvent> listen({String language});
  Future<void> stopListening();
  Future<void> cancelListening();

  Future<void> speak(String text, {String language});
  Future<void> stopSpeaking();
}

class PlatformSpeechService implements SpeechService {
  PlatformSpeechService();

  static const _channel = MethodChannel('vocle/speech');
  static const _events = EventChannel('vocle/speech/events');

  /// en-IN by default: Indian English names, drug names and accents.
  static const defaultLanguage = 'en-IN';

  /// Words the recogniser should lean towards (Android 13+): the doctor's
  /// colleague and chat names, so "Bala" is not heard as "mama".
  List<String> hints = const [];

  /// Microphone access: 'granted' | 'denied' | 'blocked' (denied with
  /// "don't ask again" — only Settings can change it). [request] shows the
  /// system prompt when Android still allows it.
  Future<String> micPermission({bool request = true}) async {
    try {
      return await _channel.invokeMethod<String>('micPermission', {'request': request}) ?? 'denied';
    } on MissingPluginException {
      return 'granted'; // not Android (tests / desktop)
    } on PlatformException {
      return 'denied';
    }
  }

  Future<void> openAppSettings() => _channel.invokeMethod<void>('openAppSettings').catchError((_) {});

  @override
  Future<SpeechCapabilities> capabilities() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('capabilities');
      return SpeechCapabilities(
        available: m?['available'] == true,
        onDevice: m?['onDevice'] == true,
        fileInput: m?['fileInput'] == true,
        tts: m?['tts'] == true,
      );
    } on MissingPluginException {
      return const SpeechCapabilities();
    } on PlatformException {
      return const SpeechCapabilities();
    }
  }

  @override
  Future<String?> transcribeFile(String wavPath, {String language = defaultLanguage}) async {
    try {
      final text = await _channel.invokeMethod<String>(
        'transcribeFile',
        {'path': wavPath, 'language': language},
      ).timeout(const Duration(minutes: 3));
      final t = text?.trim() ?? '';
      return t.isEmpty ? null : t;
    } catch (e) {
      debugPrint('transcribeFile failed: $e');
      return null;
    }
  }

  @override
  Stream<SpeechEvent> listen({String language = defaultLanguage}) {
    late StreamController<SpeechEvent> out;
    StreamSubscription<dynamic>? sub;
    out = StreamController<SpeechEvent>(
      onListen: () {
        sub = _events.receiveBroadcastStream().listen((raw) {
          if (raw is! Map) return;
          final type = raw['type']?.toString();
          final text = raw['text']?.toString() ?? '';
          switch (type) {
            case 'partial':
              out.add(SpeechPartial(text));
            case 'final':
              final alts = (raw['alternatives'] as List?)?.map((e) => e.toString()).where((e) => e.trim().isNotEmpty && e != text).toList();
              out.add(SpeechFinal(
                text,
                alternatives: alts ?? const [],
                confidence: (raw['confidence'] as num?)?.toDouble(),
                engine: raw['engine']?.toString(),
              ));
              out.close();
            case 'level':
              out.add(SpeechLevel(((raw['level'] as num?)?.toDouble() ?? 0).clamp(0, 1)));
            case 'error':
              out.add(SpeechError(raw['code']?.toString() ?? 'error', text));
              out.close();
          }
        }, onError: (Object e) {
          out.add(SpeechError('error', '$e'));
          out.close();
        });
        _channel.invokeMethod<void>('startListening', {'language': language, 'hints': hints.take(100).toList()}).catchError((Object e) {
          out.add(SpeechError(e is PlatformException ? e.code : 'unavailable', '$e'));
          out.close();
        });
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> stopListening() => _channel.invokeMethod<void>('stopListening').catchError((_) {});

  @override
  Future<void> cancelListening() => _channel.invokeMethod<void>('cancelListening').catchError((_) {});

  @override
  Future<void> speak(String text, {String language = defaultLanguage}) =>
      _channel.invokeMethod<void>('speak', {'text': text, 'language': language}).catchError((_) {});

  @override
  Future<void> stopSpeaking() => _channel.invokeMethod<void>('stopSpeaking').catchError((_) {});
}
