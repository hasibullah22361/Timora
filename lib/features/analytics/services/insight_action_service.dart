import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/analytics_models.dart';
import '../data/models/productivity_event_model.dart';
import '../data/repositories/productivity_event_repository.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/presentation/providers/schedule_provider.dart';
import '../../focus/presentation/providers/focus_provider.dart';
import '../../focus/data/models/focus_session_model.dart';
import 'insights_engine_service.dart';
import 'report_generator_service.dart';

class InsightActionResult {
  final bool success;
  final String message;
  final String? navigationTarget;

  const InsightActionResult({
    required this.success,
    required this.message,
    this.navigationTarget,
  });
}

final insightActionServiceProvider = Provider<InsightActionService>((ref) {
  return InsightActionService(ref);
});

class InsightActionService {
  final Ref _ref;

  InsightActionService(this._ref);

  Future<InsightActionResult> executeAction(AnalyticsInsight insight) async {
    switch (insight.actionType) {
      case InsightActionType.rescheduleTask:
        return _handleRescheduleTask(insight);

      case InsightActionType.scheduleFocusBlock:
        return _handleScheduleFocusBlock(insight);

      case InsightActionType.startFocusSession:
        return _handleStartFocusSession(insight);

      case InsightActionType.planTomorrow:
        return const InsightActionResult(
          success: true,
          message: 'Opening tomorrow\'s planner...',
          navigationTarget: 'daily_plan',
        );

      case InsightActionType.reviewRoutines:
        return const InsightActionResult(
          success: true,
          message: 'Opening routines checklist...',
          navigationTarget: 'routines',
        );

      case InsightActionType.none:
        return const InsightActionResult(
          success: true,
          message: 'Insight reviewed.',
        );
    }
  }

  Future<InsightActionResult> _handleRescheduleTask(AnalyticsInsight insight) async {
    final data = insight.actionData ?? {};
    final taskId = data['taskId'] as String?;
    final taskTitle = data['taskTitle'] as String? ?? 'Task';
    final targetHour = (data['targetHour'] as int?) ?? 9;
    final durationMinutes = (data['durationMinutes'] as int?) ?? 45;

    if (taskId == null || taskId.isEmpty) {
      return const InsightActionResult(
        success: false,
        message: 'No specific task target found to reschedule.',
      );
    }

    final taskRepo = _ref.read(taskRepositoryProvider);
    final existingTask = await taskRepo.getTask(taskId);

    if (existingTask == null) {
      return InsightActionResult(
        success: false,
        message: 'Task "$taskTitle" not found or was deleted.',
      );
    }

    final now = DateTime.now();
    // If targetHour has already passed today, schedule for tomorrow
    final targetDate = now.hour >= targetHour
        ? DateTime(now.year, now.month, now.day).add(const Duration(days: 1))
        : DateTime(now.year, now.month, now.day);

    final startMinutes = targetHour * 60;
    final endMinutes = startMinutes + durationMinutes;

    final updated = existingTask.copyWith(
      dueDate: targetDate,
      dueTime: TimeOfDay(hour: targetHour, minute: 0),
      startTime: TimeOfDay(hour: targetHour, minute: 0),
      endTime: TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60),
      status: TaskStatus.pending,
      updatedAt: DateTime.now(),
    );

    await _ref.read(taskNotifierProvider).updateTask(updated);

    // Record recovery event
    final eventRepo = _ref.read(productivityEventRepositoryProvider);
    await eventRepo.recordEvent(ProductivityEventModel(
      eventType: ProductivityEventType.taskRecovered,
      entityType: 'task',
      entityId: updated.id,
      metadata: {
        'title': updated.title,
        'rescheduledTo': '$targetHour:00',
        'targetDate': targetDate.toIso8601String(),
        'source': 'insights_engine',
      },
    ));

    final timeStr = targetHour > 12 ? '${targetHour - 12}:00 PM' : '$targetHour:00 AM';
    final dayStr = targetDate.day == now.day ? 'today' : 'tomorrow';

    _invalidateInsights();

    return InsightActionResult(
      success: true,
      message: 'Moved "${updated.title}" to $timeStr $dayStr.',
    );
  }

  Future<InsightActionResult> _handleScheduleFocusBlock(AnalyticsInsight insight) async {
    final data = insight.actionData ?? {};
    final startHour = (data['startHour'] as int?) ?? 9;
    final endHour = (data['endHour'] as int?) ?? 11;
    final label = (data['label'] as String?) ?? 'Focus Window';

    final now = DateTime.now();
    final targetDate = now.hour >= endHour
        ? DateTime(now.year, now.month, now.day).add(const Duration(days: 1))
        : DateTime(now.year, now.month, now.day);

    final startDt = DateTime(targetDate.year, targetDate.month, targetDate.day, startHour, 0);
    final endDt = DateTime(targetDate.year, targetDate.month, targetDate.day, endHour, 0);

    final newActivity = ScheduleActivity(
      id: const Uuid().v4(),
      title: 'Deep Focus Block',
      date: targetDate,
      startTime: startDt,
      endTime: endDt,
      category: 'Focus',
      icon: '🧠',
      notes: 'Scheduled via Timora Insights Engine ($label)',
      createdAt: DateTime.now(),
    );

    await _ref.read(scheduleNotifierProvider).addActivity(newActivity);

    final timeStr = startHour > 12 ? '${startHour - 12}:00 PM' : '$startHour:00 AM';
    final dayStr = targetDate.day == now.day ? 'today' : 'tomorrow';

    _invalidateInsights();

    return InsightActionResult(
      success: true,
      message: 'Scheduled Deep Focus Block at $timeStr $dayStr.',
    );
  }

  Future<InsightActionResult> _handleStartFocusSession(AnalyticsInsight insight) async {
    final data = insight.actionData ?? {};
    final duration = (data['durationMinutes'] as int?) ?? 25;

    await _ref.read(focusTimerProvider.notifier).startSession(
      durationMinutes: duration,
      mode: FocusSessionMode.pomodoro,
    );

    _invalidateInsights();

    return InsightActionResult(
      success: true,
      message: 'Started $duration-minute focus session.',
      navigationTarget: 'focus',
    );
  }

  void _invalidateInsights() {
    try {
      _ref.invalidate(timoraInsightsProvider);
      _ref.invalidate(todayTopInsightProvider);
      _ref.invalidate(dailyReportProvider);
      _ref.invalidate(weeklyReportProvider);
      _ref.invalidate(monthlyReportProvider);
    } catch (_) {}
  }
}
