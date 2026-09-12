import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timora/core/config/build_info.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/others/presentation/screens/others_screen.dart';
import 'package:timora/features/settings/presentation/screens/feature_audit_screen.dart';
import 'package:timora/features/recap/domain/models/recap_models.dart';
import 'package:timora/features/recap/presentation/screens/recap_screen.dart';
import 'package:timora/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:timora/features/ai_assistant/presentation/screens/ai_privacy_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Timora Master Feature Audit & Diagnostic Tests', () {
    test('1. BuildInfo contains valid version, build number, date, and 30+ verified features', () {
      expect(BuildInfo.version, '1.1.0');
      expect(BuildInfo.buildNumber, '2');
      expect(BuildInfo.featureBuildDate, '2026-09-11');
      expect(BuildInfo.fullVersionString, contains('1.1.0'));
      expect(BuildInfo.fullVersionString, contains('2026-09-11'));
      expect(BuildInfo.verifiedFeatures.length, greaterThanOrEqualTo(30));

      // Verify essential feature entries exist in metadata
      final featureNames = BuildInfo.verifiedFeatures.map((f) => f['name']).toList();
      expect(featureNames, contains('AI Daily Recap'));
      expect(featureNames, contains('AI Weekly & Monthly Recap'));
      expect(featureNames, contains('Recap History Archive'));
      expect(featureNames, contains('Clock Hub (Alarm, World, Stopwatch, Timer)'));
      expect(featureNames, contains('Smart Unified Planner'));
      expect(featureNames, contains('AI Morning Brief'));
      expect(featureNames, contains('AI Daily Debrief'));
      expect(featureNames, contains('Focus & Pomodoro Timer'));
      expect(featureNames, contains('Reviews & Reflection Wizard'));
      expect(featureNames, contains('AI Privacy & Context Permissions'));
      expect(featureNames, contains('Ambient Nature Soundscapes'));
      expect(featureNames, contains('Timora Diary & Journal'));
    });

    test('2. NotificationSettingsRepository persists custom Recap scheduling', () async {
      final repo = NotificationSettingsRepository(prefs);

      // Verify defaults
      expect(repo.dailyRecapEnabled, isTrue);
      expect(repo.weeklyRecapEnabled, isTrue);
      expect(repo.weeklyRecapWeekday, DateTime.sunday);
      expect(repo.monthlyRecapEnabled, isTrue);

      // Custom daily recap time
      await repo.setDailyRecapTime(const TimeOfDay(hour: 22, minute: 15));
      expect(repo.dailyRecapTime.hour, 22);
      expect(repo.dailyRecapTime.minute, 15);

      // Custom weekly recap schedule
      await repo.setWeeklyRecapWeekday(DateTime.saturday);
      await repo.setWeeklyRecapTime(const TimeOfDay(hour: 20, minute: 30));
      expect(repo.weeklyRecapWeekday, DateTime.saturday);
      expect(repo.weeklyRecapTime.hour, 20);
      expect(repo.weeklyRecapTime.minute, 30);

      // Custom monthly recap schedule
      await repo.setMonthlyRecapTime(const TimeOfDay(hour: 21, minute: 45));
      expect(repo.monthlyRecapTime.hour, 21);
      expect(repo.monthlyRecapTime.minute, 45);

      // Toggles
      await repo.setWeeklyRecapEnabled(false);
      expect(repo.weeklyRecapEnabled, isFalse);
    });

    testWidgets('3. OthersScreen renders with search, categories, and view mode toggle', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: OthersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and controls
      expect(find.text('All Timora Features'), findsOneWidget);
      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Check category chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Planning & Goals'), findsOneWidget);
      expect(find.text('Reviews & Insights'), findsOneWidget);
      expect(find.text('Personal & Career'), findsOneWidget);

      // Check major feature cards exist
      expect(find.text('Recaps'), findsOneWidget);
      expect(find.text('Clock (Alarm, Timer, Stopwatch)'), findsOneWidget);

      // Toggle to List mode
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      expect(prefs.getString('timora_features_view_mode'), 'list');
    });

    testWidgets('4. FeatureAuditScreen displays version identity card and verified features', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: FeatureAuditScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Feature Audit & Diagnostics'), findsOneWidget);
      expect(find.textContaining('Build 2'), findsOneWidget);
      expect(find.textContaining('1.1.0'), findsWidgets);
      expect(find.textContaining('2026-09-11'), findsOneWidget);
      expect(find.text('Open / Test Feature'), findsWidgets);
    });

    testWidgets('5. Crucial screens instantiate without crashing', (tester) async {
      // RecapScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: RecapScreen(recapType: RecapType.daily),
          ),
        ),
      );
      expect(find.byType(RecapScreen), findsOneWidget);

      // ReviewsScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: ReviewsScreen(),
          ),
        ),
      );
      expect(find.byType(ReviewsScreen), findsOneWidget);

      // AIPrivacySettingsScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: AIPrivacySettingsScreen(),
          ),
        ),
      );
      expect(find.byType(AIPrivacySettingsScreen), findsOneWidget);
    });
  });
}
