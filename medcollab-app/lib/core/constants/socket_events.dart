/// Socket.io event names — mirrors backend `SOCKET_EVENTS`.
abstract final class SocketEvents {
  // Connection lifecycle
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String authenticate = 'authenticate';
  static const String authenticated = 'authenticated';
  static const String authError = 'auth_error';

  // Room management
  static const String joinChannel = 'join_channel';
  static const String leaveChannel = 'leave_channel';

  // Messaging (client listens; server emits after REST persist)
  static const String sendMessage = 'send_message';
  static const String newMessage = 'new_message';
  static const String messageUpdated = 'message_updated';
  static const String messageDeleted = 'message_deleted';

  // Typing indicators
  static const String typingStart = 'typing_start';
  static const String typingStop = 'typing_stop';
  static const String userTyping = 'user_typing';
  static const String userStoppedTyping = 'user_stopped_typing';

  // Presence
  static const String updateAvailability = 'update_availability';
  static const String presenceUpdate = 'presence_update';

  // Notifications
  static const String newNotification = 'new_notification';

  // Handoffs
  static const String handoffSubmitted = 'handoff_submitted';

  // Errors
  static const String error = 'error';
}

/// Room naming convention used by the backend.
abstract final class SocketRooms {
  static String user(String userId) => 'user:$userId';
  static String space(String spaceId) => 'space:$spaceId';
  static String channel(String channelId) => 'channel:$channelId';
}
