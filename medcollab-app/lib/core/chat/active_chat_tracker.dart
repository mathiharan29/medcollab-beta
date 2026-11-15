/// Tracks which chat the user is currently viewing (channel / DM).
/// Used to suppress local banners and avoid unread spam while reading.
class ActiveChatTracker {
  ActiveChatTracker._();
  static final ActiveChatTracker instance = ActiveChatTracker._();

  String? _channelId;
  bool _foreground = true;

  String? get channelId => _channelId;

  void enter(String channelId) {
    _channelId = channelId;
    // Reading the chat clears its shade notification, like WhatsApp (REQ 4).
    onEnter?.call(channelId);
  }

  /// Set at startup (kept as a hook so this file stays plugin-free for tests).
  void Function(String channelId)? onEnter;

  void leave(String channelId) {
    if (_channelId == channelId) {
      _channelId = null;
    }
  }

  /// App moved to / from the background. A chat left open behind the home
  /// screen is NOT being read: its new alerts must stay unread until the
  /// doctor comes back (then they are cleared, see [setForeground]).
  void setForeground(bool foreground) {
    if (foreground == _foreground) return;
    _foreground = foreground;
    final id = _channelId;
    if (foreground && id != null) onEnter?.call(id);
  }

  bool get isForeground => _foreground;

  bool isViewing(String? channelId) {
    if (!_foreground) return false;
    if (channelId == null || channelId.isEmpty || _channelId == null) {
      return false;
    }
    return _channelId == channelId;
  }
}
