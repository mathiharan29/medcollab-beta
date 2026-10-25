/// REST API path constants — inferred from backend route files.
abstract final class ApiEndpoints {
  static const String auth = '/api/auth';
  static const String users = '/api/users';
  static const String spaces = '/api/spaces';
  static const String channels = '/api/channels';
  static const String handoffs = '/api/handoffs';
  static const String media = '/api/media';
  static const String notifications = '/api/notifications';
  static const String health = '/health';

  // Auth
  static const String requestOtp = '$auth/request-otp';
  static const String verifyOtp = '$auth/verify-otp';
  static const String verifyMsg91Token = '$auth/verify-msg91-token';
  static const String refreshToken = '$auth/refresh';
  static const String logout = '$auth/logout';

  // Users
  static const String me = '$users/me';
  static const String myAvailability = '$users/me/availability';
  static const String myFcmToken = '$users/me/fcm-token';
  static const String searchUsers = '$users/search';
  static const String lookupUser = '$users/lookup';

  static String userById(String id) => '$users/$id';

  // Spaces
  static const String joinSpace = '$spaces/join';

  static String spaceById(String id) => '$spaces/$id';
  static String spaceInvite(String id) => '$spaces/$id/invite';
  static String spaceMembers(String id) => '$spaces/$id/members';
  static String spaceMember(String spaceId, String userId) =>
      '$spaces/$spaceId/members/$userId';
  static String spacePendingJoins(String spaceId) =>
      '$spaces/$spaceId/pending';
  static String approvePendingJoin(String spaceId, String userId) =>
      '$spaces/$spaceId/pending/$userId/approve';
  static String leaveSpace(String id) => '$spaces/$id/leave';
  static String spaceChannels(String spaceId) => '$spaces/$spaceId/channels';
  static String spaceHandoffs(String spaceId) => '$spaces/$spaceId/handoffs';

  // Channels
  static const String createDm = '$channels/dm';
  static const String listDms = '$channels/dm';

  static String channelById(String id) => '$channels/$id';
  static String channelMembers(String id) => '$channels/$id/members';
  static String pinMessage(String channelId, String messageId) =>
      '$channels/$channelId/pin/$messageId';

  // Messages (nested under channel)
  static String channelMessages(String channelId) =>
      '$channels/$channelId/messages';
  static String messageById(String channelId, String messageId) =>
      '$channels/$channelId/messages/$messageId';
  static String messageThread(String channelId, String messageId) =>
      '$channels/$channelId/messages/$messageId/thread';
  static String messageReply(String channelId, String messageId) =>
      '$channels/$channelId/messages/$messageId/reply';
  static String messageReact(String channelId, String messageId) =>
      '$channels/$channelId/messages/$messageId/react';
  static String markChannelRead(String channelId) =>
      '$channels/$channelId/messages/read';

  // Handoffs
  static String handoffById(String id) => '$handoffs/$id';
  static String submitHandoff(String id) => '$handoffs/$id/submit';
  static String acknowledgeHandoff(String id) => '$handoffs/$id/acknowledge';
  static String handoffNotes(String id) => '$handoffs/$id/notes';
  static String reassignHandoff(String id) => '$handoffs/$id/reassign';
  static const String createGroupDm = '$channels/dm/group';
  static const String createGroupDmAlias = '$channels/group-dm';
  static String expandDm(String id) => '$channels/$id/expand';
  static String renameChannel(String id) => '$channels/$id';
  static const String needlThreads = '$users/me/needl';

  // Media
  static const String uploadMedia = '$media/upload';

  static String deleteMedia(String publicId) => '$media/$publicId';

  // Notifications
  static const String unreadCount = '$notifications/unread-count';
  static const String markAllRead = '$notifications/read-all';

  static String notificationById(String id) => '$notifications/$id';
  static String markNotificationRead(String id) => '$notifications/$id/read';
  static String markNotificationUnread(String id) =>
      '$notifications/$id/unread';
  static String markNotificationsReadByChannel(String channelId) =>
      '$notifications/read-by-channel/$channelId';

  // Search
  static const String search = '/api/search';

  // Message requests (stranger DM)
  static const String messageRequests = '/api/message-requests';
  static const String messageRequestsPendingCount =
      '$messageRequests/pending-count';

  static String messageRequestAccept(String id) =>
      '$messageRequests/$id/accept';

  static String messageRequestDecline(String id) =>
      '$messageRequests/$id/decline';

  // Invite preview
  static String spaceInvitePreview(String code) =>
      '$spaces/invite/${Uri.encodeComponent(code)}';
}
