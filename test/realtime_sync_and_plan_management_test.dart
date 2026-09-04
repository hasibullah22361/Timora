import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';
import 'package:timora/features/routine/data/repositories/routine_repository.dart';
import 'package:timora/features/goals/data/repositories/goal_repository.dart';
import 'package:timora/features/projects/data/repositories/project_repository.dart';
import 'package:timora/features/habits/data/repositories/habit_repository.dart';
import 'package:timora/features/daily_plan/data/models/planned_task_block_model.dart';
import 'package:timora/features/daily_plan/data/repositories/daily_plan_repository.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';
import 'package:timora/features/weekly_plan/data/models/weekly_plan_model.dart';
import 'package:timora/features/weekly_plan/data/repositories/weekly_plan_repository.dart';
import 'package:timora/features/weekly_plan/presentation/providers/weekly_plan_provider.dart';
import 'package:timora/features/monthly_plan/data/models/monthly_plan_model.dart';
import 'package:timora/features/monthly_plan/data/repositories/monthly_plan_repository.dart';
import 'package:timora/features/monthly_plan/presentation/providers/monthly_plan_provider.dart';
import 'package:timora/features/routine/application/routine_scheduler_service.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/routine/data/models/routine_block.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Problem 1: Real User Data & Empty State (No Fake Auto-Seeding)', () {
    test('TaskRepository initializes with an empty list for fresh users', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = TaskRepository(prefs);

      final tasks = await repo.getTasks();
      expect(tasks, isEmpty, reason: 'TaskRepository must not auto-seed fake dummy tasks');
    });

    test('RoutineRepository initializes with an empty list for fresh users', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RoutineRepository(prefs);

      final routines = await repo.getAllRoutines();
      expect(routines, isEmpty, reason: 'RoutineRepository must not auto-seed fake routines');
    });

    test('GoalRepository initializes with empty goals and milestones', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = GoalRepository(prefs);

      final goals = await repo.getGoals();
      expect(goals, isEmpty, reason: 'GoalRepository must not auto-seed fake goals');
    });

    test('ProjectRepository initializes with empty projects', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ProjectRepository(prefs);

      final projects = await repo.getProjects();
      expect(projects, isEmpty, reason: 'ProjectRepository must not auto-seed fake projects');
    });

    test('HabitRepository initializes with empty habits and logs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = HabitRepository(prefs);

      final habits = await repo.getHabits();
      expect(habits, isEmpty, reason: 'HabitRepository must not auto-seed fake habits');
    });
  });

  group('Problem 6: Plan Deletion & Recreation Support', () {
    test('Daily Plan can be created, deleted, and immediately recreated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final today = DateTime(2026, 8, 29);
      final dailyNotifier = container.read(dailyPlanNotifierProvider);
      final dailyRepo = container.read(dailyPlanRepositoryProvider);

      // Add a planned block (which persists the plan and block)
      final block = PlannedTaskBlockModel(
        id: 'block-123',
        dailyPlanId: 'plan-123',
        taskId: 'task-123',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 0),
        estimatedDurationSeconds: 3600,
        createdAt: DateTime.now(),
      );

      await dailyNotifier.addPlannedBlock(block, today);
      var persistedPlan = await dailyRepo.getPlanForDate(today);
      expect(persistedPlan, isNotNull);
      var blocks = await dailyRepo.getBlocksForDate(persistedPlan!.id);
      expect(blocks.length, 1);

      // Delete the day plan
      await dailyNotifier.deleteDayPlan(today);
      persistedPlan = await dailyRepo.getPlanForDate(today);
      expect(persistedPlan, isNull, reason: 'Day plan must be deleted from storage');
      blocks = await dailyRepo.getBlocksForDate('plan-123');
      expect(blocks, isEmpty, reason: 'Planned blocks for deleted plan must be cleaned up');

      // Immediately recreate a new day plan
      final newBlock = PlannedTaskBlockModel(
        id: 'block-456',
        dailyPlanId: 'plan-456',
        taskId: 'task-456',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 0),
        estimatedDurationSeconds: 3600,
        createdAt: DateTime.now(),
      );
      await dailyNotifier.addPlannedBlock(newBlock, today);
      persistedPlan = await dailyRepo.getPlanForDate(today);
      expect(persistedPlan, isNotNull, reason: 'New day plan should be immediately creatable');
      expect(persistedPlan!.id, 'plan-456');
    });

    test('Weekly Plan can be created, deleted, and immediately recreated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final startOfWeek = getStartOfWeek(DateTime(2026, 8, 29));
      final weeklyNotifier = container.read(weeklyPlanNotifierProvider);
      final weeklyRepo = container.read(weeklyPlanRepositoryProvider);

      final plan = WeeklyPlanModel(
        id: 'week-1',
        weekStartDate: startOfWeek,
        weekEndDate: startOfWeek.add(const Duration(days: 6)),
        notes: 'Goal for the week',
        createdAt: DateTime.now(),
      );

      await weeklyNotifier.savePlan(plan);
      var persisted = await weeklyRepo.getPlanForWeek(startOfWeek);
      expect(persisted, isNotNull);
      expect(persisted!.notes, 'Goal for the week');

      // Delete Week Plan
      await weeklyNotifier.deleteWeekPlan(startOfWeek);
      persisted = await weeklyRepo.getPlanForWeek(startOfWeek);
      expect(persisted, isNull, reason: 'Weekly plan must be removed on delete');

      // Recreate Week Plan
      final newPlan = WeeklyPlanModel(
        id: 'week-2',
        weekStartDate: startOfWeek,
        weekEndDate: startOfWeek.add(const Duration(days: 6)),
        notes: 'Updated goal',
        createdAt: DateTime.now(),
      );
      await weeklyNotifier.savePlan(newPlan);
      persisted = await weeklyRepo.getPlanForWeek(startOfWeek);
      expect(persisted, isNotNull);
      expect(persisted!.id, 'week-2');
      expect(persisted.notes, 'Updated goal');
    });

    test('Monthly Plan can be created, deleted, and immediately recreated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final monthlyNotifier = container.read(monthlyPlanNotifierProvider);
      final monthlyRepo = container.read(monthlyPlanRepositoryProvider);

      final plan = MonthlyPlanModel(
        id: 'month-1',
        year: 2026,
        month: 8,
        notes: 'Monthly objectives',
        createdAt: DateTime.now(),
      );

      await monthlyNotifier.savePlan(plan);
      var persisted = await monthlyRepo.getPlanForMonth(2026, 8);
      expect(persisted, isNotNull);
      expect(persisted!.notes, 'Monthly objectives');

      // Delete Month Plan
      await monthlyNotifier.deleteMonthPlan(2026, 8);
      persisted = await monthlyRepo.getPlanForMonth(2026, 8);
      expect(persisted, isNull, reason: 'Monthly plan must be removed on delete');

      // Recreate Month Plan
      final newPlan = MonthlyPlanModel(
        id: 'month-2',
        year: 2026,
        month: 8,
        notes: 'New monthly objectives',
        createdAt: DateTime.now(),
      );
      await monthlyNotifier.savePlan(newPlan);
      persisted = await monthlyRepo.getPlanForMonth(2026, 8);
      expect(persisted, isNotNull);
      expect(persisted!.id, 'month-2');
      expect(persisted.notes, 'New monthly objectives');
    });
  });

  group('Routine & Schedule Cascade Cleanup', () {
    test('Deleting a routine cleans up its generated schedule activities', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final routineRepo = RoutineRepository(prefs);
      final scheduleRepo = ScheduleRepository(prefs);
      final scheduler = RoutineSchedulerService(routineRepo, scheduleRepo);

      final routine = Routine(
        id: 'r1',
        name: 'Morning Routine',
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        createdAt: DateTime.now(),
      );
      final block = RoutineBlock(
        id: 'b1',
        routineId: 'r1',
        title: 'Morning Yoga',
        category: 'Health',
        icon: '🧘',
        order: 0,
        startTime: const TimeOfDay(hour: 7, minute: 0),
        endTime: const TimeOfDay(hour: 8, minute: 0),
      );

      await routineRepo.addRoutine(routine, [block]);
      final today = DateTime(2026, 8, 29);
      await scheduler.generateScheduleForDate(today);

      var activities = await scheduleRepo.getActivitiesForDate(today);
      expect(activities.length, 1);
      expect(activities.first.title, 'Morning Yoga');

      // Cleanup activities for routine
      await scheduler.cleanupActivitiesForRoutine('r1');
      activities = await scheduleRepo.getActivitiesForDate(today);
      expect(activities, isEmpty, reason: 'Generated activities must be deleted when routine is removed');
    });
  });
}
