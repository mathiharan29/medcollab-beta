import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_voice_note.dart';

/// Assignee / sender write-back on a submitted handoff.
class HandoffWriteBackNote extends Equatable {
  const HandoffWriteBackNote({
    required this.id,
    required this.author,
    required this.text,
    this.kind = 'note',
    this.createdAt,
    this.voiceNote,
  });

  factory HandoffWriteBackNote.fromJson(Map<String, dynamic> json) {
    UserModel parseAuthor(dynamic raw) {
      if (raw is Map) return UserModel.fromJson(Map<String, dynamic>.from(raw));
      return UserModel(id: raw?.toString() ?? '');
    }

    return HandoffWriteBackNote(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      author: parseAuthor(json['authorId']),
      text: json['text'] as String? ?? '',
      kind: json['kind'] as String? ?? 'note',
      voiceNote: HandoffVoiceNote.fromJson(json['voiceNote']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  final String id;
  final UserModel author;
  final String text;
  final String kind;
  final DateTime? createdAt;

  /// Spoken reply (beta 11-26), alone or with [text].
  final HandoffVoiceNote? voiceNote;

  String get kindLabel => switch (kind) {
        'cant_cover' => "Can't cover",
        'covered_late' => 'Covered late',
        'reassign' => 'Reassigned',
        'missed' => 'Missed',
        _ => 'Note',
      };

  @override
  List<Object?> get props => [id, author, text, kind, createdAt, voiceNote];
}

List<HandoffWriteBackNote> parseWriteBackNotes(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map(asJsonMap)
      .whereType<Map<String, dynamic>>()
      .map(HandoffWriteBackNote.fromJson)
      .toList();
}
