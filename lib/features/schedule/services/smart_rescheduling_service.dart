import '../data/models/schedule_activity.dart';

class ScheduleConflict {
  final ScheduleActivity firstActivity;
  final ScheduleActivity secondActivity;
  final Duration overlapDuration;

  ScheduleConflict({
    required this.firstActivity,
    required this.secondActivity,
    required this.overlapDuration,
  });

  String get conflictDescription =>
      '"${firstActivity.title}" overlaps with "${secondActivity.title}" for ${overlapDuration.inMinutes} mins';
}

class SmartReschedulingService {
  /// Detects all time overlaps for a given day's list of activities
  static List<ScheduleConflict> detectConflicts(List<ScheduleActivity> activities) {
    final active = activities
        .where((a) => a.status != ActivityStatus.skipped && a.status != ActivityStatus.completed)
        .toList();

    // Sort by startTime
    active.sort((a, b) => a.startTime.compareTo(b.startTime));

    final conflicts = <ScheduleConflict>[];

    for (int i = 0; i < active.length; i++) {
      for (int j = i + 1; j < active.length; j++) {
        final a = active[i];
        final b = active[j];

        // Since sorted by start time, if b.startTime >= a.endTime, no further overlap with a
        if (b.startTime.isAfter(a.endTime) || b.startTime.isAtSameMomentAs(a.endTime)) {
          break;
        }

        // Overlap detected
        final overlapStart = a.startTime.isAfter(b.startTime) ? a.startTime : b.startTime;
        final overlapEnd = a.endTime.isBefore(b.endTime) ? a.endTime : b.endTime;
        final overlapDuration = overlapEnd.difference(overlapStart);

        if (overlapDuration > Duration.zero) {
          conflicts.add(
            ScheduleConflict(
              firstActivity: a,
              secondActivity: b,
              overlapDuration: overlapDuration,
            ),
          );
        }
      }
    }

    return conflicts;
  }

  /// Proposes a non-overlapping adjusted schedule by pushing conflicting activities into open slots
  static List<ScheduleActivity> resolveConflicts(List<ScheduleActivity> activities) {
    if (activities.length <= 1) return List.from(activities);

    final sorted = List<ScheduleActivity>.from(activities)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final resolved = <ScheduleActivity>[];

    for (int i = 0; i < sorted.length; i++) {
      final current = sorted[i];
      if (resolved.isEmpty) {
        resolved.add(current);
        continue;
      }

      final prev = resolved.last;
      if (current.startTime.isBefore(prev.endTime)) {
        // Shift current activity immediately following previous activity
        final duration = current.endTime.difference(current.startTime);
        final newStart = prev.endTime;
        final newEnd = newStart.add(duration);

        resolved.add(
          current.copyWith(
            startTime: newStart,
            endTime: newEnd,
            isOverridden: true,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        resolved.add(current);
      }
    }

    return resolved;
  }

  /// Calculates the next due date for recurring task logic
  static DateTime calculateNextRecurringDate({
    required DateTime currentDate,
    required String recurrence,
    List<int> daysOfWeek = const [],
  }) {
    final lower = recurrence.toLowerCase();

    if (lower == 'daily' || lower == 'every day') {
      return currentDate.add(const Duration(days: 1));
    }

    if (lower == 'weekly' || lower == 'every week') {
      if (daysOfWeek.isNotEmpty) {
        // Find next designated day of week
        for (int i = 1; i <= 7; i++) {
          final candidate = currentDate.add(Duration(days: i));
          if (daysOfWeek.contains(candidate.weekday)) {
            return candidate;
          }
        }
      }
      return currentDate.add(const Duration(days: 7));
    }

    if (lower == 'monthly' || lower == 'every month') {
      return DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
    }

    // Default fallback: 1 day
    return currentDate.add(const Duration(days: 1));
  }
}
