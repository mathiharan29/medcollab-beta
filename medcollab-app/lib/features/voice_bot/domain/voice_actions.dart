import 'package:equatable/equatable.dart';

/// Someone or something the voice bot can address (issue 14).
/// [id] is `p:<userId>` for a person, `c:<channelId>` for a chat — the same
/// scheme the server's /api/assistant/interpret uses.
class VoiceTarget extends Equatable {
  const VoiceTarget({
    required this.id,
    required this.name,
    this.kind = 'person',
    this.username,
    this.speciality,
    this.spaceId,
  });

  final String id;
  final String name;

  /// person | needl | group | dm
  final String kind;
  final String? username;
  final String? speciality;
  final String? spaceId;

  bool get isPerson => id.startsWith('p:');
  String get rawId => id.substring(2);

  factory VoiceTarget.fromJson(Map<String, dynamic> j) => VoiceTarget(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'person',
        spaceId: j['spaceId']?.toString(),
      );

  @override
  List<Object?> get props => [id, name, kind, username, speciality, spaceId];
}

/// The doctor's own circle: who and what the bot may act on.
class VoiceDirectory {
  const VoiceDirectory({this.people = const [], this.chats = const []});
  final List<VoiceTarget> people;
  final List<VoiceTarget> chats;
}

class VoicePatient extends Equatable {
  const VoicePatient({required this.bed, this.alias = '', this.notes = '', this.tasks = const []});
  final String bed;
  final String alias;
  final String notes;
  final List<String> tasks;

  factory VoicePatient.fromJson(Map<String, dynamic> j) => VoicePatient(
        bed: j['bed']?.toString() ?? '',
        alias: j['alias']?.toString() ?? '',
        notes: j['notes']?.toString() ?? '',
        tasks: (j['tasks'] is List) ? (j['tasks'] as List).map((e) => e.toString()).toList() : const [],
      );

  @override
  List<Object?> get props => [bed, alias, notes, tasks];
}

/// A PROPOSED action. Nothing happens until the doctor confirms it.
sealed class VoiceAction extends Equatable {
  const VoiceAction();

  /// One line for the confirm card ("Send to Dr Arjun Rao").
  String get title;

  static VoiceAction? fromJson(Map<String, dynamic> j) {
    final to = j['to'] is Map ? VoiceTarget.fromJson(Map<String, dynamic>.from(j['to'] as Map)) : null;
    switch (j['type']) {
      case 'send_message':
        if (to == null) return null;
        return SendMessageAction(to: to, text: j['text']?.toString() ?? '');
      case 'open_chat':
        return to == null ? null : OpenChatAction(to);
      case 'create_handoff':
        if (to == null) return null;
        return HandoffAction(
          to: to,
          shift: j['shift']?.toString() ?? 'night',
          summary: j['summary']?.toString() ?? '',
          patients: (j['patients'] is List)
              ? (j['patients'] as List).whereType<Map>().map((m) => VoicePatient.fromJson(Map<String, dynamic>.from(m))).toList()
              : const [],
        );
      case 'mark_alerts_read':
        return const MarkAlertsReadAction();
      case 'set_availability':
        return SetAvailabilityAction(j['status']?.toString() ?? 'available');
      case 'search':
        return SearchAction(j['query']?.toString() ?? '');
      case 'ask_clarification':
        return ClarifyAction(j['question']?.toString() ?? '');
      case 'reply':
        final text = j['text']?.toString().trim() ?? '';
        return text.isEmpty ? null : ReplyAction(text);
    }
    return null;
  }
}

class SendMessageAction extends VoiceAction {
  const SendMessageAction({required this.to, required this.text});
  final VoiceTarget to;
  final String text;
  @override
  String get title => 'Send to ${to.name}';
  @override
  List<Object?> get props => [to, text];
}

class OpenChatAction extends VoiceAction {
  const OpenChatAction(this.to);
  final VoiceTarget to;
  @override
  String get title => 'Open chat with ${to.name}';
  @override
  List<Object?> get props => [to];
}

class HandoffAction extends VoiceAction {
  const HandoffAction({
    required this.to,
    this.shift = 'night',
    this.summary = '',
    this.patients = const [],
    this.unclear = const [],
  });
  final VoiceTarget to;
  final String shift;
  final String summary;
  final List<VoicePatient> patients;

  /// Parts of what was heard that were NOT put into the draft (shown on the
  /// card so a misheard bed or summary is never silently accepted).
  final List<String> unclear;
  @override
  String get title => 'Draft handoff to ${to.name}';
  @override
  List<Object?> get props => [to, shift, summary, patients, unclear];
}

class MarkAlertsReadAction extends VoiceAction {
  const MarkAlertsReadAction();
  @override
  String get title => 'Mark all alerts as read';
  @override
  List<Object?> get props => const [];
}

class SetAvailabilityAction extends VoiceAction {
  const SetAvailabilityAction(this.status);
  final String status;
  @override
  String get title => 'Set status: ${status.replaceAll('_', ' ')}';
  @override
  List<Object?> get props => [status];
}

class SearchAction extends VoiceAction {
  const SearchAction(this.query);
  final String query;
  @override
  String get title => 'Search “$query”';
  @override
  List<Object?> get props => [query];
}

class NavigateAction extends VoiceAction {
  const NavigateAction(this.tab);

  /// home | messages | handoffs | alerts | profile
  final String tab;
  @override
  String get title => 'Open ${tab[0].toUpperCase()}${tab.substring(1)}';
  @override
  List<Object?> get props => [tab];
}

/// The bot needs one answer (e.g. which of two doctors). [choices] are the
/// candidates; picking one re-runs the request with that target.
class ClarifyAction extends VoiceAction {
  const ClarifyAction(this.question, {this.choices = const [], this.rebuild, this.unmatched = false, this.peopleOnly = false});
  final String question;
  final List<VoiceTarget> choices;

  /// Rebuilds the original request (send / handoff / open) for the target
  /// the doctor picks, so picking keeps the message or beds that were said.
  final VoiceAction Function(VoiceTarget)? rebuild;

  /// The spoken name matched nobody: no choices are offered (no guessing);
  /// the panel lets the doctor pick from the full colleague list instead.
  final bool unmatched;

  /// The request needs a person (handoff), not a chat.
  final bool peopleOnly;
  @override
  String get title => question;
  @override
  List<Object?> get props => [question, choices, unmatched];
}

/// The assistant's answer to a question (nothing happens in the app).
class ReplyAction extends VoiceAction {
  const ReplyAction(this.text);
  final String text;
  @override
  String get title => text;
  @override
  List<Object?> get props => [text];
}
