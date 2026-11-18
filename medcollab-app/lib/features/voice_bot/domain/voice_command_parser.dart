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
    // Summary text only after an explicit separator ("saying", "notes", a
    // comma or dash). Other words after the name are never put into the
    // draft: they are shown as "not understood" so the doctor checks them
    // (field test: "hand off bed 12 to Alex the sky").
    final handoff = RegExp(
      r'^(?:please )?(?:create |make |start |draft |send |do )?(?:a )?hand ?-?(?:off|over)(?: of| for)?(?<beds> .+?)? to (?<who>.+?)(?:(?<sep>(?:,|\s-)\s*(?:saying|with notes?|notes?:?|summary:?)?|\s(?:saying|with notes?|notes?:?|summary:?))\s*(?<rest>.*))?$',
    ).firstMatch(lower);
    if (handoff != null) {
      final whoRaw = handoff.namedGroup('who')!.trim();
      final rest = handoff.namedGroup('rest')?.trim() ?? '';
      final bedsText = handoff.namedGroup('beds')?.trim() ?? '';
      final beds = _beds(bedsText);
      final unclear = <String>[
        if (bedsText.isNotEmpty && beds.isEmpty) '“$bedsText” was not understood as a bed number',
      ];
      // Longest leading part of the spoken name that matches someone; the
      // leftover words are reported, never guessed into the handoff.
      final words = whoRaw.split(' ');
      var who = whoRaw;
      for (var n = words.length; n >= 1; n--) {
        final candidate = words.take(n).join(' ');
        if (_match(candidate, peopleOnly: true, strict: true).isNotEmpty) {
          who = candidate;
          if (n < words.length) {
            unclear.add('“${_original(text, words.skip(n).join(' '))}” after the name was not used');
          }
          break;
        }
      }
      return _withTarget(who, people: true, build: (t) {
        return HandoffAction(
          to: t,
          shift: _shift(lower),
          summary: rest.isEmpty ? '' : _sentence(_original(text, rest)),
          patients: [for (final b in beds) VoicePatient(bed: b, alias: 'Bed $b')],
          unclear: unclear,
        );
      });
    }
    // ── open chat ────────────────────────────────────────────────────────
    // "open chat with Bala", "show conversation with Dr Morgan", "take me to
    // the Cedar ward chat", and — verb lost by the recogniser — "conversation
    // with Dr Morgan".
    final open = RegExp(
      r'^(?:(?:please )?(?:open|show|go to|take me to|switch to|pull up|bring up|start)(?: up)?(?: (?:the|a))?(?: (?:chat|conversation|messages|dm|chats))?(?: (?:with|to|for))? |(?:chat|conversation|messages|dm) (?:with|to) )(.+?)(?:\s+(?:chat|conversation|messages))?$',
    ).firstMatch(lower);
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
      // Never guess a near-sounding name (that could reach the wrong
      // doctor): no suggestions; the doctor picks someone explicitly from
      // their colleagues list (and the request is rebuilt for that person).
      return ParseResult([
        ClarifyAction(
          'I could not find “${who.trim()}” among your colleagues. Who did you mean?',
          rebuild: build,
          unmatched: true,
          peopleOnly: people,
        ),
      ]);
    }
    if (matches.length > 1) return ParseResult([_clarify(who, matches, build)]);
    return ParseResult([build(matches.first)]);
  }

  ClarifyAction _clarify(String who, List<VoiceTarget> matches, [VoiceAction Function(VoiceTarget)? build]) =>
      ClarifyAction(
        'Which “${who.trim()}” did you mean?',
        choices: matches.take(5).toList(),
        rebuild: build,
      );

  static const _numberWords = {
    'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6', 'seven': '7',
    'eight': '8', 'nine': '9', 'ten': '10', 'eleven': '11', 'twelve': '12', 'thirteen': '13',
    'fourteen': '14', 'fifteen': '15', 'sixteen': '16', 'seventeen': '17', 'eighteen': '18',
    'nineteen': '19', 'twenty': '20', 'thirty': '30', 'forty': '40', 'fifty': '50',
  };

  /// Bed numbers ONLY from an explicit "bed …" phrase ("bed 12", "beds 4
  /// and 5", "bed twelve"). "at 12:00" is a time, not a bed — never guessed.
  static List<String> _beds(String s) {
    final m = RegExp(r'\b(?:bed|beds|bed number|bed no)\s+([a-z0-9-]+(?:\s*(?:,|and|&)\s*(?:bed\s+)?[a-z0-9-]+)*)').firstMatch(s);
    if (m == null) return const [];
    final out = <String>[];
    for (final raw in m.group(1)!.split(RegExp(r'\s*(?:,|and|&)\s*(?:bed\s+)?'))) {
      final b = _numberWords[raw] ?? raw;
      if (b.isEmpty || !RegExp(r'^[a-z]?\d+[a-z]?(?:-\d+)?$|^[a-z]{1,3}-?\d+$').hasMatch(b)) continue;
      out.add(b.toUpperCase());
    }
    return out;
  }

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
      // "#general" is said "general" — the stripped alias is part of the
      // chat's NAME (FR-AST: "open chat with General" asked to clarify).
      final nameWords = [
        ..._tokens(t.name),
        for (final w in _tokens(t.name)) if (w.startsWith('#')) w.substring(1),
      ];
      final words = [
        ...nameWords,
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
          if (nameWords.contains(w) || w.startsWith('@') || w == t.username?.toLowerCase()) nameHits++;
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
    var m = RegExp(r"^(?:set (?:my )?(?:status|availability) (?:to |as )?|change (?:my )?(?:status|availability) (?:to |as )?|update (?:my )?(?:status|availability) (?:to |as )?|i(?: am|'m) (?:now )?|mark me (?:as )?|put me (?:as |on )?)(.+)$").firstMatch(l);
    // Same meaning, other words: "my status is on rounds", "status: in OT"
    // ("that's my status long rounds" from the recogniser) — only when a
    // status word AND a known status are both present.
    m ??= RegExp(r'\b(?:status|availability)\b(?: is| to| as|:)?(.+)$').firstMatch(l);
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
