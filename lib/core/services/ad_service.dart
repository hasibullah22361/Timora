import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Central service responsible for safe initialization and lifecycle of Google Mobile Ads.
class AdService {
  AdService._();

  static bool _isInitialized = false;

  /// Returns whether the Mobile Ads SDK has been successfully initialized.
  static bool get isInitialized => _isInitialized;

  /// Whether the current platform supports Google Mobile Ads.
  static bool get isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Initializes the Google Mobile Ads SDK safely in the background.
  ///
  /// This method is non-blocking and safe to call during app startup.
  /// Any errors or platform incompatibilities are caught and will never crash the app.
  static Future<void> initialize() async {
    if (!isPlatformSupported) {
      debugPrint(
          '[AdService] Platform does not support Google Mobile Ads. Skipping initialization.');
      return;
    }

    if (_isInitialized) return;

    try {
      debugPrint('[AdService] Initializing Google Mobile Ads SDK...');
      final initStatus = await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] Google Mobile Ads SDK initialized successfully.');

      // Log adapter statuses in debug mode
      if (kDebugMode) {
        initStatus.adapterStatuses.forEach((key, status) {
          debugPrint(
              '[AdService] Adapter $key: ${status.state} (${status.description})');
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[AdService] Failed to initialize Google Mobile Ads SDK: $e');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}
