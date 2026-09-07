import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/home/presentation/providers/home_provider.dart';
import 'package:timora/features/home/presentation/widgets/current_activity_card.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/routine/data/models/routine_block.dart';
import 'package:timora/features/routine/presentation/providers/routine_provider.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Current Activity on Home Page Tests', () {
    test('currentActivityProvider identifies active activity based on current time', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final baseDate = DateTime(2026, 9, 6);
      final startTime = DateTime(2026, 9, 6, 9, 0);
      final endTime = DateTime(2026, 9, 6, 12, 0);

      final studyActivity = ScheduleActivity(
        id: 'act_study_1',
        title: 'Study',
        description: 'Exam preparation',
        date: baseDate,
        startTime: startTime,
        endTime: endTime,
        category: 'Study',
        createdAt: baseDate,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Set current time to 10:30 AM (within 9:00 AM - 12:00 PM)
          currentTimeProvider.overrideWith((ref) => CurrentTimeNotifier(startTimer: false)..state = DateTime(2026, 9, 6, 10, 30)),
        ],
      );

      final scheduleRepo = container.read(scheduleRepositoryProvider);
      await scheduleRepo.addActivity(studyActivity);

      // Invalidate and fetch
      container.invalidate(dailyScheduleProvider);
      await container.read(dailyScheduleProvider.future);
      final activeAsync = container.read(currentActivityProvider);
      final active = activeAsync.valueOrNull;

      expect(active, isNotNull);
      expect(active!.title, 'Study');
      expect(active.startTime, startTime);
      expect(active.endTime, endTime);

      // Now advance time to 12:30 PM (past the end of the activity)
      container.read(currentTimeProvider.notifier).state = DateTime(2026, 9, 6, 12, 30);
      final activeAfterAsync = container.read(currentActivityProvider);
      final activeAfter = activeAfterAsync.valueOrNull;

      expect(activeAfter, isNull, reason: 'Old activities must not be incorrectly shown as active');
    });

    test('Routine scheduler generates schedule activities for all active routines for today', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentTimeProvider.overrideWith((ref) => CurrentTimeNotifier(startTimer: false)..state = DateTime(2026, 9, 6, 10, 0)),
        ],
      );

      final routineNotifier = container.read(routineNotifierProvider);

      // Routine 1: Morning routine (7:00 AM - 8:00 AM)
      final r1 = Routine(
        id: 'r_morning',
        name: 'Morning Routine',
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        startDate: DateTime(2026, 9, 1),
        createdAt: DateTime(2026, 9, 1),
      );
      final b1 = RoutineBlock(
        id: 'b_morning_1',
        routineId: 'r_morning',
        title: 'Morning Meditation',
        category: 'Health',
        icon: '🧘',
        order: 0,
        startTime: const TimeOfDay(hour: 7, minute: 0),
        endTime: const TimeOfDay(hour: 8, minute: 0),
      );
      await routineNotifier.addRoutine(r1, [b1]);

      // Routine 2: Study routine (9:00 AM - 12:00 PM) - second routine!
      final r2 = Routine(
        id: 'r_study',
        name: 'Study Routine',
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        startDate: DateTime(2026, 9, 1),
        createdAt: DateTime(2026, 9, 1),
      );
      final b2 = RoutineBlock(
        id: 'b_study_1',
        routineId: 'r_study',
        title: 'Study',
        category: 'Study',
        icon: '📚',
        order: 0,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 12, minute: 0),
      );
      await routineNotifier.addRoutine(r2, [b2]);

      // Trigger daily schedule generation and fetch
      final todaySchedule = await container.read(dailyScheduleProvider.future);
      expect(todaySchedule.length, 2, reason: 'Both routine activities must be generated for today');

      // Check that at 10:00 AM, the current activity is 'Study'
      final currentActivity = container.read(currentActivityProvider).valueOrNull;
      expect(currentActivity, isNotNull);
      expect(currentActivity!.title, 'Study');
    });

    testWidgets('CurrentActivityCard displays CURRENT ACTIVITY, Study, 9:00 AM – 12:00 PM, and In Progress', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final baseDate = DateTime(2026, 9, 6);
      final startTime = DateTime(2026, 9, 6, 9, 0);
      final endTime = DateTime(2026, 9, 6, 12, 0);

      final studyActivity = ScheduleActivity(
        id: 'act_study_widget',
        title: 'Study',
        description: 'Focus on coursework',
        date: baseDate,
        startTime: startTime,
        endTime: endTime,
        category: 'Study',
        createdAt: baseDate,
      );

      final scheduleRepo = ScheduleRepository(prefs);
      await scheduleRepo.addActivity(studyActivity);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            scheduleRepositoryProvider.overrideWithValue(scheduleRepo),
            currentTimeProvider.overrideWith((ref) => CurrentTimeNotifier(startTimer: false)..state = DateTime(2026, 9, 6, 10, 30)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CurrentActivityCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the required elements appear:
      expect(find.text('Current Activity'), findsWidgets);
      expect(find.text('CURRENT ACTIVITY'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);
      expect(find.text('9:00 AM – 12:00 PM'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
    });

    testWidgets('CurrentActivityCard displays Ready for Focus empty state when no activity is active', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentTimeProvider.overrideWith((ref) => CurrentTimeNotifier(startTimer: false)..state = DateTime(2026, 9, 6, 14, 0)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CurrentActivityCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('WHAT SHOULD I DO NOW'), findsOneWidget);
      expect(find.text('Start Focus'), findsOneWidget);
    });
  });
}
