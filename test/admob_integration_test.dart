import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timora/core/config/admob_config.dart';
import 'package:timora/core/services/ad_service.dart';
import 'package:timora/core/widgets/timora_banner_ad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdMobConfig Tests', () {
    test('Config contains exact real AdMob IDs supplied by user', () {
      expect(AdMobConfig.realAppId, 'ca-app-pub-4444144770013098~2921653672');
      expect(AdMobConfig.realBannerAdUnitId, 'ca-app-pub-4444144770013098/1596612068');
      expect(AdMobConfig.testBannerAdUnitId, 'ca-app-pub-3940256099942544/6300978111');
    });

    test('Switching between test and production mode correctly updates bannerAdUnitId', () {
      AdMobConfig.setTestMode(true);
      expect(AdMobConfig.useTestAds, isTrue);
      expect(AdMobConfig.bannerAdUnitId, AdMobConfig.testBannerAdUnitId);

      AdMobConfig.setTestMode(false);
      expect(AdMobConfig.useTestAds, isFalse);
      expect(AdMobConfig.bannerAdUnitId, AdMobConfig.realBannerAdUnitId);

      // Reset to test mode for safe testing
      AdMobConfig.setTestMode(true);
    });
  });

  group('AdService Tests', () {
    test('AdService.initialize executes safely without throwing on any platform', () async {
      // In flutter test (host OS), AdService should handle the non-mobile platform gracefully
      expect(AdService.initialize(), completes);
    });
  });

  group('TimoraBannerAd Widget Tests', () {
    testWidgets('TimoraBannerAd safely renders and collapses when not loaded or on unsupported platform', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TimoraBannerAd(),
            ),
          ),
        ),
      );

      // Expect that TimoraBannerAd renders without throwing
      expect(find.byType(TimoraBannerAd), findsOneWidget);
      // When uninitialized or on desktop/test environment, it safely collapses to SizedBox.shrink()
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
