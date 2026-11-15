class AppConfig {
  const AppConfig._();

  /// Public OAuth 2.0 Web Client ID (serverClientId) used by Google Sign-In
  /// to issue a cryptographically signed `id_token` for `ucapkas_backend`.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '118443733579-r8d0qj2t3e3rtvo5rfo6gk5vp6cndknp.apps.googleusercontent.com',
  );

  /// Public OAuth 2.0 Mobile Client ID.
  static const String googleMobileClientId = String.fromEnvironment(
    'GOOGLE_MOBILE_CLIENT_ID',
    defaultValue:
        '118443733579-qmrroh69gspf4jkafl1mfogte03pc32e.apps.googleusercontent.com',
  );
}
