class DailyReportModel {
  final DateTime date;
  final int plannedActivities;
  final int completedActivities;
  final int missedActivities;
  final int recoveredActivities;
  final double completionPercentage;
  final int focusTimeMinutes;
  final double routineConsistency;
  final int tasksCompleted;
  final int tasksRemaining;

  DailyReportModel({
    required this.date,
    required this.plannedActivities,
    required this.completedActivities,
    required this.missedActivities,
    required this.recoveredActivities,
    required this.completionPercentage,
    required this.focusTimeMinutes,
    required this.routineConsistency,
    required this.tasksCompleted,
    required this.tasksRemaining,
  });
}

class WeeklyReportModel {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double totalPlannedHours;
  final double totalCompletedHours;
  final double completionRate;
  final int missedTasks;
  final int recoveredTasks;
  final String bestDay;
  final String weakestDay;
  final String mostProductiveTime;
  final double routineConsistency;
  final double goalProgress;
  final double projectProgress;

  WeeklyReportModel({
    required this.weekStart,
    required this.weekEnd,
    required this.totalPlannedHours,
    required this.totalCompletedHours,
    required this.completionRate,
    required this.missedTasks,
    required this.recoveredTasks,
    required this.bestDay,
    required this.weakestDay,
    required this.mostProductiveTime,
    required this.routineConsistency,
    required this.goalProgress,
    required this.projectProgress,
  });
}

class MonthlyReportModel {
  final DateTime monthStart;
  final DateTime monthEnd;
  final double completionTrend;
  final double productivityTrend;
  final double routineConsistencyTrend;
  final double goalProgress;
  final double projectProgress;
  final String strongestProductivityHours;
  final String weakestPeriod;
  final List<String> improvementSuggestions;

  MonthlyReportModel({
    required this.monthStart,
    required this.monthEnd,
    required this.completionTrend,
    required this.productivityTrend,
    required this.routineConsistencyTrend,
    required this.goalProgress,
    required this.projectProgress,
    required this.strongestProductivityHours,
    required this.weakestPeriod,
    required this.improvementSuggestions,
  });
}
