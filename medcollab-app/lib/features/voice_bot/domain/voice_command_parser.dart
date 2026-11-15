import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';

/// Result of the on-device parser: confident actions, or "not understood"
/// (then the app may ask the server's Claude half, if configured).
class ParseResult {
  const ParseResult(this.actions, {this.understood = true});
  const ParseResult.notUnderstood() : actions = const [], understood = false;
  final List<VoiceAction> actions;
  final bool understood;
}

/// Built-in, private voice command parser (issue 14 — hybrid bot, local half).
///
/// Handles the common clinical phrasings fully on the phone; nothing leaves
/// the device. Names are matched against the doctor's own circle only.
class VoiceCommandParser {
  const VoiceCommandParser(this.directory);

  final VoiceDirectory directory;

  static const _titles = {'dr', 'doctor', 'dr.', 'prof', 'sir', 'madam', 'maam', 'ma\'am'};

  ParseResult parse(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return const ParseResult.notUnderstood();
    final lower = text.toLowerCase().replaceAll(RegExp(r'[.!?]+$'), '');

    // ── alerts ───────────────────────────────────────────────────────────
    if (RegExp(r'\b(mark|clear)\b.*\b(alerts?|notifications?)\b').hasMatch(lower) ||
        RegExp(r'\b(alerts?|notifications?)\b.*\b(as )?read\b').hasMatch(lower)) {
      return const ParseResult([MarkAlertsReadAction()]);
    }

    // ── availability ─────────────────────────────────────────────────────
    final status = _availability(lower);
    if (status != null) return ParseResult([SetAvailabilityAction(status)]);

    // ── search ───────────────────────────────────────────────────────────
    final search = RegExp(r'^(?:search|find|look up|lookup)(?: for)? (.+)$').firstMatch(lower);
    if (search != null) {
      return ParseResult([SearchAction(_original(text, search.group(1)!))]);
    }

    // ── tabs ─────────────────────────────────────────────────────────────
    final tab = RegExp(r'^(?:open|go to|show)(?: my)? (home|messages|chats|handoffs|alerts|notifications|profile)$')
        .firstMatch(lower);
    if (tab != null) {
      final t = tab.group(1)!;
      return ParseResult([
        NavigateAction(switch (t) {
          'chats' => 'messages',
          'notifications' => 'alerts',
          _ => t,
        }),
      ]);
    }

    // ── handoff ──────────────────────────────────────────────────────────
    final handoff = RegExp(
      r'^(?:create |make |start |draft |send )?(?:a )?hand ?-?off(?: of| for)?(?<beds> .+?)? to (?<who>.+?)(?:,|\.| -| saying| with notes?| notes?)?(?<rest> .*)?$',
    ).firstMatch(lower);
    if (handoff != null) {
      final who = handoff.namedGroup('who')!;
      final rest = handoff.namedGroup('rest')?.trim() ?? '';
      final bedsText = handoff.namedGroup('beds')?.trim() ?? '';
      return _withTarget(who, people: true, build: (t) {
        final beds = RegExp(r'\b(?:bed|beds)\s+([a-z0-9-]+(?:\s*(?:,|and)\s*[a-z0-9-]+)*)')
            .firstMatch(bedsText)
            ?.group(1)
            ?.split(RegExp(r'\s*(?:,|and)\s*'))
            .where((b) => b.isNotEmpty)
            .toList() ??
            const <String>[];
        return HandoffAction(
          to: t,
          shift: _shift(lower),
          summary: rest.isEmpty ? '' : _original(text, rest),
          patients: [for (final b in beds) VoicePatient(bed: b.toUpperCase(), alias: 'Bed ${b.toUpperCase()}')],
        );
      });
    }

    // ── open chat ────────────────────────────────────────────────────────
    final open = RegExp(r'^(?:open|show|go to)(?: the)?(?: chat| conversation)?(?: with)? (.+?)(?:\s+chat)?$').firstMatch(lower);
    if (open != null) {
      return _withTarget(open.group(1)!, build: OpenChatAction.new);
    }

    // ── send message ─────────────────────────────────────────────────────
    final send = RegExp(
      r'^(?:please )?(?:send|message|text|tell|inform|ping|ask)(?: a message)?(?: to)? (?<who>.+?)(?:,| that| saying| to say|:| -)\s*(?<msg>.+)$',
    ).firstMatch(lower);
    // A separator only splits name from message when the part before it IS
    // a name: in "tell Arjun bed 7 is stable, BP 120/80" the comma belongs
    // to the message (found on device).
    final sendWho = send?.namedGroup('who');
    if (send != null && _match(sendWho!, strict: true).isNotEmpty) {
      final verb = lower.split(' ').first == 'please' ? lower.split(' ')[1] : lower.split(' ').first;
      var msg = _original(text, send.namedGroup('msg')!);
      if (verb == 'ask') msg = _askPhrasing(msg);
      return _withTarget(sendWho, build: (t) => SendMessageAction(to: t, text: _sentence(msg)));
    }
    // "tell Bala bed 7 is stable" (no separator): longest name prefix wins.
    final bare = RegExp(r'^(?:please )?(send|message|text|tell|ping|ask)(?: to)? (.+)$').firstMatch(lower);
    if (bare != null) {
      final words = bare.group(2)!.split(' ');
      for (var n = words.length - 1; n >= 1; n--) {
        final who = words.take(n).join(' ');
        // No separator: every word of the name part must belong to the
        // person ("Bala bed 7…" must not read "bed" as part of the name).
        final matches = _match(who, strict: true);
        if (matches.isEmpty) continue;
        var msg = _original(text, words.skip(n).join(' '));
        if (bare.group(1) == 'ask') msg = _askPhrasing(msg);
        if (matches.length > 1) return ParseResult([_clarify(who, matches)]);
        return ParseResult([SendMessageAction(to: matches.first, text: _sentence(msg))]);
      }
    }
    if (send != null) {
      // Clearly a "send to someone" request, but nobody matched: ask.
      final msg = _original(text, send.namedGroup('msg')!);
      return _withTarget(sendWho!, build: (t) => SendMessageAction(to: t, text: _sentence(msg)));
    }
    return const ParseResult.notUnderstood();
  }

  // ── helpers ─────────────────────────────────────────────────────────────
  ParseResult _withTarget(String who, {required VoiceAction Function(VoiceTarget) build, bool people = false}) {
    final matches = _match(who, peopleOnly: people);
    if (matches.isEmpty) {
      return ParseResult([ClarifyAction('I could not find “${who.trim()}” among your colleagues. Who did you mean?')]);
    }
    if (matches.length > 1) return ParseResult([_clarify(who, matches)]);
    return ParseResult([build(matches.first)]);
  }

  ClarifyAction _clarify(String who, List<VoiceTarget> matches) => ClarifyAction(
        'Which “${who.trim()}” did you mean?',
        choices: matches.take(5).toList(),
      );

  static List<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9@# ]'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty && !_titles.contains(w) && w != 'and' && w != '&')
      .toList();

  /// Best matches for a spoken name in the doctor's circle.
  List<VoiceTarget> _match(String spoken, {bool peopleOnly = false, bool strict = false}) {
    final q = _tokens(spoken.replaceAll(RegExp(r"'s\b"), ''));
    if (q.isEmpty) return const [];
    final pool = [...directory.people, if (!peopleOnly) ...directory.chats];
    var best = 0;
    final scored = <(int, VoiceTarget)>[];
    for (final t in pool) {
      final words = [
        ..._tokens(t.name),
        // "#general" is said "general".
        for (final w in _tokens(t.name)) if (w.startsWith('#')) w.substring(1),
        if (t.username != null) t.username!.toLowerCase(),
        if (t.username != null) '@${t.username!.toLowerCase()}',
        ..._tokens(t.speciality ?? ''),
      ];
      var score = 0;
      var nameHits = 0;
      var misses = 0;
      for (final w in q) {
        if (words.contains(w)) {
          score += 3;
          if (_tokens(t.name).contains(w) || w.startsWith('@') || w == t.username?.toLowerCase()) nameHits++;
        } else if (w.length >= 3 && words.any((x) => x.startsWith(w))) {
          score += 1;
          nameHits++;
        } else {
          score -= 2; // a spoken word that doesn't fit this person
          misses++;
        }
      }
      if (nameHits == 0 || score <= 0 || (strict && misses > 0)) continue;
      scored.add((score, t));
      if (score > best) best = score;
    }
    final top = [for (final s in scored) if (s.$1 == best) s.$2];
    // Needl / group-DM names are made of member names, so "Arjun" ties
    // Dr Arjun Rao with every Needl he is in: the person wins a tie
    // (a chat still wins when more of its name was said).
    final people = top.where(directory.people.contains).toList();
    return people.isNotEmpty ? people : top;
  }

  static String? _availability(String l) {
    if (RegExp(r"\b(do not disturb|dnd)\b").hasMatch(l)) return 'do_not_disturb';
    final m = RegExp(r"^(?:set (?:my )?(?:status|availability) (?:to |as )?|i(?: am|'m) (?:now )?|mark me (?:as )?)(.+)$").firstMatch(l);
    if (m == null) return null;
    final s = m.group(1)!;
    if (RegExp(r'\b(ot|operation theatre|theater|surgery)\b').hasMatch(s)) return 'in_ot';
    if (RegExp(r'\bicu\b').hasMatch(s)) return 'in_icu';
    if (RegExp(r'\bon ?call\b').hasMatch(s)) return 'on_call';
    if (RegExp(r'\brounds?\b').hasMatch(s)) return 'on_rounds';
    if (RegExp(r'\b(off duty|off-duty|going home|done for the day)\b').hasMatch(s)) return 'off_duty';
    if (RegExp(r'\b(available|free|back)\b').hasMatch(s)) return 'available';
    return null;
  }

  static String _shift(String l) {
    if (l.contains('morning')) return 'morning';
    if (l.contains('evening')) return 'evening';
    return 'night';
  }

  /// Text from the original utterance (keeps the doctor's capitalisation).
  static String _original(String original, String lowerPart) {
    final i = original.toLowerCase().lastIndexOf(lowerPart.trim());
    return i < 0 ? lowerPart.trim() : original.substring(i, i + lowerPart.trim().length);
  }

  static String _askPhrasing(String m) {
    final t = m.replaceFirst(RegExp(r'^(?:to |if |whether )', caseSensitive: false), '');
    final s = _sentence(t).replaceAll(RegExp(r'[.!]$'), '');
    return s.endsWith('?') ? 'Can you ${_lowerFirst(s)}' : 'Can you ${_lowerFirst(s)}?';
  }

  static String _lowerFirst(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  static String _sentence(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}
