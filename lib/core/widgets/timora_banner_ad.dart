import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/admob_config.dart';
import '../services/ad_service.dart';

/// A reusable, safe Banner Ad widget for Timora.
///
/// Handles all states of the AdMob lifecycle:
/// - Loading: completely hidden (`SizedBox.shrink()`) to prevent jarring layout shifts.
/// - Loaded: renders within a themed, responsive container with subtle ad labeling.
/// - Failed: cleanly disposes the ad and collapses to zero size (`SizedBox.shrink()`).
/// - Disposed: releases native resources without memory leaks.
/// - Unsupported platform (Web, Desktop): collapses to zero size safely.
class TimoraBannerAd extends StatefulWidget {
  /// The AdMob size to request. Defaults to [AdSize.banner] (320x50).
  final AdSize adSize;

  /// Outer padding/margin around the ad container.
  final EdgeInsetsGeometry margin;

  /// Whether to display a discreet "Ad" tag above or beside the banner for Google policy compliance.
  final bool showAdBadge;

  const TimoraBannerAd({
    super.key,
    this.adSize = AdSize.banner,
    this.margin = const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
    this.showAdBadge = true,
  });

  @override
  State<TimoraBannerAd> createState() => _TimoraBannerAdState();
}

class _TimoraBannerAdState extends State<TimoraBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initAndLoadAd();
  }

  Future<void> _initAndLoadAd() async {
    if (!AdService.isPlatformSupported) return;

    // Ensure SDK initialization has been triggered
    if (!AdService.isInitialized) {
      await AdService.initialize();
    }

    if (!mounted || _isDisposed) return;

    try {
      _bannerAd = BannerAd(
        adUnitId: AdMobConfig.bannerAdUnitId,
        size: widget.adSize,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (_isDisposed || !mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _isLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint(
                '[TimoraBannerAd] Failed to load: ${error.message} (code: ${error.code})');
            ad.dispose();
            _bannerAd = null;
            if (mounted && !_isDisposed) {
              setState(() {
                _isLoaded = false;
              });
            }
          },
          onAdOpened: (ad) => debugPrint('[TimoraBannerAd] Ad opened.'),
          onAdClosed: (ad) => debugPrint('[TimoraBannerAd] Ad closed.'),
          onAdImpression: (ad) =>
              debugPrint('[TimoraBannerAd] Ad impression recorded.'),
        ),
      );

      await _bannerAd?.load();
    } catch (e) {
      debugPrint('[TimoraBannerAd] Unexpected error loading banner ad: $e');
      _bannerAd?.dispose();
      _bannerAd = null;
      if (mounted) {
        setState(() {
          _isLoaded = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If not supported, not loaded, or ad object is null, render nothing
    if (!AdService.isPlatformSupported || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bannerWidth = _bannerAd!.size.width.toDouble();
    final bannerHeight = _bannerAd!.size.height.toDouble();

    return Container(
      margin: widget.margin,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showAdBadge)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ADVERTISEMENT',
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: bannerWidth,
                height: bannerHeight,
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
