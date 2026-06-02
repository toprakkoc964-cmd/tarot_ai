/// Google Sign-In configuration for Firebase Auth.
///
/// Android requires a **Web application** OAuth 2.0 client ID as [webClientId]
/// so Firebase receives a valid `idToken`.
///
/// Set via `--dart-define=GOOGLE_WEB_CLIENT_ID=...` or update [_defaultWebClientId]
/// after copying the value from:
/// Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration.
abstract final class GoogleAuthConfig {
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  /// Paste your Firebase Web client ID here if you are not using dart-define.
  static const String _defaultWebClientId = '';

  static bool get hasWebClientId => webClientId.trim().isNotEmpty;
}
