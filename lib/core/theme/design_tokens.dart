import 'package:flutter/material.dart';

/// Centralized design tokens for Timora's modern, clean, mobile-first design system.
class AppTokens {
  AppTokens._();

  // Spacing & Padding
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  // Border Radii
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 14.0;
  static const double radiusLarge = 18.0;
  static const double radiusXLarge = 24.0;
  static const double radiusRound = 999.0;

  static BorderRadius get borderSmall => BorderRadius.circular(radiusSmall);
  static BorderRadius get borderMedium => BorderRadius.circular(radiusMedium);
  static BorderRadius get borderLarge => BorderRadius.circular(radiusLarge);
  static BorderRadius get borderXLarge => BorderRadius.circular(radiusXLarge);
  static BorderRadius get borderRound => BorderRadius.circular(radiusRound);

  // Curated Primary Brand Palette
  static const Color primaryBlue = Color(0xFF2563EB); // Vibrant Royal Blue
  static const Color primaryBlueLight = Color(0xFF3B82F6);
  static const Color primaryBlueDark = Color(0xFF1D4ED8);
  static const Color primaryContainerLight = Color(0xFFEFF6FF);
  static const Color primaryContainerDark = Color(0xFF1E293B);

  // Accent & Functional Palette
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color emeraldGreenLight = Color(0xFFD1FAE5);
  static const Color amberOrange = Color(0xFFF59E0B);
  static const Color amberOrangeLight = Color(0xFFFEF3C7);
  static const Color coralRed = Color(0xFFEF4444);
  static const Color coralRedLight = Color(0xFFFEE2E2);
  static const Color purpleViolet = Color(0xFF8B5CF6);
  static const Color purpleVioletLight = Color(0xFFEDE9FE);
  static const Color cyanTeal = Color(0xFF06B6D4);
  static const Color cyanTealLight = Color(0xFFCFFAFE);

  // Neutral Scales (Light)
  static const Color bgLight = Color(0xFFF8FAFC); // Slate-50
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure White
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0); // Slate-200
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate-900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate-500
  static const Color textMutedLight = Color(0xFF94A3B8); // Slate-400

  // Neutral Scales (Dark)
  static const Color bgDark = Color(0xFF070B14); // Ultra-deep dark navy matching screenshot
  static const Color surfaceDark = Color(0xFF0C1322); // Deep Surface
  static const Color cardDark = Color(0xFF0E1626); // Card Surface
  static const Color borderDark = Color(0xFF1B273F); // Border Highlight
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate-50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate-400
  static const Color textMutedDark = Color(0xFF64748B); // Slate-500

  // Soft Elevation Shadows
  static List<BoxShadow> get cardShadowLight => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get cardShadowDark => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // AI Gradient
  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Primary Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Hero Card Icon Gradient
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Streak Gradients
  static const LinearGradient streakGradientDark = LinearGradient(
    colors: [Color(0xFF221142), Color(0xFF140D2C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient streakGradientLight = LinearGradient(
    colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color streakBorderDark = Color(0xFF3B1D73);
  static const Color streakBorderLight = Color(0xFFE9D5FF);
}

/// Alias for AppTokens providing convenient color references across presentation screens.
typedef AppColors = AppTokens;

