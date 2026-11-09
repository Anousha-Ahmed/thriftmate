import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// ThriftMate brand mark: a pre-loved t-shirt with a heart badge, paired with
/// the Fraunces wordmark. Uses the same artwork as the launcher icon.
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
  final bool light; // true = cream mark for use on dark backgrounds

  @override
  Widget build(BuildContext context) {
    final Color wordmarkColor = light ? Colors.white : AppColors.textDark;

    return Column(
      children: [
        Image.asset(
          light ? 'assets/icons/mark_light.png' : 'assets/icons/mark_dark.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
        if (showWordmark) ...[
          const SizedBox(height: 14),
          Text(
            'ThriftMate',
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: wordmarkColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Buy & sell pre-loved clothing',
            style: GoogleFonts.dmSans(
              fontSize: 13,
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
