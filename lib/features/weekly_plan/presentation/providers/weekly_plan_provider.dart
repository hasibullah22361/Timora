import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:timora/features/weekly_plan/data/models/weekly_plan_model.dart';
import 'package:timora/features/weekly_plan/data/repositories/weekly_plan_repository.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';

import 'package:timora/features/daily_plan/data/repositories/daily_plan_repository.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';

// Helper to get the start of the week (assuming Monday)
DateTime getStartOfWeek(DateTime date) {
  final daysToSubtract = date.weekday - 1; // 1 = Monday
  final start = date.subtract(Duration(days: daysToSubtract));
  return DateTime(start.year, start.month, start.day);
}

final selectedWeekProvider = StateProvider<DateTime>((ref) {
  return getStartOfWeek(DateTime.now());
});

final weeklyPlanProvider = FutureProvider.family<WeeklyPlanModel, DateTime>((ref, startOfWeek) async {
  final repo = ref.watch(weeklyPlanRepositoryProvider);
  final plan = await repo.getPlanForWeek(startOfWeek);
  
  if (plan == null) {
    return WeeklyPlanModel(
      id: const Uuid().v4(),
      weekStartDate: startOfWeek,
      weekEndDate: startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59)),
      createdAt: DateTime.now(),
    );
  }
  return plan;
});

// A provider that aggregates stats from the 7 daily plans of the week
class WeeklyStats {
  final int totalPlannedSeconds;
  final int totalCompletedSeconds;
  final int totalTasks;
  final int completedTasks;

  WeeklyStats({
    this.totalPlannedSeconds = 0,
    this.totalCompletedSeconds = 0,
    this.totalTasks = 0,
    this.completedTasks = 0,
  });
}

final weeklyStatsProvider = FutureProvider.family<WeeklyStats, DateTime>((ref, startOfWeek) async {
  int plannedSecs = 0;
  int completedSecs = 0;
  int totalTasks = 0;
  int completedTasks = 0;

  final dailyRepo = ref.watch(dailyPlanRepositoryProvider);

  for (int i = 0; i < 7; i++) {
    final date = startOfWeek.add(Duration(days: i));
    final plan = await dailyRepo.getPlanForDate(date);
    if (plan != null) {
      plannedSecs += plan.plannedDurationSeconds;
      completedSecs += plan.completedDurationSeconds;
      
      final blocks = await dailyRepo.getBlocksForDate(plan.id);
      totalTasks += blocks.length;
      completedTasks += blocks.where((b) => b.status.name == 'completed').length;
    }
  }

  return WeeklyStats(
    totalPlannedSeconds: plannedSecs,
    totalCompletedSeconds: completedSecs,
    totalTasks: totalTasks,
    completedTasks: completedTasks,
  );
});

class WeeklyPlanNotifier extends StateNotifier<AsyncValue<void>> {
  final WeeklyPlanRepository _repo;
  final DailyPlanRepository _dailyRepo;
  final Ref _ref;

  WeeklyPlanNotifier(this._repo, this._dailyRepo, this._ref) : super(const AsyncValue.data(null));

  Future<void> savePlan(WeeklyPlanModel plan) async {
    await _repo.savePlan(plan);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'weekly_plans',
      entityId: plan.id,
      operation: SyncOperation.create,
    );
    _ref.invalidate(weeklyPlanProvider(plan.weekStartDate));
    _ref.invalidate(weeklyStatsProvider(plan.weekStartDate));
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> deleteWeekPlan(DateTime startOfWeek, {bool deleteDailyPlans = false}) async {
    final deletedPlan = await _repo.deletePlanForWeek(startOfWeek);
    if (deletedPlan != null) {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'weekly_plans',
        entityId: deletedPlan.id,
        operation: SyncOperation.delete,
      );
    }

    if (deleteDailyPlans) {
      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        await _dailyRepo.deletePlanForDate(date);
        _ref.invalidate(dailyPlanProvider(date));
        _ref.invalidate(timelineProvider(date));
      }
    }

    _ref.invalidate(weeklyPlanProvider(startOfWeek));
    _ref.invalidate(weeklyStatsProvider(startOfWeek));
    _ref.read(syncServiceProvider).autoSync();
  }
}

final weeklyPlanNotifierProvider = Provider<WeeklyPlanNotifier>((ref) {
  return WeeklyPlanNotifier(
    ref.watch(weeklyPlanRepositoryProvider),
    ref.watch(dailyPlanRepositoryProvider),
    ref,
  );
});
