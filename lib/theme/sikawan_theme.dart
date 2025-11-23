import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SiKawanTheme {
  // Colors
  static const primary = Color(0xFF2563EB);
  static const primarySoft = Color(0xFFDBEAFE);
  static const secondary = Color(0xFF10B981);
  static const accent = Color(0xFFF59E0B);
  static const bg = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const error = Color(0xFFDC2626);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primary,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
    ),

    // ✅ Manrope sebagai default text theme
    textTheme: GoogleFonts.manropeTextTheme().copyWith(
      headlineLarge: GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: textPrimary),
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: error),
      ),
      hintStyle: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelStyle: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
