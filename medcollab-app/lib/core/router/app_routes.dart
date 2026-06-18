/// Named routes for [GoRouter].
abstract final class AppRoutes {
  static const String splash = '/';
  static const String phoneEntry = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String profileSetup = '/auth/profile';
  static const String home = '/home';
  static const String spaces = '/spaces';
  static const String spaceDetail = '/spaces/:spaceId';
  static const String channel = '/channels/:channelId';
  static const String handoffCreate = '/handoffs/create';
  static const String handoffDetail = '/handoffs/:handoffId';
}
