import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/others/presentation/screens/others_screen.dart';
import 'package:timora/features/recap/presentation/screens/recaps_hub_screen.dart';
import 'package:timora/features/home/presentation/widgets/focus_dashboard_widget.dart';
import 'package:timora/features/tasks/presentation/screens/tasks_screen.dart';
import 'package:timora/features/settings/presentation/screens/settings_screen.dart';
import 'package:timora/features/planner/presentation/screens/planner_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Timora Master Feature Navigation Reorganization Tests', () {
    testWidgets('1. OthersScreen contains only legitimate features and no duplicates', (tester) async {
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

      // Verified legitimate features that MUST be in Other
      expect(find.text('Recaps'), findsOneWidget);
      expect(find.text('Smart Planner'), findsOneWidget);
      expect(find.text('Clock (Alarm, Timer, Stopwatch)'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Goals & Targets'), findsOneWidget);
      expect(find.text('Productivity Analysis'), findsOneWidget);
      expect(find.text('Timora Diary & Reflection'), findsOneWidget);
      expect(find.text('Career Roadmap'), findsOneWidget);
      expect(find.text('Career Document Vault'), findsOneWidget);

      // Verified features that MUST NOT be top-level in Other
      expect(find.text('Timora AI Assistant'), findsNothing);
      expect(find.text('AI Morning Brief'), findsNothing);
      expect(find.text('AI Daily Debrief'), findsNothing);
      expect(find.text('AI Privacy & Context Settings'), findsNothing);
      expect(find.text('Quick Voice Note & NLP Capture'), findsNothing);
      expect(find.text('Focus & Pomodoro Timer'), findsNothing);
      expect(find.text('Focus History & Stats'), findsNothing);
      expect(find.text('Daily Plan Agenda'), findsNothing);
      expect(find.text('Weekly Plan Overview'), findsNothing);
      expect(find.text('Monthly Calendar Plan'), findsNothing);
      expect(find.text('Routine Templates Library'), findsNothing);
      expect(find.text('Comprehensive Reports'), findsNothing);
      expect(find.text('Reviews & Reflection Wizard'), findsNothing);
      expect(find.text('Habits & Atomic Consistency'), findsNothing);
      expect(find.text('Streaks & Consistency Heatmap'), findsNothing);
      expect(find.text('Ambient Environment Sounds'), findsNothing);
      expect(find.text('Notifications Center'), findsNothing);
      expect(find.text('Spoken Announcements & Notifications'), findsNothing);
      expect(find.text('Cloud Backup & Sync'), findsNothing);
      expect(find.text('Data Privacy, Export & Import'), findsNothing);
      expect(find.text('Feature Audit & Diagnostics'), findsNothing);
    });

    testWidgets('2. RecapsHubScreen organizes Daily, Weekly, Monthly recaps and History Archive', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: RecapsHubScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Performance Recaps'), findsOneWidget);
      expect(find.text('AI Daily Recap'), findsOneWidget);
      expect(find.text('AI Weekly Recap'), findsOneWidget);
      expect(find.text('AI Monthly Recap'), findsOneWidget);
      expect(find.text('Recap History & Archive'), findsOneWidget);
    });

    testWidgets('3. FocusDashboardWidget exposes Focus State and Focus History on Home', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FocusDashboardWidget(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Focus State'), findsOneWidget);
      expect(find.text('Focus History'), findsOneWidget);
      expect(find.text('Pomodoro'), findsOneWidget);
      expect(find.text('Focus Music'), findsOneWidget);
    });

    testWidgets('4. TasksScreen contains Review & Reflection button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: TasksScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Review & Reflection'), findsOneWidget);
      expect(find.byTooltip('Review & Reflection'), findsOneWidget);
    });

    testWidgets('5. SettingsScreen exposes all 6 target Main Settings entries', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications & Spoken Announcements'), findsOneWidget);
      expect(find.text('Cloud Backup & Sync'), findsOneWidget);
      expect(find.text('Data Privacy'), findsOneWidget);
      expect(find.text('Export & Import'), findsOneWidget);
      expect(find.text('AI Privacy & Context'), findsOneWidget);
      expect(find.text('Features Audit & Diagnostics'), findsOneWidget);
    });

    testWidgets('6. Smart Planner contains Daily & Agenda, Weekly Overview, and Monthly Calendar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: PlannerScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Smart Planner'), findsOneWidget);
      expect(find.text('Daily & Agenda'), findsOneWidget);
      expect(find.text('Weekly Overview'), findsOneWidget);
      expect(find.text('Monthly Calendar'), findsOneWidget);
    });
  });
}
