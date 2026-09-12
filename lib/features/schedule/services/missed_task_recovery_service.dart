import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../data/models/schedule_activity.dart';
import '../data/repositories/schedule_repository.dart';
import '../presentation/providers/schedule_provider.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../../analytics/services/productivity_event_service.dart';

class RecoveryRecommendation {
  final ScheduleActivity? activity;
  final TaskModel? task;
  final String title;
  final DateTime originalStart;
  final DateTime originalEnd;
  final DateTime proposedStart;
  final DateTime proposedEnd;
  final Duration duration;
  final String reason;

  RecoveryRecommendation({
    this.activity,
    this.task,
    required this.title,
    required this.originalStart,
    required this.originalEnd,
    required this.proposedStart,
    required this.proposedEnd,
    required this.duration,
    required this.reason,
  });
}

final missedTaskRecoveryServiceProvider = Provider<MissedTaskRecoveryService>((ref) {
  return MissedTaskRecoveryService(ref);
});

final missedActivitiesProvider = FutureProvider<List<ScheduleActivity>>((ref) async {
  final service = ref.read(missedTaskRecoveryServiceProvider);
  return service.getMissedActivitiesForToday();
});

final recoveryRecommendationsProvider = FutureProvider<List<RecoveryRecommendation>>((ref) async {
  final service = ref.read(missedTaskRecoveryServiceProvider);
  return service.generateRecoveryRecommendations();
});

class MissedTaskRecoveryService {
  final Ref _ref;

  MissedTaskRecoveryService(this._ref);

  /// Retrieves the set of entity IDs (activities or tasks) that have been skipped today
  Future<Set<String>> getSkippedIdsToday() async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences? prefs;
    try {
      prefs = _ref.read(sharedPreferencesProvider);
    } catch (_) {}
    prefs ??= await SharedPreferences.getInstance();

    final list = prefs.getStringList('timora_autopilot_skipped_ids') ?? [];
    final prefix = '${dateStr}_';
    final result = <String>{};
    for (final item in list) {
      if (item.startsWith(prefix)) {
        result.add(item.substring(prefix.length));
      }
    }
    return result;
  }

  /// Skips a missed recommendation so it does not keep prompting for recovery.
  /// Does NOT complete or delete tasks.
  Future<void> skipMissedItem(RecoveryRecommendation rec) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final entityId = rec.activity?.id ?? rec.task?.id;

    if (entityId != null) {
      SharedPreferences? prefs;
      try {
        prefs = _ref.read(sharedPreferencesProvider);
      } catch (_) {}
      prefs ??= await SharedPreferences.getInstance();

      final list = prefs.getStringList('timora_autopilot_skipped_ids') ?? [];
      final key = '${dateStr}_$entityId';
      if (!list.contains(key)) {
        final updated = List<String>.from(list)..add(key);
        await prefs.setStringList('timora_autopilot_skipped_ids', updated);
      }
    }

    if (rec.activity != null) {
      try {
        final scheduleNotifier = _ref.read(scheduleNotifierProvider);
        await scheduleNotifier.markSkipped(rec.activity!);
      } catch (_) {}
    }

    Future.microtask(() {
      try {
        _ref.invalidate(missedActivitiesProvider);
        _ref.invalidate(recoveryRecommendationsProvider);
        _ref.invalidate(dailyScheduleProvider);
        _ref.invalidate(scheduleActivitiesProvider);
        _ref.invalidate(todayTasksProvider);
        _ref.invalidate(allTasksProvider);
      } catch (_) {}
    });
  }

  /// Detects scheduled activities today whose end time has passed and are not completed or skipped
  Future<List<ScheduleActivity>> getMissedActivitiesForToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final repo = _ref.read(scheduleRepositoryProvider);
    final activities = await repo.getActivitiesForDate(today);
    final skippedIds = await getSkippedIdsToday();

    return activities.where((a) {
      if (a.status == ActivityStatus.completed ||
          a.status == ActivityStatus.skipped ||
          a.status == ActivityStatus.replaced) {
        return false;
      }
      if (skippedIds.contains(a.id)) {
        return false;
      }
      return a.endTime.isBefore(now);
    }).toList();
  }

  /// Detects pending tasks whose due date has passed today and have not been skipped
  Future<List<TaskModel>> getMissedTasksForToday() async {
    final now = DateTime.now();
    final skippedIds = await getSkippedIdsToday();
    try {
      final taskRepo = _ref.read(taskRepositoryProvider);
      final tasks = await taskRepo.getPendingTasks();
      return tasks.where((t) {
        if (t.isCompleted || t.isDeleted || t.status == TaskStatus.cancelled) {
          return false;
        }
        if (skippedIds.contains(t.id)) {
          return false;
        }
        if (t.dueDate == null) return false;
        return t.dueDate!.isBefore(now);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Finds the earliest conflict-free slot for a given duration between [afterTime] and [endOfDayLimit]
  Future<DateTimeRange?> findAvailableRecoverySlot({
    required Duration duration,
    DateTime? afterTime,
    int endHour = 22,
  }) async {
    final now = DateTime.now();
    DateTime candidateStart = afterTime ?? now;
    if (candidateStart.isBefore(now)) candidateStart = now;

    // Round up candidate start to next 5-minute interval + 5m buffer
    final remainder = candidateStart.minute % 5;
    final minutesToAdd = (remainder == 0 ? 5 : (5 - remainder)) + 5;
    candidateStart = candidateStart
        .add(Duration(minutes: minutesToAdd))
        .subtract(Duration(seconds: candidateStart.second, milliseconds: candidateStart.millisecond));

    final today = DateTime(now.year, now.month, now.day);
    final repo = _ref.read(scheduleRepositoryProvider);
    final allActivities = await repo.getActivitiesForDate(today);

    // Filter to active future activities
    final active = allActivities
        .where((a) =>
            a.status != ActivityStatus.completed &&
            a.status != ActivityStatus.skipped &&
            a.status != ActivityStatus.replaced)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final endOfDay = DateTime(today.year, today.month, today.day, endHour, 0);

    while (candidateStart.add(duration).isBefore(endOfDay) ||
        candidateStart.add(duration).isAtSameMomentAs(endOfDay)) {
      final candidateEnd = candidateStart.add(duration);

      // Check if candidate overlaps with any existing scheduled activity
      bool hasOverlap = false;
      for (final act in active) {
        if (candidateStart.isBefore(act.endTime) && candidateEnd.isAfter(act.startTime)) {
          hasOverlap = true;
          // Jump candidate start to end of the overlapping activity + 5 min buffer
          candidateStart = act.endTime.add(const Duration(minutes: 5));
          break;
        }
      }

      if (!hasOverlap) {
        return DateTimeRange(start: candidateStart, end: candidateEnd);
      }
    }

    return null;
  }

  /// Generates recovery recommendations for all missed activities and tasks today
  Future<List<RecoveryRecommendation>> generateRecoveryRecommendations() async {
    final missed = await getMissedActivitiesForToday();
    final missedTasks = await getMissedTasksForToday();
    final recommendations = <RecoveryRecommendation>[];

    DateTime searchStart = DateTime.now();

    for (final act in missed) {
      final dur = act.endTime.difference(act.startTime);
      final validDuration = dur > const Duration(minutes: 10) ? dur : const Duration(minutes: 30);

      final slot = await findAvailableRecoverySlot(
        duration: validDuration,
        afterTime: searchStart,
      );

      if (slot != null) {
        recommendations.add(
          RecoveryRecommendation(
            activity: act,
            title: act.title,
            originalStart: act.startTime,
            originalEnd: act.endTime,
            proposedStart: slot.start,
            proposedEnd: slot.end,
            duration: validDuration,
            reason: 'Missed at ${_formatTime(act.startTime)}. Found a free ${_formatDuration(validDuration)} slot at ${_formatTime(slot.start)}.',
          ),
        );
        searchStart = slot.end.add(const Duration(minutes: 5));
      }
    }

    for (final task in missedTasks) {
      final validDuration = Duration(minutes: task.estimatedDurationMinutes ?? 30);
      final slot = await findAvailableRecoverySlot(
        duration: validDuration,
        afterTime: searchStart,
      );

      if (slot != null) {
        recommendations.add(
          RecoveryRecommendation(
            task: task,
            title: task.title,
            originalStart: task.dueDate ?? DateTime.now(),
            originalEnd: (task.dueDate ?? DateTime.now()).add(validDuration),
            proposedStart: slot.start,
            proposedEnd: slot.end,
            duration: validDuration,
            reason: 'Deadline was ${_formatTime(task.dueDate ?? DateTime.now())}. Found a free ${_formatDuration(validDuration)} slot at ${_formatTime(slot.start)}.',
          ),
        );
        searchStart = slot.end.add(const Duration(minutes: 5));
      }
    }

    return recommendations;
  }

  /// Executes recovery by shifting activity or task to the new time slot
  Future<void> applyRecovery(RecoveryRecommendation rec) async {
    if (rec.activity != null) {
      final act = rec.activity!;
      final updated = act.copyWith(
        startTime: rec.proposedStart,
        endTime: rec.proposedEnd,
        status: ActivityStatus.upcoming,
        isOverridden: true,
        updatedAt: DateTime.now(),
      );

      final scheduleNotifier = _ref.read(scheduleNotifierProvider);
      await scheduleNotifier.updateActivity(updated);

      // Log productivity recovery event
      await _ref.read(productivityEventServiceProvider).logTaskRecovered(
            act.id,
            act.title,
            rec.proposedStart,
          );

      _ref.invalidate(missedActivitiesProvider);
      _ref.invalidate(recoveryRecommendationsProvider);
      _ref.invalidate(scheduleActivitiesProvider);
    } else if (rec.task != null) {
      final task = rec.task!;
      final updated = task.copyWith(
        dueDate: rec.proposedStart,
        updatedAt: DateTime.now(),
      );
      try {
        await _ref.read(taskRepositoryProvider).updateTask(updated);
        await _ref.read(productivityEventServiceProvider).logTaskRecovered(
              task.id,
              task.title,
              rec.proposedStart,
            );
      } catch (_) {}

      _ref.invalidate(missedActivitiesProvider);
      _ref.invalidate(recoveryRecommendationsProvider);
      _ref.invalidate(allTasksProvider);
      _ref.invalidate(todayTasksProvider);
    }
  }

  /// Skips a missed activity so it does not keep prompting for recovery
  Future<void> dismissMissed(ScheduleActivity activity) async {
    await skipMissedItem(
      RecoveryRecommendation(
        activity: activity,
        title: activity.title,
        originalStart: activity.startTime,
        originalEnd: activity.endTime,
        proposedStart: activity.startTime,
        proposedEnd: activity.endTime,
        duration: activity.endTime.difference(activity.startTime),
        reason: 'Dismissed by user',
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final mins = d.inMinutes % 60;
      return mins > 0 ? '${d.inHours}h ${mins}m' : '${d.inHours}h';
    }
    return '${d.inMinutes}m';
  }
}
