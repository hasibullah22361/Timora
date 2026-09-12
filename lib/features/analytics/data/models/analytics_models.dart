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

enum InsightCategory {
  productivityPattern,
  scheduleEffectiveness,
  routineConsistency,
  missedTask,
  trend,
  general,
}

enum InsightImpact {
  high,
  medium,
  low,
}

enum InsightActionType {
  rescheduleTask,
  scheduleFocusBlock,
  planTomorrow,
  startFocusSession,
  reviewRoutines,
  none,
}

class AnalyticsInsight {
  final String id;
  final String type;
  final String title;
  final String description;
  final String explanation;
  final String recommendation;
  final InsightCategory category;
  final InsightImpact impact;
  final InsightActionType actionType;
  final String? actionLabel;
  final Map<String, dynamic>? actionData;
  final double confidence;
  final bool hasSufficientData;
  final String icon;
  final DateTime createdAt;

  AnalyticsInsight({
    required this.id,
    required this.type,
    required this.description,
    String? title,
    String? explanation,
    String? recommendation,
    this.category = InsightCategory.general,
    this.impact = InsightImpact.medium,
    this.actionType = InsightActionType.none,
    this.actionLabel,
    this.actionData,
    this.confidence = 1.0,
    this.hasSufficientData = true,
    String? icon,
    DateTime? createdAt,
  })  : title = title ?? _defaultTitleForCategory(category, type),
        explanation = explanation ?? description,
        recommendation = recommendation ?? '',
        icon = icon ?? _defaultIconForCategory(category),
        createdAt = createdAt ?? DateTime.now();

  static String _defaultTitleForCategory(InsightCategory cat, String type) {
    switch (cat) {
      case InsightCategory.productivityPattern:
        return 'Productivity Pattern';
      case InsightCategory.scheduleEffectiveness:
        return 'Schedule Effectiveness';
      case InsightCategory.routineConsistency:
        return 'Routine Consistency';
      case InsightCategory.missedTask:
        return 'Task Attention Alert';
      case InsightCategory.trend:
        return 'Performance Trend';
      case InsightCategory.general:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  static String _defaultIconForCategory(InsightCategory cat) {
    switch (cat) {
      case InsightCategory.productivityPattern:
        return '🧠';
      case InsightCategory.scheduleEffectiveness:
        return '📅';
      case InsightCategory.routineConsistency:
        return '🔥';
      case InsightCategory.missedTask:
        return '⚠️';
      case InsightCategory.trend:
        return '📈';
      case InsightCategory.general:
        return '💡';
    }
  }
}

class ProductivityTimeSlotStats {
  final String label;
  final int startHour;
  final int endHour;
  final int completedTasks;
  final int totalTasks;
  final int focusMinutes;
  final double completionRate;

  const ProductivityTimeSlotStats({
    required this.label,
    required this.startHour,
    required this.endHour,
    this.completedTasks = 0,
    this.totalTasks = 0,
    this.focusMinutes = 0,
    this.completionRate = 0.0,
  });
}

