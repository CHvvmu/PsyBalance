import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    const Color primary = Color(0xFFA8B5A0);
    const Color onPrimary = Color(0xFFFAF7F2);
    const Color secondary = Color(0xFFD4A5A5);
    const Color onSecondary = Color(0xFFFAF7F2);
    const Color surface = Color(0xFFFFFFFF);
    const Color onSurface = Color(0xFF4A443F);
    const Color error = Color(0xFFE57373);
    const Color onError = Color(0xFFFFFFFF);

    const ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      error: error,
      onError: onError,
      surface: surface,
      onSurface: onSurface,
    );

    final TextTheme textTheme = _textTheme(
      primaryText: const Color(0xFF4A443F),
      secondaryText: const Color(0xFF7D746D),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFAF7F2),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFAF7F2),
        foregroundColor: const Color(0xFF4A443F),
        centerTitle: true,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE8E2D9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE8E2D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primary),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xFFBDB6AF)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: const Color(0xFF4A443F),
          side: const BorderSide(color: Color(0xFFE8E2D9)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      dividerColor: const Color(0xFFE8E2D9),
    );
  }

  static ThemeData dark() {
    const Color primary = Color(0xFFA8B5A0);
    const Color onPrimary = Color(0xFF2D2A26);
    const Color secondary = Color(0xFFD4A5A5);
    const Color onSecondary = Color(0xFF2D2A26);
    const Color surface = Color(0xFF3D3934);
    const Color onSurface = Color(0xFFFAF7F2);
    const Color error = Color(0xFFEF9A9A);
    const Color onError = Color(0xFF2D2A26);

    const ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      error: error,
      onError: onError,
      surface: surface,
      onSurface: onSurface,
    );

    final TextTheme textTheme = _textTheme(
      primaryText: const Color(0xFFFAF7F2),
      secondaryText: const Color(0xFFBDB6AF),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF2D2A26),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF2D2A26),
        foregroundColor: const Color(0xFFFAF7F2),
        centerTitle: true,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF4A443F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF4A443F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primary),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xFF7D746D)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: const Color(0xFFFAF7F2),
          side: const BorderSide(color: Color(0xFF4A443F)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      dividerColor: const Color(0xFF4A443F),
    );
  }

  static TextTheme _textTheme({
    required Color primaryText,
    required Color secondaryText,
  }) {
    return TextTheme(
      headlineLarge: GoogleFonts.nunito(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: primaryText,
      ),
      headlineMedium: GoogleFonts.nunito(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: primaryText,
      ),
      titleLarge: GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: primaryText,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: primaryText,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: primaryText,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: secondaryText,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: secondaryText,
      ),
      labelLarge: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: primaryText,
      ),
      labelMedium: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: primaryText,
      ),
      labelSmall: GoogleFonts.nunito(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: secondaryText,
      ),
    );
  }
}

