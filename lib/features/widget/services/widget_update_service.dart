import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/data/repositories/schedule_repository.dart';
import '../../focus/data/models/focus_session_model.dart';
import '../../focus/data/repositories/focus_repository.dart';
import '../data/models/widget_data.dart';

final widgetUpdateServiceProvider = Provider<WidgetUpdateService>((ref) {
  final taskRepo = ref.watch(taskRepositoryProvider);
  final scheduleRepo = ref.watch(scheduleRepositoryProvider);
  final focusRepo = ref.watch(focusRepositoryProvider);
  return WidgetUpdateService(taskRepo, scheduleRepo, focusRepo);
});

class WidgetUpdateService {
  static const MethodChannel _channel = MethodChannel('timora/widget');

  final TaskRepository _taskRepo;
  final ScheduleRepository _scheduleRepo;
  final FocusRepository _focusRepo;

  WidgetUpdateService(this._taskRepo, this._scheduleRepo, this._focusRepo);

  /// Aggregates all current Timora data, generates a compact [WidgetData]
  /// payload, and pushes it to native Android widgets.
  Future<void> updateWidgets() async {
    // Only Android supports native home screen AppWidgets
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 1. Fetch Today's Tasks
      final allTasks = await _taskRepo.getTasks();
      final todayTasks = allTasks.where((t) {
        if (t.dueDate == null) return true;
        final d = t.dueDate!;
        return d.year == today.year && d.month == today.month && d.day == today.day;
      }).toList();

      final totalTasks = todayTasks.isNotEmpty ? todayTasks.length : allTasks.length;
      final completedTasks = (todayTasks.isNotEmpty ? todayTasks : allTasks)
          .where((t) => t.status == TaskStatus.completed)
          .length;
      final progressPercentage = totalTasks > 0
          ? ((completedTasks / totalTasks) * 100).round()
          : 0;

      // 2. Fetch Today's Schedule Activities
      final activities = await _scheduleRepo.getActivitiesForDate(today);
      final timeFormatter = DateFormat.jm();

      final scheduleItems = activities.map((a) {
        final startStr = timeFormatter.format(a.startTime);
        final endStr = timeFormatter.format(a.endTime);
        return WidgetScheduleItem(
          id: a.id,
          title: a.title,
          timeStr: '$startStr – $endStr',
          startMillis: a.startTime.millisecondsSinceEpoch,
          endMillis: a.endTime.millisecondsSinceEpoch,
          isCompleted: a.status == ActivityStatus.completed,
        );
      }).toList();

      // 3. Determine Active Focus Session
      bool focusActive = false;
      String? focusTitle;
      int focusRemainingSeconds = 0;

      try {
        final session = await _focusRepo.getActiveSession();
        if (session != null &&
            (session.status == FocusSessionStatus.running ||
                session.status == FocusSessionStatus.breakTime)) {
          focusActive = true;
          focusTitle = session.notes.isNotEmpty ? session.notes : 'Focus Session';
          final elapsed = now.difference(session.startedAt).inSeconds -
              session.totalPausedDurationSeconds;
          final remaining = session.plannedDurationSeconds - elapsed;
          focusRemainingSeconds = remaining > 0 ? remaining : 0;
        }
      } catch (_) {}

      // 4. Determine Current and Next Activity / Task
      String? currentTaskId;
      String? currentTaskTitle;
      String? currentTaskTime;

      String? nextTaskId;
      String? nextTaskTitle;
      String? nextTaskTime;

      // First check schedule activities
      ScheduleActivity? currentAct;
      ScheduleActivity? nextAct;

      for (var a in activities) {
        if (currentAct == null &&
            now.isAfter(a.startTime) &&
            now.isBefore(a.endTime) &&
            a.status != ActivityStatus.completed) {
          currentAct = a;
        } else if (now.isBefore(a.startTime)) {
          nextAct ??= a;
        }
      }

      if (currentAct != null) {
        currentTaskId = currentAct.id;
        currentTaskTitle = currentAct.title;
        currentTaskTime = '${timeFormatter.format(currentAct.startTime)} – ${timeFormatter.format(currentAct.endTime)}';
      }

      if (nextAct != null) {
        nextTaskId = nextAct.id;
        nextTaskTitle = nextAct.title;
        nextTaskTime = timeFormatter.format(nextAct.startTime);
      }

      // Fallback to tasks if schedule is empty
      if (currentTaskTitle == null) {
        final pendingTasks = (todayTasks.isNotEmpty ? todayTasks : allTasks)
            .where((t) => t.status != TaskStatus.completed)
            .toList();

        if (pendingTasks.isNotEmpty) {
          final firstTask = pendingTasks.first;
          currentTaskId = firstTask.id;
          currentTaskTitle = firstTask.title;
          currentTaskTime = firstTask.dueTime != null
              ? '${_formatTimeOfDay(firstTask.dueTime!)} • Due Today'
              : 'Priority: ${firstTask.priority.name.toUpperCase()}';

          if (pendingTasks.length > 1) {
            final secondTask = pendingTasks[1];
            nextTaskId = secondTask.id;
            nextTaskTitle = secondTask.title;
            nextTaskTime = secondTask.dueTime != null
                ? _formatTimeOfDay(secondTask.dueTime!)
                : 'Upcoming Task';
          }
        }
      }

      final widgetData = WidgetData(
        currentTaskId: currentTaskId,
        currentTaskTitle: currentTaskTitle ?? 'Plan your day',
        currentTaskTime: currentTaskTime ?? 'Tap to open Timora',
        nextTaskId: nextTaskId,
        nextTaskTitle: nextTaskTitle ?? 'All clear',
        nextTaskTime: nextTaskTime ?? 'No upcoming activities',
        completedTasksCount: completedTasks,
        totalTasksCount: totalTasks,
        progressPercentage: progressPercentage,
        focusActive: focusActive,
        focusTitle: focusTitle,
        focusRemainingSeconds: focusRemainingSeconds,
        scheduleItems: scheduleItems,
        lastUpdatedMillis: now.millisecondsSinceEpoch,
      );

      final jsonStr = widgetData.serialize();

      // Send to native Android layer
      await _channel.invokeMethod('updateWidgetData', {'data': jsonStr});
      debugPrint('[TimoraWidget] Successfully updated Android widgets with data: ${widgetData.currentTaskTitle} (${widgetData.progressPercentage}%)');
    } catch (e) {
      debugPrint('[TimoraWidget] Error updating widgets: $e');
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
