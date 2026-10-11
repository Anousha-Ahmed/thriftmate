/// App-wide configuration values.
class AppConfig {
  AppConfig._();

  /// Web client ID used by Google Sign-In on Android.
  ///
  /// Where to find it:
  ///   Firebase Console -> Authentication -> Sign-in method -> Google
  ///   -> "Web SDK configuration" -> "Web client ID"
  /// It looks like:  123456789-abcdefg.apps.googleusercontent.com
  ///
  /// While this is still the placeholder, the app falls back to Firebase's
  /// browser-based Google flow on phones (and Chrome always uses the popup).
  static const String googleServerClientId = '465196855268-3qtg6oh1mabu83074m64ainl5udvd1qg.apps.googleusercontent.com';

  static bool get hasGoogleServerClientId =>
      googleServerClientId.isNotEmpty &&
      !googleServerClientId.startsWith('PASTE_');
}
