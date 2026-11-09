import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ThriftMate design system — warm "vintage editorial" look.
///
/// The older names (primary, darkAccent, textDark ...) are kept as aliases so
/// every existing screen picks up the new palette without being rewritten.
class AppColors {
  // Core palette
  static const Color canvas = Color(0xFFFAF6EF); // warm cream background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1C1B18); // near-black text
  static const Color forest = Color(0xFF1F3D2E); // primary action
  static const Color forestDeep = Color(0xFF14281E); // pressed / gradients
  static const Color clay = Color(0xFFB85C3A); // accents, tags, prices
  static const Color mustard = Color(0xFFE3A857); // price sticker
  static const Color sage = Color(0xFF879A7E); // soft chips
  static const Color line = Color(0xFFE7DFD3); // hairlines
  static const Color sand = Color(0xFFF1E9DC); // fill / placeholders
  static const Color muted = Color(0xFF8C867B); // secondary text
  static const Color success = Color(0xFF2F6B4F);
  static const Color error = Color(0xFFB3261E);

  // Legacy aliases used across the project
  static const Color primary = forest;
  static const Color primaryDark = forestDeep;
  static const Color secondary = sage;
  static const Color accent = mustard;
  static const Color darkAccent = clay;
  static const Color background = canvas;
  static const Color textDark = ink;
  static const Color textMuted = muted;
  static const Color border = line;
  static const Color fill = sand;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      primary: AppColors.forest,
      onPrimary: Colors.white,
      secondary: AppColors.clay,
      onSecondary: Colors.white,
      tertiary: AppColors.mustard,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
    );

    final text = base.textTheme;
    TextStyle serif(
      double size, {
      FontWeight weight = FontWeight.w600,
      double height = 1.15,
      Color color = AppColors.ink,
      double letterSpacing = -0.4,
    }) =>
        GoogleFonts.fraunces(
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color,
          letterSpacing: letterSpacing,
        );
    TextStyle sans(
      double size, {
      FontWeight weight = FontWeight.w400,
      double height = 1.5,
      Color color = AppColors.ink,
      double letterSpacing = 0,
    }) =>
        GoogleFonts.dmSans(
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color,
          letterSpacing: letterSpacing,
        );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: text.copyWith(
        displayLarge: serif(44, height: 1.05),
        displayMedium: serif(38, height: 1.08),
        headlineLarge: serif(32),
        headlineMedium: serif(27),
        headlineSmall: serif(22),
        titleLarge: serif(20),
        titleMedium: serif(17, letterSpacing: -0.2),
        titleSmall: sans(13.5, weight: FontWeight.w600, letterSpacing: 0.3),
        bodyLarge: sans(15.5, height: 1.6),
        bodyMedium: sans(14, color: AppColors.muted),
        bodySmall: sans(12.5, color: AppColors.muted),
        labelLarge: sans(15, weight: FontWeight.w600, height: 1.2),
        labelMedium: sans(12, weight: FontWeight.w600, letterSpacing: 0.6),
        labelSmall: sans(11, weight: FontWeight.w500, letterSpacing: 0.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: serif(21),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.sage.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: sans(15.5, weight: FontWeight.w600, height: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: sans(15.5, weight: FontWeight.w600, height: 1.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.forest, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: sans(15.5, weight: FontWeight.w600, height: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.clay,
          textStyle: sans(14, weight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        hintStyle: sans(14, color: AppColors.muted),
        labelStyle: sans(14, color: AppColors.muted),
        floatingLabelStyle: sans(13.5, color: AppColors.forest),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.forest,
        disabledColor: AppColors.sand,
        labelStyle: sans(13, weight: FontWeight.w500),
        secondaryLabelStyle:
            sans(13, weight: FontWeight.w600, color: Colors.white),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: sans(13.5, color: AppColors.canvas),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titleTextStyle: serif(20),
        contentTextStyle: sans(14, color: AppColors.muted),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.forest,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.forest,
        dividerColor: AppColors.line,
        labelStyle: sans(13.5, weight: FontWeight.w600),
        unselectedLabelStyle: sans(13.5, weight: FontWeight.w500),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.forest,
      ),
    );
  }
}
