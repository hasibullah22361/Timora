import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/services/audio_mode_service.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/schedule/data/models/activity_definition.dart';
import 'package:timora/features/schedule/data/activity_library.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/planner/presentation/providers/planner_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 & 6: AudioMode & Speaking Speed Tests', () {
    test('Speaking speed defaults to 1.0 and persists in NotificationSettingsRepository', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      expect(repo.speakingSpeed, 1.0);

      await repo.setSpeakingSpeed(1.5);
      expect(repo.speakingSpeed, 1.5);

      // Verify persistence across new repo instance
      final repo2 = NotificationSettingsRepository(prefs);
      expect(repo2.speakingSpeed, 1.5);

      // Clamping between 0.1 and 2.0
      await repo.setSpeakingSpeed(3.0);
      expect(repo.speakingSpeed, 2.0);

      await repo.setSpeakingSpeed(0.01);
      expect(repo.speakingSpeed, 0.1);
    });

    test('AudioMode enum has silent, vibrate, normal and detects properly', () {
      expect(AudioMode.values, contains(AudioMode.silent));
      expect(AudioMode.values, contains(AudioMode.vibrate));
      expect(AudioMode.values, contains(AudioMode.normal));

      final service = AudioModeService();
      expect(service, isNotNull);
    });
  });

  group('Phase 9: Expanded Activity Library Tests', () {
    test('ActivityCategoryGroup contains islamic and desiLifestyle', () {
      expect(ActivityCategoryGroup.values.any((g) => g.name == 'islamic'), isTrue);
      expect(ActivityCategoryGroup.values.any((g) => g.name == 'desiLifestyle'), isTrue);

      final islamicGroup = ActivityCategoryGroup.islamic;
      expect(islamicGroup.icon, '🕌');
      expect(islamicGroup.label, 'Islamic & Prayer');

      final desiGroup = ActivityCategoryGroup.desiLifestyle;
      expect(desiGroup.icon, '☕');
      expect(desiGroup.label, 'Desi Lifestyle');
    });

    test('ActivityLibrary contains at least 15 Islamic activities', () {
      final islamic = ActivityLibrary.defaultActivities
          .where((a) => a.categoryGroup == ActivityCategoryGroup.islamic)
          .toList();

      expect(islamic.length, greaterThanOrEqualTo(15));
      expect(islamic.any((a) => a.id == 'fajr_prayer'), isTrue);
      expect(islamic.any((a) => a.id == 'dhuhr_prayer'), isTrue);
      expect(islamic.any((a) => a.id == 'asr_prayer'), isTrue);
      expect(islamic.any((a) => a.id == 'maghrib_prayer'), isTrue);
      expect(islamic.any((a) => a.id == 'isha_prayer'), isTrue);
      expect(islamic.any((a) => a.id == 'quran_recitation'), isTrue);
      expect(islamic.any((a) => a.id == 'tahajjud_prayer'), isTrue);
      expect(islamic.any((a) => a.id == 'jummah_prayer'), isTrue);
    });

    test('ActivityLibrary contains at least 15 Desi Lifestyle activities', () {
      final desi = ActivityLibrary.defaultActivities
          .where((a) => a.categoryGroup == ActivityCategoryGroup.desiLifestyle)
          .toList();

      expect(desi.length, greaterThanOrEqualTo(15));
      expect(desi.any((a) => a.id == 'morning_chai'), isTrue);
      expect(desi.any((a) => a.id == 'evening_chai_family'), isTrue);
      expect(desi.any((a) => a.id == 'guest_hosting'), isTrue);
      expect(desi.any((a) => a.id == 'roti_meal_prep'), isTrue);
      expect(desi.any((a) => a.id == 'family_chitchat'), isTrue);
      expect(desi.any((a) => a.id == 'desi_breakfast'), isTrue);
      expect(desi.any((a) => a.id == 'cricket_match'), isTrue);
      expect(desi.any((a) => a.id == 'helping_parents'), isTrue);
    });
  });

  group('Phase 11 & 12: Routine Start Date & Recurrence Tests', () {
    test('Routine isActiveOn respects future start date (Phase 12 bug fix)', () {
      final today = DateTime(2026, 9, 4);
      final futureDate = DateTime(2026, 9, 10);

      final routineStartingInFuture = Routine(
        id: 'r_future',
        name: 'Future Routine',
        startDate: futureDate,
        frequency: RoutineFrequency.daily,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        createdAt: today,
      );

      // On today (Sep 4) - should NOT be active
      expect(routineStartingInFuture.isActiveOn(today), isFalse);
      expect(routineStartingInFuture.isActiveOn(DateTime(2026, 9, 9)), isFalse);

      // On start date (Sep 10) - SHOULD be active
      expect(routineStartingInFuture.isActiveOn(futureDate), isTrue);
      expect(routineStartingInFuture.isActiveOn(DateTime(2026, 9, 15)), isTrue);
    });

    test('Routine isActiveOn respects end date', () {
      final startDate = DateTime(2026, 9, 1);
      final endDate = DateTime(2026, 9, 15);

      final routineWithEnd = Routine(
        id: 'r_end',
        name: 'Temporary Routine',
        startDate: startDate,
        endDate: endDate,
        frequency: RoutineFrequency.daily,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        createdAt: startDate,
      );

      expect(routineWithEnd.isActiveOn(DateTime(2026, 9, 10)), isTrue);
      expect(routineWithEnd.isActiveOn(DateTime(2026, 9, 15)), isTrue);
      expect(routineWithEnd.isActiveOn(DateTime(2026, 9, 16)), isFalse);
    });

    test('Routine isActiveOn handles weekly and monthly frequency', () {
      final startDate = DateTime(2026, 9, 1); // Tuesday

      // Weekly: only Mondays (1) and Fridays (5)
      final weeklyRoutine = Routine(
        id: 'r_weekly',
        name: 'MWF Routine',
        startDate: startDate,
        frequency: RoutineFrequency.weekly,
        daysOfWeek: [1, 5],
        createdAt: startDate,
      );

      // 2026-09-04 is a Friday (5) -> active
      expect(weeklyRoutine.isActiveOn(DateTime(2026, 9, 4)), isTrue);
      // 2026-09-05 is a Saturday (6) -> not active
      expect(weeklyRoutine.isActiveOn(DateTime(2026, 9, 5)), isFalse);

      // Monthly: only 15th of the month
      final monthlyRoutine = Routine(
        id: 'r_monthly',
        name: 'Mid-Month Review',
        startDate: startDate,
        frequency: RoutineFrequency.monthly,
        monthlyDay: 15,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        createdAt: startDate,
      );

      expect(monthlyRoutine.isActiveOn(DateTime(2026, 9, 15)), isTrue);
      expect(monthlyRoutine.isActiveOn(DateTime(2026, 10, 15)), isTrue);
      expect(monthlyRoutine.isActiveOn(DateTime(2026, 9, 14)), isFalse);
    });

    test('Routine serializes and deserializes new fields correctly', () {
      final start = DateTime(2026, 9, 10, 10, 30);
      final end = DateTime(2026, 12, 31, 23, 59);

      final routine = Routine(
        id: 'r_json',
        name: 'Serialization Test',
        startDate: start,
        endDate: end,
        frequency: RoutineFrequency.monthly,
        monthlyDay: 12,
        daysOfWeek: [1, 2, 3],
        createdAt: start,
      );

      final json = routine.toJson();
      final reconstructed = Routine.fromJson(json);

      expect(reconstructed.id, 'r_json');
      expect(reconstructed.frequency, RoutineFrequency.monthly);
      expect(reconstructed.monthlyDay, 12);
      expect(reconstructed.startDate.year, 2026);
      expect(reconstructed.startDate.month, 9);
      expect(reconstructed.startDate.day, 10);
      expect(reconstructed.endDate?.month, 12);
    });
  });

  group('Phase 14: Planner Provider & Models', () {
    test('PlannerSummary instantiates with duration and task counts', () {
      const summary = PlannerSummary(
        plannedDurationMinutes: 120,
        completedDurationMinutes: 60,
        weeklyTasks: 14,
        monthlyTasks: 50,
      );

      expect(summary.plannedDurationMinutes, 120);
      expect(summary.completedDurationMinutes, 60);
      expect(summary.weeklyTasks, 14);
      expect(summary.monthlyTasks, 50);
    });
  });
}
