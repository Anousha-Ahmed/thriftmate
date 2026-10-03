import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// ThriftMate brand mark: a clothing hanger with a small heart badge,
/// representing "fashion" (hanger) + "pre-loved, friendly" (heart).
/// Reused on Splash, Login and Signup so the identity stays consistent.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.showWordmark = true,
    this.showTagline = false,
    this.light = false,
  });

  final double size;
  final bool showWordmark;
  final bool showTagline;
  final bool light; // true = white version for use on colored backgrounds

  @override
  Widget build(BuildContext context) {
    final Color ring = light ? Colors.white : AppColors.primary;
    final Color hangerColor = light ? Colors.white : AppColors.primary;
    final Color wordmarkColor = light ? Colors.white : AppColors.textDark;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ring.withValues(alpha: light ? 0.18 : 0.1),
                border: Border.all(
                    color: ring.withValues(alpha: 0.35), width: 1.2),
              ),
              child: Icon(
                Icons.checkroom_rounded,
                color: hangerColor,
                size: size * 0.5,
              ),
            ),
            Positioned(
              right: -4,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.darkAccent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: light ? Colors.white : AppColors.background,
                    width: 2,
                  ),
                ),
                child: Icon(Icons.favorite_rounded,
                    color: Colors.white, size: size * 0.16),
              ),
            ),
          ],
        ),
        if (showWordmark) ...[
          const SizedBox(height: 14),
          Text(
            'ThriftMate',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: wordmarkColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Pre-loved. Perfectly you.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: light
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
