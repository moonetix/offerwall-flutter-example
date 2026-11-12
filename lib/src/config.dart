/// Build-time settings. Pass them with --dart-define, see the README.
abstract final class AppConfig {
  /// The App ID from the top of your offerwall's settings page in the
  /// Moonetix dashboard. Public, safe to ship in the app.
  static const String moonetixAppId = String.fromEnvironment('MOONETIX_APP_ID');

  /// Your own server (the one in server/). Use https in production.
  /// 10.0.2.2 is your computer as seen from the Android emulator.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
