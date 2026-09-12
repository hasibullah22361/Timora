import 'analytics_models.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';

class DailyReportModel {
  final DateTime date;
  final int plannedActivities;
  final int completedActivities;
  final int missedActivities;
  final int recoveredActivities;
  final int replacedActivities;
  final double completionPercentage;
  final int focusTimeMinutes;
  final double routineConsistency;
  final int tasksCompleted;
  final int tasksRemaining;
  final AnalyticsInsight? topInsight;

  // Inspection lists
  final List<ScheduleActivity> plannedList;
  final List<ScheduleActivity> completedList;
  final List<ScheduleActivity> missedList;
  final List<ScheduleActivity> recoveredList;
  final List<ScheduleActivity> replacedList;

  DailyReportModel({
    required this.date,
    required this.plannedActivities,
    required this.completedActivities,
    required this.missedActivities,
    required this.recoveredActivities,
    this.replacedActivities = 0,
    required this.completionPercentage,
    required this.focusTimeMinutes,
    required this.routineConsistency,
    required this.tasksCompleted,
    required this.tasksRemaining,
    this.topInsight,
    this.plannedList = const [],
    this.completedList = const [],
    this.missedList = const [],
    this.recoveredList = const [],
    this.replacedList = const [],
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
  final int replacedActivities;
  final String bestDay;
  final String weakestDay;
  final String mostProductiveTime;
  final double routineConsistency;
  final double goalProgress;
  final double projectProgress;
  final List<AnalyticsInsight> weeklyInsights;

  // Inspection lists
  final List<ScheduleActivity> plannedList;
  final List<ScheduleActivity> completedList;
  final List<ScheduleActivity> missedList;
  final List<ScheduleActivity> recoveredList;
  final List<ScheduleActivity> replacedList;

  WeeklyReportModel({
    required this.weekStart,
    required this.weekEnd,
    required this.totalPlannedHours,
    required this.totalCompletedHours,
    required this.completionRate,
    required this.missedTasks,
    required this.recoveredTasks,
    this.replacedActivities = 0,
    required this.bestDay,
    required this.weakestDay,
    required this.mostProductiveTime,
    required this.routineConsistency,
    required this.goalProgress,
    required this.projectProgress,
    this.weeklyInsights = const [],
    this.plannedList = const [],
    this.completedList = const [],
    this.missedList = const [],
    this.recoveredList = const [],
    this.replacedList = const [],
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
  final List<AnalyticsInsight> monthlyInsights;
  final int replacedActivities;

  // Inspection lists
  final List<ScheduleActivity> plannedList;
  final List<ScheduleActivity> completedList;
  final List<ScheduleActivity> missedList;
  final List<ScheduleActivity> recoveredList;
  final List<ScheduleActivity> replacedList;

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
    this.monthlyInsights = const [],
    this.replacedActivities = 0,
    this.plannedList = const [],
    this.completedList = const [],
    this.missedList = const [],
    this.recoveredList = const [],
    this.replacedList = const [],
  });
}
