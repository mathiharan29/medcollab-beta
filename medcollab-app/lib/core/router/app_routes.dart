/// Named routes for [GoRouter].
abstract final class AppRoutes {
  static const String splash = '/';
  static const String phoneEntry = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String profileSetup = '/auth/profile';
  static const String home = '/home';
  static const String spaces = '/spaces';
  static const String spaceDetail = '/spaces/:spaceId';
  static const String channel = '/spaces/:spaceId/channels/:channelId';
  static const String thread =
      '/spaces/:spaceId/channels/:channelId/threads/:messageId';
  static const String spaceMembers = '/spaces/:spaceId/members';
  static const String handoffCreate = '/handoffs/create';
  static const String handoffDetail = '/handoffs/:handoffId';

  static String spaceDetailPath(String spaceId) => '/spaces/$spaceId';

  static String channelPath(String spaceId, String channelId) =>
      '/spaces/$spaceId/channels/$channelId';

  static String threadPath(
    String spaceId,
    String channelId,
    String messageId,
  ) =>
      '/spaces/$spaceId/channels/$channelId/threads/$messageId';

  static String spaceMembersPath(String spaceId) => '/spaces/$spaceId/members';
}
