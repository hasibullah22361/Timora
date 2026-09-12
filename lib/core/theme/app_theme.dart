import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = AppTokens.primaryBlue;
  static const Color secondaryColor = AppTokens.cyanTeal;
  static const Color backgroundColorLight = AppTokens.bgLight;
  static const Color backgroundColorDark = AppTokens.bgDark;
  static const Color surfaceColorLight = AppTokens.surfaceLight;
  static const Color surfaceColorDark = AppTokens.surfaceDark;

  static ThemeData? _cachedLightTheme;
  static ThemeData get lightTheme => _cachedLightTheme ??= _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppTokens.primaryBlue,
        primaryContainer: AppTokens.primaryContainerLight,
        onPrimary: Colors.white,
        onPrimaryContainer: AppTokens.primaryBlueDark,
        secondary: AppTokens.cyanTeal,
        secondaryContainer: AppTokens.cyanTealLight,
        onSecondary: Colors.white,
        surface: AppTokens.surfaceLight,
        onSurface: AppTokens.textPrimaryLight,
        surfaceContainerHighest: Color(0xFFF1F5F9),
        outline: AppTokens.borderLight,
        outlineVariant: Color(0xFFCBD5E1),
        error: AppTokens.coralRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppTokens.bgLight,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: AppTokens.textPrimaryLight,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: AppTokens.textPrimaryLight,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: AppTokens.textPrimaryLight,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: AppTokens.textPrimaryLight,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppTokens.textPrimaryLight,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppTokens.textPrimaryLight,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          color: AppTokens.textSecondaryLight,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppTokens.textPrimaryLight,
          fontSize: 16,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppTokens.textSecondaryLight,
          fontSize: 14,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: AppTokens.textMutedLight,
          fontSize: 12,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.textPrimaryLight,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppTokens.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTokens.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppTokens.borderLight, width: 1.5),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.coralRed),
        ),
        hintStyle: const TextStyle(color: AppTokens.textMutedLight, fontSize: 14),
        labelStyle: const TextStyle(color: AppTokens.textSecondaryLight, fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: AppTokens.primaryBlue.withValues(alpha: 0.15),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTokens.textPrimaryLight),
        secondaryLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTokens.primaryBlue),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.borderLight,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.surfaceLight,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppTokens.surfaceLight,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: const Color(0xFFEFF6FF),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTokens.primaryBlue);
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTokens.textSecondaryLight);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppTokens.primaryBlue, size: 22);
          }
          return const IconThemeData(color: AppTokens.textSecondaryLight, size: 22);
        }),
      ),
    );
  }

  static ThemeData? _cachedDarkTheme;
  static ThemeData get darkTheme => _cachedDarkTheme ??= _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppTokens.primaryBlueLight,
        primaryContainer: AppTokens.primaryContainerDark,
        onPrimary: Colors.white,
        onPrimaryContainer: Colors.white,
        secondary: AppTokens.cyanTeal,
        secondaryContainer: Color(0xFF164E63),
        onSecondary: Colors.white,
        surface: AppTokens.surfaceDark,
        onSurface: AppTokens.textPrimaryDark,
        surfaceContainerHighest: AppTokens.cardDark,
        outline: AppTokens.borderDark,
        outlineVariant: Color(0xFF334155),
        error: AppTokens.coralRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppTokens.bgDark,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: AppTokens.textPrimaryDark,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: AppTokens.textPrimaryDark,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: AppTokens.textPrimaryDark,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: AppTokens.textPrimaryDark,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppTokens.textPrimaryDark,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppTokens.textPrimaryDark,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          color: AppTokens.textSecondaryDark,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppTokens.textPrimaryDark,
          fontSize: 16,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppTokens.textSecondaryDark,
          fontSize: 14,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: AppTokens.textMutedDark,
          fontSize: 12,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppTokens.textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTokens.borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.primaryBlueLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.primaryBlueLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.primaryBlueLight,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppTokens.borderDark, width: 1.5),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.primaryBlueLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTokens.coralRed),
        ),
        hintStyle: const TextStyle(color: AppTokens.textMutedDark, fontSize: 14),
        labelStyle: const TextStyle(color: AppTokens.textSecondaryDark, fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppTokens.cardDark,
        selectedColor: AppTokens.primaryBlueLight.withValues(alpha: 0.25),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTokens.textPrimaryDark),
        secondaryLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTokens.primaryBlueLight),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTokens.borderDark),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.borderDark,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.surfaceDark,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppTokens.surfaceDark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTokens.bgDark,
        elevation: 0,
        indicatorColor: const Color(0xFF14244B),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF38BDF8));
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF38BDF8), size: 22);
          }
          return const IconThemeData(color: Color(0xFF64748B), size: 22);
        }),
      ),
    );
  }
}

