import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import '../utils/role_router.dart';
import '../widgets/app_logo.dart';
import 'complete_profile_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

/// Branded startup gate. It keeps the Firebase session across launches and
/// shows the intro only on the very first launch.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final DateTime started = DateTime.now();

    final bool seenOnboarding = await OnboardingService.hasSeen();
    final User? user = await _restoredUser();

    Widget next;
    if (user == null) {
      next = seenOnboarding
          ? const LoginScreen()
          : const OnboardingScreen();
    } else {
      if (!seenOnboarding) await OnboardingService.markSeen();

      UserProfile? profile;
      bool couldNotLoadProfile = false;
      try {
        profile = await AuthService.instance
            .getProfile(user.uid)
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        couldNotLoadProfile = true;
      }

      if (profile != null) {
        next = homeForRole(profile.role);
      } else if (couldNotLoadProfile) {
        // Offline or rules issue: the shell handles the profile itself.
        next = homeForRole('buyer');
      } else {
        next = const CompleteProfileScreen();
      }
    }

    const Duration minimumSplash = Duration(milliseconds: 900);
    final Duration elapsed = DateTime.now().difference(started);
    if (elapsed < minimumSplash) {
      await Future<void>.delayed(minimumSplash - elapsed);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  /// Firebase restores the saved session from disk/indexedDB. `currentUser`
  /// is usually filled already; the auth stream covers slower restores.
  Future<User?> _restoredUser() async {
    var user = AuthService.instance.currentUser;
    if (user != null) return user;
    try {
      user = await FirebaseAuth.instance.authStateChanges().first
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    return user ?? AuthService.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forest,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.35,
            colors: [
              Color(0xFF2C5140),
              AppColors.forest,
              Color(0xFF14261C),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: _glow(240, Colors.white.withValues(alpha: 0.05)),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: _glow(260, AppColors.mustard.withValues(alpha: 0.10)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(
                    size: 124,
                    light: true,
                    showTagline: true,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _purpose('SWIPE'),
                      _dot(),
                      _purpose('OFFER'),
                      _dot(),
                      _purpose('REHOME'),
                    ],
                  ),
                  const SizedBox(height: 38),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _purpose(String label) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: Colors.white.withValues(alpha: 0.72),
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.mustard,
        ),
      ),
    );
  }
}
