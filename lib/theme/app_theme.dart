import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ThriftMate design system colors — from the project's brand brief.
/// Mapped so existing screens (home_screen etc.) keep working:
///   primary      -> Burnt Sienna  (main CTA / brand action color)
///   primaryDark  -> darker Burnt Sienna (gradients)
///   secondary    -> Dusty Rose    (soft accents, selected chips)
///   accent       -> Arctic Blue   (tags/badges contrast)
///   darkAccent   -> Crimson Ink   (highlights, sold tags, heart logo)
///   background   -> Cosmic Latte  (warm cream screen background)
///   surface      -> White         (cards)
class AppColors {
  static const Color primary = Color(0xFFE86F1A); // Burnt Sienna
  static const Color primaryDark = Color(0xFFC25A12);
  static const Color secondary = Color(0xFFE7A6AB); // Dusty Rose
  static const Color accent = Color(0xFFA9C9E3); // Arctic Blue
  static const Color darkAccent = Color(0xFF94152F); // Crimson Ink
  static const Color background = Color(0xFFF4F0D0); // Cosmic Latte
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF292323); // Dark Charcoal
  static const Color textMuted = Color(0xFF8C8578);
  static const Color error = Color(0xFFD9534F);
  static const Color border = Color(0xFFE8E2CF);
  static const Color fill = Color(0xFFFBF9EE);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.textMuted,
          height: 1.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted),
        labelStyle: GoogleFonts.dmSans(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkAccent,
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
