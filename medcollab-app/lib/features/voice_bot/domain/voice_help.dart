/// Built-in answers for the assistant (works on the phone, no AI needed):
/// help about Vocle itself, greetings, the time and date. Anything else
/// goes to the AI half when it is switched on.
class VoiceHelp {
  const VoiceHelp._();

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static String? answer(String raw, {required DateTime now}) {
    final q = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.isEmpty) return null;
    bool has(String pattern) => RegExp(pattern).hasMatch(q);

    if (has(r'^(hi|hello|hey|good (morning|afternoon|evening)|namaste)\b')) {
      return 'Hello! Tell me what you need — for example "Message Bala that bed 7 is stable".';
    }
    if (has(r'^(thanks|thank you|thank u|great|ok thanks)\b')) return "You're welcome.";
    if (has(r'\bwhat (can|do) you do\b|\bhow (do|can) (i )?use you\b|^help$|\bwhat are you\b|\bwho are you\b')) {
      return 'I am the Vocle assistant. I can message a colleague, open a chat or Needl, draft a handoff, '
          'mark alerts read, set your status and search. I always show a card first — nothing happens until you tap.';
    }
    if (has(r'\b(what s|what is) the time\b|\bwhat time is it\b|\bcurrent time\b')) {
      final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final m = now.minute.toString().padLeft(2, '0');
      return 'It is $h:$m ${now.hour < 12 ? 'AM' : 'PM'}.';
    }
    if (has(r'\b(what s|what is) (the |today s )?date\b|\bwhat day is (it|today)\b|\btoday s date\b')) {
      return 'Today is ${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}.';
    }
    if (has(r'\bhow\b.*\b(hand ?off|handover)\b|\b(hand ?off|handover)\b.*\bhow\b')) {
      return 'Say "Hand off bed 12 to Meera, saying stable overnight". I make a draft with the beds and summary you said; '
          'you check every field on the card, then review and submit it in Handoffs.';
    }
    if (has(r'\bneedl voice\b|\bvoice (chat|mode)\b|\bwalkie\b')) {
      return 'Needl Voice is a separate voice-only space: open it from the Voice button on the Messages tab, '
          'hold the mic to talk, and clips play one after another. Transcripts are made on your phone.';
    }
    if (has(r'\bwhat is (a )?needl\b|\bneedl\b.*\bmean\b')) {
      return 'A Needl is a small private chat with up to 9 colleagues. Adding someone starts a new Needl, '
          'with the earlier messages shared if you choose.';
    }
    if (has(r'\bhow\b.*\b(status|availability)\b')) {
      return 'Say "I\'m in OT", "Set my status to on rounds" or "I\'m available".';
    }
    if (has(r'\bhow\b.*\b(message|chat|text)\b')) {
      return 'Say "Tell Arjun that bed 7 is stable" or "Open chat with Bala".';
    }
    return null;
  }
}
