import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/routine/data/models/routine_template.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/services/smart_rescheduling_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 — Routine Templates Tests', () {
    test('ROUTINE-1: Predefined templates exist and instantiate cleanly', () {
      final templates = RoutineTemplate.predefinedTemplates;
      expect(templates.length, greaterThanOrEqualTo(5));

      final morning = templates.firstWhere((t) => t.id == 'tpl_morning_momentum');
      expect(morning.title, 'Morning Momentum');
      expect(morning.blocks.length, greaterThanOrEqualTo(3));

      final routine = morning.instantiateRoutine('r_test_1');
      final blocks = morning.instantiateBlocks('r_test_1');

      expect(routine.id, 'r_test_1');
      expect(routine.name, 'Morning Momentum');
      expect(routine.enabled, isTrue);
      expect(blocks.length, morning.blocks.length);
      expect(blocks.first.routineId, 'r_test_1');
      expect(blocks.first.startTime, const TimeOfDay(hour: 6, minute: 30));
    });

    test('ROUTINE-2: Deep work power blocks template contains focus blocks', () {
      final deepWork = RoutineTemplate.predefinedTemplates.firstWhere((t) => t.id == 'tpl_deep_work');
      expect(deepWork.title, contains('Deep Work'));
      expect(deepWork.blocks.any((b) => b.category == 'Work'), isTrue);
    });
  });

  group('Phase 3 — Smart Rescheduling & Conflict Resolution Tests', () {
    test('CONFLICT-1: Detects overlapping schedule activities', () {
      final baseDate = DateTime(2026, 8, 28);
      final activityA = ScheduleActivity(
        id: 'act_1',
        title: 'Deep Work A',
        startTime: DateTime(2026, 8, 28, 9, 0),
        endTime: DateTime(2026, 8, 28, 10, 30),
        date: baseDate,
        createdAt: baseDate,
      );

      final activityB = ScheduleActivity(
        id: 'act_2',
        title: 'Team Sync',
        startTime: DateTime(2026, 8, 28, 10, 0), // Overlaps by 30 mins
        endTime: DateTime(2026, 8, 28, 11, 0),
        date: baseDate,
        createdAt: baseDate,
      );

      final conflicts = SmartReschedulingService.detectConflicts([activityA, activityB]);
      expect(conflicts.length, 1);
      expect(conflicts.first.overlapDuration.inMinutes, 30);
    });

    test('CONFLICT-2: Non-overlapping activities produce no conflicts', () {
      final baseDate = DateTime(2026, 8, 28);
      final activityA = ScheduleActivity(
        id: 'act_1',
        title: 'Morning Routine',
        startTime: DateTime(2026, 8, 28, 8, 0),
        endTime: DateTime(2026, 8, 28, 9, 0),
        date: baseDate,
        createdAt: baseDate,
      );

      final activityB = ScheduleActivity(
        id: 'act_2',
        title: 'Deep Work',
        startTime: DateTime(2026, 8, 28, 9, 0),
        endTime: DateTime(2026, 8, 28, 10, 30),
        date: baseDate,
        createdAt: baseDate,
      );

      final conflicts = SmartReschedulingService.detectConflicts([activityA, activityB]);
      expect(conflicts, isEmpty);
    });

    test('CONFLICT-3: Resolves overlapping activities by shifting subsequent block', () {
      final baseDate = DateTime(2026, 8, 28);
      final activityA = ScheduleActivity(
        id: 'act_1',
        title: 'Deep Work A',
        startTime: DateTime(2026, 8, 28, 9, 0),
        endTime: DateTime(2026, 8, 28, 10, 30),
        date: baseDate,
        createdAt: baseDate,
      );

      final activityB = ScheduleActivity(
        id: 'act_2',
        title: 'Team Sync',
        startTime: DateTime(2026, 8, 28, 10, 0),
        endTime: DateTime(2026, 8, 28, 11, 0),
        date: baseDate,
        createdAt: baseDate,
      );

      final resolved = SmartReschedulingService.resolveConflicts([activityA, activityB]);
      expect(resolved.length, 2);
      expect(resolved[0].startTime, DateTime(2026, 8, 28, 9, 0));
      expect(resolved[0].endTime, DateTime(2026, 8, 28, 10, 30));
      
      // Activity B is shifted to start at 10:30 and end at 11:30 (preserving 60 min duration)
      expect(resolved[1].startTime, DateTime(2026, 8, 28, 10, 30));
      expect(resolved[1].endTime, DateTime(2026, 8, 28, 11, 30));
      expect(resolved[1].isOverridden, isTrue);

      // Verify no conflicts remaining
      final remainingConflicts = SmartReschedulingService.detectConflicts(resolved);
      expect(remainingConflicts, isEmpty);
    });

    test('RECURRENCE-1: Calculates accurate next date for daily recurrence', () {
      final current = DateTime(2026, 8, 28);
      final next = SmartReschedulingService.calculateNextRecurringDate(
        currentDate: current,
        recurrence: 'daily',
      );
      expect(next, DateTime(2026, 8, 29));
    });

    test('RECURRENCE-2: Calculates accurate next date for weekly recurrence', () {
      final current = DateTime(2026, 8, 28); // Friday (weekday 5)
      final next = SmartReschedulingService.calculateNextRecurringDate(
        currentDate: current,
        recurrence: 'weekly',
        daysOfWeek: [1, 5], // Monday and Friday
      );
      // Next day from Friday with [1, 5] is Monday (3 days later)
      expect(next.weekday, 1);
    });
  });
}
