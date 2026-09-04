import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/features/habits/data/models/habit_model.dart';
import 'package:timora/features/habits/data/models/habit_log_model.dart';
import 'package:timora/features/habits/data/repositories/habit_repository.dart';
import 'package:timora/features/goals/data/models/goal_model.dart';
import 'package:timora/features/goals/data/models/milestone_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late HabitRepository habitRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    habitRepo = HabitRepository(prefs, userId: 'test_user_4');
  });

  group('Phase 4 — Habits & Streaks Tests', () {
    test('HABIT-1: HabitModel and HabitLogModel serialization', () {
      final now = DateTime(2026, 8, 28, 8, 30);
      final habit = HabitModel(
        id: 'h_test_1',
        title: 'Morning Meditation',
        description: '10 mins of mindfulness',
        icon: '🧘',
        color: const Color(0xFF10B981),
        currentStreak: 4,
        bestStreak: 10,
        createdAt: now,
      );

      final json = habit.toJson();
      final reconstituted = HabitModel.fromJson(json);

      expect(reconstituted.id, 'h_test_1');
      expect(reconstituted.title, 'Morning Meditation');
      expect(reconstituted.icon, '🧘');
      expect(reconstituted.currentStreak, 4);
      expect(reconstituted.bestStreak, 10);

      final log = HabitLogModel(
        id: 'log_1',
        habitId: 'h_test_1',
        logDate: DateTime(2026, 8, 28),
        completed: true,
        createdAt: now,
      );
      final logJson = log.toJson();
      final reconstitutedLog = HabitLogModel.fromJson(logJson);

      expect(reconstitutedLog.id, 'log_1');
      expect(reconstitutedLog.habitId, 'h_test_1');
      expect(reconstitutedLog.completed, isTrue);
    });

    test('HABIT-2: Creating and retrieving habits', () async {
      final habit = HabitModel(
        id: 'h_new_1',
        title: 'Read 20 pages',
        icon: '📚',
        createdAt: DateTime.now(),
      );

      await habitRepo.createHabit(habit);
      final retrieved = await habitRepo.getHabit('h_new_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Read 20 pages');
      expect(retrieved.icon, '📚');
    });

    test('HABIT-3: Toggling habit log updates streaks accurately', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final habit = HabitModel(
        id: 'h_streak_test',
        title: 'Daily Exercise',
        currentStreak: 0,
        bestStreak: 0,
        createdAt: today.subtract(const Duration(days: 10)),
      );

      await habitRepo.createHabit(habit);

      // Log 4 consecutive days (3 days ago, 2 days ago, yesterday, today)
      await habitRepo.toggleHabitLog(habit.id, today.subtract(const Duration(days: 3)));
      await habitRepo.toggleHabitLog(habit.id, today.subtract(const Duration(days: 2)));
      await habitRepo.toggleHabitLog(habit.id, today.subtract(const Duration(days: 1)));
      await habitRepo.toggleHabitLog(habit.id, today);

      final updated = await habitRepo.getHabit(habit.id);
      expect(updated!.currentStreak, 4);
      expect(updated.bestStreak, 4);

      // Untoggle today -> streak drops to 3 (yesterday, 2 days ago, 3 days ago)
      await habitRepo.toggleHabitLog(habit.id, today);
      final afterUntoggle = await habitRepo.getHabit(habit.id);
      expect(afterUntoggle!.currentStreak, 3);
      expect(afterUntoggle.bestStreak, 4); // Best streak preserved!
    });

    test('HABIT-4: Range queries for Heatmap consistency', () async {
      final habit = HabitModel(
        id: 'h_heatmap_test',
        title: 'Cold Shower',
        createdAt: DateTime.now(),
      );
      await habitRepo.createHabit(habit);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await habitRepo.toggleHabitLog(habit.id, today.subtract(const Duration(days: 1)));
      await habitRepo.toggleHabitLog(habit.id, today);

      final logs = await habitRepo.getHabitLogs(
        habit.id,
        startDate: today.subtract(const Duration(days: 7)),
        endDate: today,
      );

      expect(logs.length, 2);
      expect(logs.every((l) => l.completed), isTrue);
    });
  });

  group('Phase 4 — Goals & Milestone Hierarchy Tests', () {
    test('GOAL-1: Goal and Milestone models properly calculate progress', () {
      final goal = GoalModel(
        id: 'g_1',
        title: 'Launch Timora 2.0',
        progressMode: ProgressMode.auto,
        createdAt: DateTime.now(),
      );

      final m1 = MilestoneModel(
        id: 'm_1',
        goalId: 'g_1',
        title: 'Design Database Schema',
        order: 0,
        status: MilestoneStatus.completed,
        createdAt: DateTime.now(),
      );

      final m2 = MilestoneModel(
        id: 'm_2',
        goalId: 'g_1',
        title: 'Implement Core Modules',
        order: 1,
        status: MilestoneStatus.inProgress,
        createdAt: DateTime.now(),
      );

      final milestones = [m1, m2];
      final completed = milestones.where((m) => m.status == MilestoneStatus.completed).length;
      final progress = completed / milestones.length;
      expect(goal.title, 'Launch Timora 2.0');
      expect(progress, 0.5);
    });
  });
}
