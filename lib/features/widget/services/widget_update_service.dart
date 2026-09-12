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
import '../../goals/data/models/goal_model.dart';
import '../../goals/data/models/milestone_model.dart';
import '../../goals/data/repositories/goal_repository.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/models/widget_data.dart';

final widgetUpdateServiceProvider = Provider<WidgetUpdateService>((ref) {
  final taskRepo = ref.watch(taskRepositoryProvider);
  final scheduleRepo = ref.watch(scheduleRepositoryProvider);
  final focusRepo = ref.watch(focusRepositoryProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);
  return WidgetUpdateService(
    taskRepo,
    scheduleRepo,
    focusRepo,
    goalRepo: goalRepo,
    ref: ref,
  );
});

class WidgetUpdateService {
  static const MethodChannel _channel = MethodChannel('timora/widget');

  final TaskRepository _taskRepo;
  final ScheduleRepository _scheduleRepo;
  final FocusRepository _focusRepo;
  final GoalRepository? _goalRepo;
  final Ref? _ref;

  WidgetUpdateService(
    this._taskRepo,
    this._scheduleRepo,
    this._focusRepo, {
    GoalRepository? goalRepo,
    Ref? ref,
  })  : _goalRepo = goalRepo,
        _ref = ref;

  /// Aggregates all current Timora data, generates a compact [WidgetData]
  /// payload, and pushes it to native Android widgets.
  Future<void> updateWidgets() async {
    // Only Android supports native home screen AppWidgets
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final timeFormatter = DateFormat.jm();

      // 1. Fetch Today's Tasks
      final allTasks = await _taskRepo.getTasks();
      final todayTasks = allTasks.where((t) {
        if (t.isDeleted || t.status == TaskStatus.cancelled) return false;
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

      // Prepare compact tasks list for widget (up to 3 items, pending first)
      final sortedTasks = List<TaskModel>.from(
        todayTasks.isNotEmpty
            ? todayTasks
            : allTasks.where((t) => !t.isDeleted && t.status != TaskStatus.cancelled),
      )..sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return 0;
        });

      final widgetTasks = sortedTasks.take(3).map((t) => WidgetTaskItem(
        id: t.id,
        title: t.title,
        isCompleted: t.isCompleted,
      )).toList();

      // 2. Fetch Today's Schedule Activities
      final activities = await _scheduleRepo.getActivitiesForDate(today);

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

      ScheduleActivity? currentAct;
      ScheduleActivity? nextAct;

      for (var a in activities) {
        if (a.status == ActivityStatus.completed) continue;
        if (currentAct == null &&
            now.isAfter(a.startTime) &&
            now.isBefore(a.endTime)) {
          currentAct = a;
        } else if (now.isBefore(a.startTime)) {
          if (nextAct == null || a.startTime.isBefore(nextAct.startTime)) {
            nextAct = a;
          }
        }
      }

      String? currentActivityTitle;
      String? currentActivityTime;
      bool isActivityRunning = false;

      if (currentAct != null) {
        currentTaskId = currentAct.id;
        currentTaskTitle = currentAct.title;
        currentTaskTime = '${timeFormatter.format(currentAct.startTime)} – ${timeFormatter.format(currentAct.endTime)}';

        final emoji = _getCategoryEmoji(currentAct.category);
        currentActivityTitle = '$emoji ${currentAct.title}'.trim();
        currentActivityTime = currentTaskTime;
        isActivityRunning = true;
      } else if (nextAct != null) {
        nextTaskId = nextAct.id;
        nextTaskTitle = nextAct.title;
        nextTaskTime = timeFormatter.format(nextAct.startTime);

        final emoji = _getCategoryEmoji(nextAct.category);
        currentActivityTitle = '$emoji ${nextAct.title}'.trim();
        currentActivityTime = 'Starts at ${timeFormatter.format(nextAct.startTime)}';
        isActivityRunning = false;
      } else if (sortedTasks.isNotEmpty) {
        // Fallback to top task if schedule is empty
        final firstTask = sortedTasks.first;
        currentTaskId = firstTask.id;
        currentTaskTitle = firstTask.title;
        currentTaskTime = firstTask.dueTime != null
            ? '${_formatTimeOfDay(firstTask.dueTime!)} • Due Today'
            : 'Priority: ${firstTask.priority.name.toUpperCase()}';

        currentActivityTitle = '📝 ${firstTask.title}';
        currentActivityTime = currentTaskTime;
        isActivityRunning = false;
      }

      // 5. Query Goals (up to 2 important/active goals with real progress)
      final widgetGoals = <WidgetGoalItem>[];
      final goalRepo = _goalRepo;
      if (goalRepo != null) {
        try {
          final goals = await goalRepo.getGoals();
          final activeGoals = goals.where((g) => g.status == GoalStatus.active).toList();
          for (final g in activeGoals.take(2)) {
            int progressPercent = 0;
            if (g.progressMode == ProgressMode.manual) {
              progressPercent = (g.manualProgress * 100).round().clamp(0, 100);
            } else {
              final milestones = await goalRepo.getMilestonesForGoal(g.id);
              if (milestones.isNotEmpty) {
                final completed = milestones.where((m) => m.status == MilestoneStatus.completed).length;
                progressPercent = ((completed / milestones.length) * 100).round().clamp(0, 100);
              } else {
                progressPercent = (g.manualProgress * 100).round().clamp(0, 100);
              }
            }
            widgetGoals.add(WidgetGoalItem(
              id: g.id,
              title: g.title,
              progressPercentage: progressPercent,
            ));
          }
        } catch (e) {
          debugPrint('[TimoraWidget] Error fetching goals for widget: $e');
        }
      }

      // 6. Query Unread Notifications Count
      int unreadNotificationsCount = 0;
      final ref = _ref;
      if (ref != null) {
        try {
          unreadNotificationsCount = ref.read(unreadNotificationsCountProvider);
        } catch (_) {}
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
        unreadNotificationsCount: unreadNotificationsCount,
        currentActivityTitle: currentActivityTitle,
        currentActivityTime: currentActivityTime,
        isActivityRunning: isActivityRunning,
        tasks: widgetTasks,
        goals: widgetGoals,
        lastUpdatedMillis: now.millisecondsSinceEpoch,
      );

      final jsonStr = widgetData.serialize();

      // Send to native Android layer
      await _channel.invokeMethod('updateWidgetData', {'data': jsonStr});
      debugPrint('[TimoraWidget] Successfully updated Android widgets (unread: $unreadNotificationsCount, tasks: ${widgetTasks.length}, goals: ${widgetGoals.length})');
    } catch (e) {
      debugPrint('[TimoraWidget] Error updating widgets: $e');
    }
  }

  String _getCategoryEmoji(String? category) {
    if (category == null) return '📚';
    final lower = category.toLowerCase();
    if (lower.contains('study') || lower.contains('learn') || lower.contains('ai') || lower.contains('read') || lower.contains('book')) return '📚';
    if (lower.contains('work') || lower.contains('project') || lower.contains('code') || lower.contains('dev') || lower.contains('tech')) return '💼';
    if (lower.contains('health') || lower.contains('gym') || lower.contains('sport') || lower.contains('fitness') || lower.contains('run')) return '🏃';
    if (lower.contains('food') || lower.contains('eat') || lower.contains('meal') || lower.contains('lunch') || lower.contains('dinner')) return '🍎';
    if (lower.contains('rest') || lower.contains('sleep') || lower.contains('break')) return '☕';
    if (lower.contains('pray') || lower.contains('meditat')) return '✨';
    return '🎯';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
