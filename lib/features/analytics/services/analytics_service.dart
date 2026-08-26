import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/analytics_models.dart';
import '../../focus/presentation/providers/focus_provider.dart';
import '../../focus/data/models/focus_session_model.dart';
import '../../tasks/presentation/providers/task_provider.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref);
});

class AnalyticsService {
  final Ref _ref;

  AnalyticsService(this._ref);

  DateTimeRange _getDateRange(AnalyticsPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case AnalyticsPeriod.today:
        return DateTimeRange(start: today, end: now);
      case AnalyticsPeriod.last7Days:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 6)), end: now);
      case AnalyticsPeriod.last30Days:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 29)), end: now);
      case AnalyticsPeriod.last90Days:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 89)), end: now);
      case AnalyticsPeriod.thisWeek:
        final daysToSubtract = today.weekday - 1;
        final startOfWeek = today.subtract(Duration(days: daysToSubtract));
        return DateTimeRange(start: startOfWeek, end: now);
      case AnalyticsPeriod.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
  }

  Future<FocusStats> getFocusStats(AnalyticsPeriod period) async {
    final range = _getDateRange(period);
    // In a real app we'd query the DB with a date range filter.
    // For this demonstration, we filter the entire list in memory.
    final allSessions = await _ref
        .read(allFocusSessionsProvider.future); // Assuming this provider exists

    final validSessions = allSessions.where((s) {
      return s.status == FocusSessionStatus.completed &&
          s.createdAt.isAfter(range.start) &&
          s.createdAt.isBefore(range.end);
    }).toList();

    int totalSeconds = 0;
    int longest = 0;
    Map<DateTime, int> trends = {};

    for (var s in validSessions) {
      totalSeconds += s.actualDurationSeconds.toInt();
      if (s.actualDurationSeconds > longest) longest = s.actualDurationSeconds;

      final day =
          DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      trends[day] = (trends[day] ?? 0) + s.actualDurationSeconds.toInt();
    }

    // Ensure all days in range have a trend entry (0 if empty)
    for (int i = 0; i <= range.end.difference(range.start).inDays; i++) {
      final day = range.start.add(Duration(days: i));
      trends.putIfAbsent(day, () => 0);
    }

    final sortedKeys = trends.keys.toList()..sort();
    final sortedTrends = {for (var k in sortedKeys) k: trends[k]!};

    return FocusStats(
      totalSeconds: totalSeconds,
      sessionCount: validSessions.length,
      averageSessionSeconds:
          validSessions.isEmpty ? 0 : totalSeconds ~/ validSessions.length,
      longestSessionSeconds: longest,
      dailyTrends: sortedTrends,
    );
  }

  Future<TaskStats> getTaskStats(AnalyticsPeriod period) async {
    final range = _getDateRange(period);
    final allTasks = await _ref.read(allTasksProvider.future);

    // Simplification: just counting tasks created or completed in period
    final relevantTasks = allTasks.where((t) {
      return (t.createdAt.isAfter(range.start) &&
              t.createdAt.isBefore(range.end)) ||
          (t.isCompleted &&
              t.updatedAt != null &&
              t.updatedAt!.isAfter(range.start) &&
              t.updatedAt!.isBefore(range.end));
    }).toList();

    int completed = 0;
    int pending = 0;
    int overdue = 0;
    final now = DateTime.now();

    for (var t in relevantTasks) {
      if (t.isCompleted) {
        completed++;
      } else {
        pending++;
        if (t.dueDate != null && t.dueDate!.isBefore(now)) overdue++;
      }
    }

    return TaskStats(
      completed: completed,
      pending: pending,
      overdue: overdue,
      completionRate:
          relevantTasks.isEmpty ? 0.0 : completed / relevantTasks.length,
    );
  }

  Future<PlanningStats> getPlanningStats(AnalyticsPeriod period) async {
    // Very simplified for demonstration
    final focusStats = await getFocusStats(period);

    // In a real app we'd sum up all PlannedTaskBlock duration in the period.
    // Simulating planned time as 120% of focus time for now.
    final planned = (focusStats.totalSeconds * 1.2).toInt();

    return PlanningStats(
      plannedSeconds: planned,
      actualFocusSeconds: focusStats.totalSeconds,
      planAccuracyPercentage:
          planned == 0 ? 0.0 : focusStats.totalSeconds / planned,
    );
  }

  Future<List<AnalyticsInsight>> getInsights(AnalyticsPeriod period) async {
    final insights = <AnalyticsInsight>[];
    final focus = await getFocusStats(period);

    if (focus.totalSeconds > 0) {
      // Find best day
      DateTime? bestDay;
      int maxFocus = 0;
      focus.dailyTrends.forEach((k, v) {
        if (v > maxFocus) {
          maxFocus = v;
          bestDay = k;
        }
      });

      if (bestDay != null) {
        const days = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        insights.add(AnalyticsInsight(
          id: const Uuid().v4(),
          type: 'focus_best_day',
          description:
              '${days[bestDay!.weekday - 1]} was your highest-focus day.',
        ));
      }

      insights.add(AnalyticsInsight(
        id: const Uuid().v4(),
        type: 'focus_average',
        description:
            'Your average focus session is ${focus.averageSessionSeconds ~/ 60} minutes.',
      ));
    }

    final tasks = await getTaskStats(period);
    if (tasks.completed > 0) {
      insights.add(AnalyticsInsight(
        id: const Uuid().v4(),
        type: 'task_completion',
        description:
            'You completed ${(tasks.completionRate * 100).toInt()}% of your tasks in this period.',
      ));
    }

    return insights;
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  DateTimeRange({required this.start, required this.end});
}
