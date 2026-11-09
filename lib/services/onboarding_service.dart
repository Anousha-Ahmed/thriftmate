import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the intro slides were shown on this device, so the
/// onboarding appears only on the very first launch.
class OnboardingService {
  OnboardingService._();

  static const String _seenKey = 'onboarding_seen_v1';

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
