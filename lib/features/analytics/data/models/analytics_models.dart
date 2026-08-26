enum AnalyticsPeriod {
  today,
  last7Days,
  last30Days,
  last90Days,
  thisWeek,
  thisMonth,
}

extension AnalyticsPeriodExt on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.today: return 'Today';
      case AnalyticsPeriod.last7Days: return 'Last 7 Days';
      case AnalyticsPeriod.last30Days: return 'Last 30 Days';
      case AnalyticsPeriod.last90Days: return 'Last 90 Days';
      case AnalyticsPeriod.thisWeek: return 'This Week';
      case AnalyticsPeriod.thisMonth: return 'This Month';
    }
  }
}

class FocusStats {
  final int totalSeconds;
  final int sessionCount;
  final int averageSessionSeconds;
  final int longestSessionSeconds;
  final Map<DateTime, int> dailyTrends;

  FocusStats({
    this.totalSeconds = 0,
    this.sessionCount = 0,
    this.averageSessionSeconds = 0,
    this.longestSessionSeconds = 0,
    this.dailyTrends = const {},
  });
}

class TaskStats {
  final int completed;
  final int pending;
  final int overdue;
  final double completionRate;

  TaskStats({
    this.completed = 0,
    this.pending = 0,
    this.overdue = 0,
    this.completionRate = 0.0,
  });
}

class PlanningStats {
  final int plannedSeconds;
  final int actualFocusSeconds;
  final double planAccuracyPercentage;

  PlanningStats({
    this.plannedSeconds = 0,
    this.actualFocusSeconds = 0,
    this.planAccuracyPercentage = 0.0,
  });
}

class AnalyticsInsight {
  final String id;
  final String type;
  final String description;

  AnalyticsInsight({
    required this.id,
    required this.type,
    required this.description,
  });
}
