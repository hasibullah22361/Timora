import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:timora/features/monthly_plan/data/models/monthly_plan_model.dart';
import 'package:timora/features/monthly_plan/data/repositories/monthly_plan_repository.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final monthlyPlanProvider = FutureProvider.family<MonthlyPlanModel, DateTime>((ref, monthDate) async {
  final repo = ref.watch(monthlyPlanRepositoryProvider);
  var plan = await repo.getPlanForMonth(monthDate.year, monthDate.month);
  
  if (plan == null) {
    plan = MonthlyPlanModel(
      id: const Uuid().v4(),
      year: monthDate.year,
      month: monthDate.month,
      createdAt: DateTime.now(),
    );
    await repo.savePlan(plan);
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

  final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
  
  for (int i = 1; i <= daysInMonth; i++) {
    final date = DateTime(monthDate.year, monthDate.month, i);
    final plan = await ref.watch(dailyPlanProvider(date).future);
    
    plannedSecs += plan.plannedDurationSeconds;
    completedSecs += plan.completedDurationSeconds;
    
    final blocks = await ref.watch(plannedBlocksProvider(plan.id).future);
    totalTasks += blocks.length;
    completedTasks += blocks.where((b) => b.status.name == 'completed').length;
  }

  return MonthlyStats(
    totalPlannedSeconds: plannedSecs,
    totalCompletedSeconds: completedSecs,
    totalTasks: totalTasks,
    completedTasks: completedTasks,
  );
});
