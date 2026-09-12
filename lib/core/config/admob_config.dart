import 'package:flutter/foundation.dart';

/// Centralized configuration for Google AdMob in Timora.
///
/// All AdMob identifiers, test configurations, and production switches are
/// managed here so they are never duplicated or hard-coded across multiple files.
class AdMobConfig {
  AdMobConfig._();

  // ================= REAL PRODUCTION ADMOB IDENTIFIERS =================
  /// Real Production AdMob Application ID provided for Timora.
  static const String realAppId = 'ca-app-pub-4444144770013098~2921653672';

  /// Real Production Banner Ad Unit ID provided for Timora.
  static const String realBannerAdUnitId =
      'ca-app-pub-4444144770013098/1596612068';

  // ================= GOOGLE OFFICIAL TEST AD IDENTIFIERS =================
  /// Official Google Sample/Test Ad Unit ID for Android Banners.
  /// Used during development and testing to prevent invalid traffic and policy strikes.
  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  // ================= CONFIGURATION TOGGLES =================
  /// Whether to serve Google official test ads instead of live production ads.
  ///
  /// Defaults to [kDebugMode] (true in debug/testing, false in release mode).
  /// Can be explicitly toggled at runtime or in build settings.
  static bool useTestAds = kDebugMode;

  /// Returns the appropriate Banner Ad Unit ID based on the active test/production mode.
  static String get bannerAdUnitId {
    if (useTestAds) {
      return testBannerAdUnitId;
    }
    return realBannerAdUnitId;
  }

  /// Helper to quickly switch test ad mode explicitly.
  static void setTestMode(bool isTest) {
    useTestAds = isTest;
  }
}
