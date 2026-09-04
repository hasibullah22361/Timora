import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';
import 'package:timora/features/weekly_plan/presentation/providers/weekly_plan_provider.dart';
import 'package:timora/features/monthly_plan/presentation/providers/monthly_plan_provider.dart';

enum PlannerTab { daily, weekly, monthly }

final activePlannerTabProvider = StateProvider<PlannerTab>((ref) => PlannerTab.daily);

/// Aggregated planner summary for dashboard / quick stats
final plannerSummaryProvider = Provider<AsyncValue<PlannerSummary>>((ref) {
  final today = ref.watch(selectedDateProvider);
  final dailyPlanAsync = ref.watch(dailyPlanProvider(today));
  final weekStart = ref.watch(selectedWeekProvider);
  final weeklyStatsAsync = ref.watch(weeklyStatsProvider(weekStart));
  final monthDate = ref.watch(selectedMonthProvider);
  final monthlyStatsAsync = ref.watch(monthlyStatsProvider(monthDate));

  if (dailyPlanAsync.isLoading || weeklyStatsAsync.isLoading || monthlyStatsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  try {
    final dailyPlan = dailyPlanAsync.valueOrNull;
    final weeklyStats = weeklyStatsAsync.valueOrNull;
    final monthlyStats = monthlyStatsAsync.valueOrNull;

    final plannedMins = (dailyPlan?.plannedDurationSeconds ?? 0) ~/ 60;
    final completedMins = (dailyPlan?.completedDurationSeconds ?? 0) ~/ 60;

    return AsyncValue.data(
      PlannerSummary(
        plannedDurationMinutes: plannedMins,
        completedDurationMinutes: completedMins,
        weeklyTasks: weeklyStats?.totalTasks ?? 0,
        monthlyTasks: monthlyStats?.totalTasks ?? 0,
      ),
    );
  } catch (e, st) {
    return AsyncValue.error(e, st);
  }
});

class PlannerSummary {
  final int plannedDurationMinutes;
  final int completedDurationMinutes;
  final int weeklyTasks;
  final int monthlyTasks;

  const PlannerSummary({
    required this.plannedDurationMinutes,
    required this.completedDurationMinutes,
    required this.weeklyTasks,
    required this.monthlyTasks,
  });
}
