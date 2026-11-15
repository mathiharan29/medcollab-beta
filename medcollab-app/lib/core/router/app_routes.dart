/// Named routes for [GoRouter].
abstract final class AppRoutes {
  static const String splash = '/';
  static const String phoneEntry = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String profileSetup = '/auth/profile';

  // Shell tabs (Sprint 7 — clinical workspace IA)
  static const String home = '/home';
  static const String messages = '/messages';
  static const String handoffs = '/handoffs';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';

  // Spaces (no longer landing page)
  static const String spacesList = '/spaces';
  static const String spaceDetail = '/spaces/:spaceId';
  static const String channel = '/spaces/:spaceId/channels/:channelId';
  static const String thread =
      '/spaces/:spaceId/channels/:channelId/threads/:messageId';
  static const String spaceMembers = '/spaces/:spaceId/members';
  static const String spaceHandoffs = '/spaces/:spaceId/handoffs';
  static const String spaceHandoffCreate = '/spaces/:spaceId/handoffs/create';
  static const String spaceHandoffDetail =
      '/spaces/:spaceId/handoffs/:handoffId';
  static const String spaceHandoffEdit =
      '/spaces/:spaceId/handoffs/:handoffId/edit';

  // Sprint 7–8 utilities
  static const String search = '/search';
  static const String bookmarks = '/bookmarks';
  static const String notificationSettings = '/notifications/settings';
  static const String startDm = '/dm/new';
  static const String dm = '/dm/:channelId';
  static const String dmThread = '/dm/:channelId/threads/:messageId';
  static const String joinInvite = '/join/:code';
  static const String scanInviteQr = '/join-scan';

  // Sprint 11 — help & support
  static const String help = '/help';
  static const String reportBug = '/report-bug';
  static const String featureRequest = '/feature-request';
  static const String feedback = '/feedback';
  static const String contact = '/contact';
  static const String privacy = '/privacy';
  static const String terms = '/terms';
  static const String developerMode = '/developer';

  static String spaceDetailPath(String spaceId) => '/spaces/$spaceId';

  static String channelPath(String spaceId, String channelId) =>
      '/spaces/$spaceId/channels/$channelId';

  static String threadPath(
    String spaceId,
    String channelId,
    String messageId,
  ) =>
      '/spaces/$spaceId/channels/$channelId/threads/$messageId';

  static String dmPath(String channelId) => '/dm/$channelId';

  /// Needl Voice (issue 13): voice-first view of any chat.
  static const String needlVoice = '/voice/:channelId';
  static String needlVoicePath(String channelId) => '/voice/$channelId';

  static String dmThreadPath(String channelId, String messageId) =>
      '/dm/$channelId/threads/$messageId';

  static String joinInvitePath(String code) => '/join/$code';

  static String spaceMembersPath(String spaceId) => '/spaces/$spaceId/members';

  static String spaceHandoffsPath(String spaceId) =>
      '/spaces/$spaceId/handoffs';

  static String spaceHandoffCreatePath(String spaceId) =>
      '/spaces/$spaceId/handoffs/create';

  static String spaceHandoffDetailPath(String spaceId, String handoffId) =>
      '/spaces/$spaceId/handoffs/$handoffId';

  static String spaceHandoffEditPath(String spaceId, String handoffId) =>
      '/spaces/$spaceId/handoffs/$handoffId/edit';

  /// Shell tab paths for bottom navigation.
  static const shellPaths = [
    home,
    messages,
    handoffs,
    notifications,
    profile,
  ];
}
