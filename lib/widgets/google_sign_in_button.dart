import 'package:flutter/material.dart';
import '../screens/complete_profile_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/role_router.dart';

/// "Continue with Google" button. Handles the full flow:
///   Google sign-in -> profile exists? -> Home
///                  -> no profile yet?  -> Complete Profile (pick username + role)
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, this.label = 'Continue with Google'});

  final String label;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _loading = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onPressed() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      final profile = await AuthService.instance.getProfile(user.uid);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              profile == null
              ? const CompleteProfileScreen()
              : homeForRole(profile.role),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _loading ? null : _onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: _loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.g_mobiledata_rounded,
                    size: 32, color: Color(0xFFEA4335)),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
