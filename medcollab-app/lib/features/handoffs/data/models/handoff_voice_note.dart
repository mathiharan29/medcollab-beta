import 'package:equatable/equatable.dart';

/// Spoken handover (beta 11-14, issue 5): one for the whole shift and one
/// per patient. Mirrors `voiceNoteSchema` on the backend. `recordedBy` /
/// `recordedAt` are set by the server.
class HandoffVoiceNote extends Equatable {
  const HandoffVoiceNote({
    required this.url,
    required this.durationMs,
    this.mimeType = 'audio/mp4',
    this.waveform = const [],
    this.recordedById,
    this.recordedAt,
  });

  static HandoffVoiceNote? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url']?.toString() ?? '';
    if (url.isEmpty) return null;
    final by = raw['recordedBy'];
    return HandoffVoiceNote(
      url: url,
      durationMs: (raw['durationMs'] as num?)?.toInt() ?? 0,
      mimeType: raw['mimeType']?.toString() ?? 'audio/mp4',
      waveform: raw['waveform'] is List
          ? (raw['waveform'] as List)
              .whereType<num>()
              .map((n) => n.toInt().clamp(0, 100))
              .toList()
          : const [],
      recordedById: by is Map ? by['_id']?.toString() : by?.toString(),
      recordedAt: raw['recordedAt'] != null
          ? DateTime.tryParse(raw['recordedAt'].toString())
          : null,
    );
  }

  final String url;
  final int durationMs;
  final String mimeType;
  final List<int> waveform;
  final String? recordedById;
  final DateTime? recordedAt;

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
        'url': url,
        'durationMs': durationMs,
        'mimeType': mimeType,
        if (waveform.isNotEmpty) 'waveform': waveform,
      };

  @override
  List<Object?> get props =>
      [url, durationMs, mimeType, waveform, recordedById, recordedAt];
}
