import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:timora/features/monthly_plan/data/models/monthly_plan_model.dart';
import 'package:timora/features/monthly_plan/data/repositories/monthly_plan_repository.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';

import 'package:timora/features/daily_plan/data/repositories/daily_plan_repository.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final monthlyPlanProvider = FutureProvider.family<MonthlyPlanModel, DateTime>((ref, monthDate) async {
  final repo = ref.watch(monthlyPlanRepositoryProvider);
  final plan = await repo.getPlanForMonth(monthDate.year, monthDate.month);
  
  if (plan == null) {
    return MonthlyPlanModel(
      id: const Uuid().v4(),
      year: monthDate.year,
      month: monthDate.month,
      createdAt: DateTime.now(),
    );
  }
  return plan;
});

class MonthlyStats {
  final int totalPlannedSeconds;
  final int totalCompletedSeconds;
  final int totalTasks;
  final int completedTasks;

  MonthlyStats({
    this.totalPlannedSeconds = 0,
    this.totalCompletedSeconds = 0,
    this.totalTasks = 0,
    this.completedTasks = 0,
  });
}

final monthlyStatsProvider = FutureProvider.family<MonthlyStats, DateTime>((ref, monthDate) async {
  int plannedSecs = 0;
  int completedSecs = 0;
  int totalTasks = 0;
  int completedTasks = 0;

  final dailyRepo = ref.watch(dailyPlanRepositoryProvider);
  final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
  
  for (int i = 1; i <= daysInMonth; i++) {
    final date = DateTime(monthDate.year, monthDate.month, i);
    final plan = await dailyRepo.getPlanForDate(date);
    if (plan != null) {
      plannedSecs += plan.plannedDurationSeconds;
      completedSecs += plan.completedDurationSeconds;
      
      final blocks = await dailyRepo.getBlocksForDate(plan.id);
      totalTasks += blocks.length;
      completedTasks += blocks.where((b) => b.status.name == 'completed').length;
    }
  }

  return MonthlyStats(
    totalPlannedSeconds: plannedSecs,
    totalCompletedSeconds: completedSecs,
    totalTasks: totalTasks,
    completedTasks: completedTasks,
  );
});

class MonthlyPlanNotifier extends StateNotifier<AsyncValue<void>> {
  final MonthlyPlanRepository _repo;
  final DailyPlanRepository _dailyRepo;
  final Ref _ref;

  MonthlyPlanNotifier(this._repo, this._dailyRepo, this._ref) : super(const AsyncValue.data(null));

  Future<void> savePlan(MonthlyPlanModel plan) async {
    await _repo.savePlan(plan);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'monthly_plans',
      entityId: plan.id,
      operation: SyncOperation.create,
    );
    final monthDate = DateTime(plan.year, plan.month, 1);
    _ref.invalidate(monthlyPlanProvider(monthDate));
    _ref.invalidate(monthlyStatsProvider(monthDate));
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> deleteMonthPlan(int year, int month, {bool deleteDailyPlans = false}) async {
    final deletedPlan = await _repo.deletePlanForMonth(year, month);
    if (deletedPlan != null) {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'monthly_plans',
        entityId: deletedPlan.id,
        operation: SyncOperation.delete,
      );
    }

    final monthDate = DateTime(year, month, 1);
    if (deleteDailyPlans) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int i = 1; i <= daysInMonth; i++) {
        final date = DateTime(year, month, i);
        await _dailyRepo.deletePlanForDate(date);
        _ref.invalidate(dailyPlanProvider(date));
        _ref.invalidate(timelineProvider(date));
      }
    }

    _ref.invalidate(monthlyPlanProvider(monthDate));
    _ref.invalidate(monthlyStatsProvider(monthDate));
    _ref.read(syncServiceProvider).autoSync();
  }
}

final monthlyPlanNotifierProvider = Provider<MonthlyPlanNotifier>((ref) {
  return MonthlyPlanNotifier(
    ref.watch(monthlyPlanRepositoryProvider),
    ref.watch(dailyPlanRepositoryProvider),
    ref,
  );
});
