import 'package:flutter/material.dart';

class RapidAidColors {
  RapidAidColors._();

  static const Color primary = Color(0xFFE53935);
  static const Color primaryDark = Color(0xFFC62828);
  static const Color secondary = Color(0xFFFF8F00);
  static const Color accent = Color(0xFFFFC107);

  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFFFF4F3);

  static const Color textPrimary = Color(0xFF1B1D21);
  static const Color textSecondary = Color(0xFF62666D);
  static const Color textLight = Color(0xFF90949B);

  static const Color success = Color(0xFF2E9D59);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);

  static const Color border = Color(0xFFE2E5E9);
  static const Color divider = Color(0xFFECEEF1);
}

class AppTheme {
  AppTheme._();

  // Builds the main Material 3 theme used throughout RapidAid.
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RapidAidColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: RapidAidColors.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFDAD6),
      onPrimaryContainer: const Color(0xFF410002),
      secondary: RapidAidColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFDDB8),
      onSecondaryContainer: const Color(0xFF2A1700),
      surface: RapidAidColors.surface,
      onSurface: RapidAidColors.textPrimary,
      error: RapidAidColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RapidAidColors.background,
      fontFamily: 'Roboto',

      appBarTheme: const AppBarTheme(
        backgroundColor: RapidAidColors.background,
        foregroundColor: RapidAidColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: RapidAidColors.textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        color: RapidAidColors.surface,
        elevation: 2,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RapidAidColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: RapidAidColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: RapidAidColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: RapidAidColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: RapidAidColors.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: RapidAidColors.error,
            width: 2,
          ),
        ),
        labelStyle: const TextStyle(
          color: RapidAidColors.textSecondary,
        ),
        hintStyle: const TextStyle(
          color: RapidAidColors.textLight,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RapidAidColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RapidAidColors.primary,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(
            color: RapidAidColors.primary,
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RapidAidColors.primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: RapidAidColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: RapidAidColors.surface,
        elevation: 3,
        indicatorColor: const Color(0xFFFFDAD6),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: RapidAidColors.primary,
              );
            }

            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: RapidAidColors.textSecondary,
            );
          },
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: RapidAidColors.surfaceSoft,
        selectedColor: const Color(0xFFFFDAD6),
        side: const BorderSide(
          color: RapidAidColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: const TextStyle(
          color: RapidAidColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: RapidAidColors.divider,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RapidAidColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: RapidAidColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: RapidAidColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 15,
          height: 1.4,
          color: RapidAidColors.textSecondary,
        ),
      ),
    );
  }
}