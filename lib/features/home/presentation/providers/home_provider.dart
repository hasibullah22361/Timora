import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/routine/application/routine_scheduler_service.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';

final currentTimeProvider = StateNotifierProvider<CurrentTimeNotifier, DateTime>((ref) {
  return CurrentTimeNotifier();
});

class CurrentTimeNotifier extends StateNotifier<DateTime> {
  Timer? _timer;

  CurrentTimeNotifier({bool? startTimer}) : super(DateTime.now()) {
    final inTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final shouldStart = startTimer ?? (!inTest);
    if (shouldStart) {
      _timer = Timer.periodic(const Duration(seconds: 10), (_) {
        state = DateTime.now();
      });
    }
  }

  void refresh() {
    state = DateTime.now();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final greetingProvider = Provider<String>((ref) {
  final now = ref.watch(currentTimeProvider);
  final hour = now.hour;
  if (hour < 12) {
    return 'Good Morning,';
  } else if (hour < 17) {
    return 'Good Afternoon,';
  } else {
    return 'Good Evening,';
  }
});

final formattedDateProvider = Provider<String>((ref) {
  final now = ref.watch(currentTimeProvider);
  return DateFormat('EEEE, MMMM d').format(now);
});

final formattedTimeProvider = Provider<String>((ref) {
  final now = ref.watch(currentTimeProvider);
  return DateFormat('h:mm a').format(now);
});

final todayDateProvider = Provider<DateTime>((ref) {
  final now = ref.watch(currentTimeProvider);
  return DateTime(now.year, now.month, now.day);
});

final dailyScheduleProvider = FutureProvider<List<ScheduleActivity>>((ref) async {
  final date = ref.watch(todayDateProvider);
  final scheduler = ref.watch(routineSchedulerServiceProvider);
  await scheduler.generateScheduleForDate(date);
  final repo = ref.watch(scheduleRepositoryProvider);
  return await repo.getActivitiesForDate(date);
});

final currentActivityProvider = Provider<AsyncValue<ScheduleActivity?>>((ref) {
  final now = ref.watch(currentTimeProvider);
  final scheduleAsync = ref.watch(dailyScheduleProvider);
  
  return scheduleAsync.whenData((schedule) {
    try {
      final localNow = now.toLocal();
      return schedule.firstWhere((activity) {
        if (activity.status == ActivityStatus.completed || activity.status == ActivityStatus.skipped) {
          return false;
        }
        final start = activity.startTime.isUtc
            ? DateTime(activity.startTime.year, activity.startTime.month, activity.startTime.day,
                activity.startTime.hour, activity.startTime.minute)
            : activity.startTime;
        final end = activity.endTime.isUtc
            ? DateTime(activity.endTime.year, activity.endTime.month, activity.endTime.day,
                activity.endTime.hour, activity.endTime.minute)
            : activity.endTime;
        return (localNow.isAfter(start) || localNow.isAtSameMomentAs(start)) &&
            localNow.isBefore(end);
      });
    } catch (_) {
      return null;
    }
  });
});

final nextActivityProvider = Provider<AsyncValue<ScheduleActivity?>>((ref) {
  final now = ref.watch(currentTimeProvider);
  final scheduleAsync = ref.watch(dailyScheduleProvider);
  
  return scheduleAsync.whenData((schedule) {
    try {
      final localNow = now.toLocal();
      return schedule.firstWhere((activity) {
        if (activity.status == ActivityStatus.completed || activity.status == ActivityStatus.skipped) {
          return false;
        }
        final start = activity.startTime.isUtc
            ? DateTime(activity.startTime.year, activity.startTime.month, activity.startTime.day,
                activity.startTime.hour, activity.startTime.minute)
            : activity.startTime;
        return start.isAfter(localNow);
      });
    } catch (_) {
      return null;
    }
  });
});

/// Dynamically calculates unread/pending notification count from actual task reminders and overdue items
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final tasksAsync = ref.watch(allTasksProvider);
  return tasksAsync.when(
    data: (tasks) {
      final now = DateTime.now();
      int count = 0;
      for (final t in tasks) {
        if (t.isCompleted || t.status == TaskStatus.cancelled || t.isDeleted) {
          continue;
        }
        if (t.isOverdue) {
          count++;
        } else if (t.dueDate != null &&
            t.dueDate!.year == now.year &&
            t.dueDate!.month == now.month &&
            t.dueDate!.day == now.day) {
          count++;
        } else if (t.reminderEnabled) {
          count++;
        }
      }
      return count;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

enum RecommendationType {
  currentActivity,
  overdueTask,
  upcomingActivity,
  highPriorityTask,
  freeSlotFocus,
}

class WhatShouldIDoNowItem {
  final String title;
  final String subtitle;
  final String category;
  final String priority;
  final DateTime? startTime;
  final DateTime? endTime;
  final Duration duration;
  final String reason;
  final RecommendationType type;
  final String? entityId;
  final bool isCurrentActivity;
  final dynamic entity; // ScheduleActivity or TaskModel

  WhatShouldIDoNowItem({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.priority,
    this.startTime,
    this.endTime,
    required this.duration,
    required this.reason,
    required this.type,
    this.entityId,
    this.isCurrentActivity = false,
    this.entity,
  });
}

final whatShouldIDoNowProvider = Provider<AsyncValue<WhatShouldIDoNowItem>>((ref) {
  final currentActAsync = ref.watch(currentActivityProvider);
  final nextActAsync = ref.watch(nextActivityProvider);
  final allTasksAsync = ref.watch(allTasksProvider);
  final overdueTasksAsync = ref.watch(overdueTasksProvider);
  final now = ref.watch(currentTimeProvider);

  // 1. If an activity is currently running, it is what to do right now
  final current = currentActAsync.valueOrNull;
  if (current != null) {
    final dur = current.endTime.difference(current.startTime);
    final remaining = current.endTime.difference(now);
    return AsyncValue.data(
      WhatShouldIDoNowItem(
        title: current.title,
        subtitle: current.description.isNotEmpty ? current.description : 'In Progress',
        category: current.category,
        priority: 'High',
        startTime: current.startTime,
        endTime: current.endTime,
        duration: remaining > Duration.zero ? remaining : dur,
        reason: 'Currently scheduled on your calendar',
        type: RecommendationType.currentActivity,
        entityId: current.id,
        isCurrentActivity: true,
        entity: current,
      ),
    );
  }

  // 2. If an overdue task exists, prioritize clearing it
  final overdue = overdueTasksAsync.valueOrNull;
  if (overdue != null && overdue.isNotEmpty) {
    final topOverdue = overdue.first;
    return AsyncValue.data(
      WhatShouldIDoNowItem(
        title: topOverdue.title,
        subtitle: topOverdue.description.isNotEmpty ? topOverdue.description : 'Overdue Task',
        category: topOverdue.category,
        priority: topOverdue.priority.name.toUpperCase(),
        duration: Duration(minutes: (topOverdue.estimatedDurationMinutes ?? 30)),
        reason: 'Your deadline has passed. Clear this task to regain momentum.',
        type: RecommendationType.overdueTask,
        entityId: topOverdue.id,
        isCurrentActivity: false,
        entity: topOverdue,
      ),
    );
  }

  // 3. If an activity is upcoming within the next 45 minutes, recommend preparing for it
  final next = nextActAsync.valueOrNull;
  if (next != null) {
    final minsUntil = next.startTime.difference(now).inMinutes;
    if (minsUntil >= 0 && minsUntil <= 45) {
      return AsyncValue.data(
        WhatShouldIDoNowItem(
          title: next.title,
          subtitle: 'Starts in $minsUntil min (${next.startTime.hour % 12 == 0 ? 12 : next.startTime.hour % 12}:${next.startTime.minute.toString().padLeft(2, '0')})',
          category: next.category,
          priority: 'High',
          startTime: next.startTime,
          endTime: next.endTime,
          duration: next.endTime.difference(next.startTime),
          reason: 'Your next scheduled commitment begins shortly.',
          type: RecommendationType.upcomingActivity,
          entityId: next.id,
          isCurrentActivity: false,
          entity: next,
        ),
      );
    }
  }

  // 4. If any uncompleted high-priority tasks exist today, recommend them
  final allTasks = allTasksAsync.valueOrNull;
  if (allTasks != null) {
    final pendingHigh = allTasks.where((t) => !t.isCompleted && !t.isDeleted && t.priority == TaskPriority.high).toList();
    if (pendingHigh.isNotEmpty) {
      final top = pendingHigh.first;
      return AsyncValue.data(
        WhatShouldIDoNowItem(
          title: top.title,
          subtitle: top.category,
          category: top.category,
          priority: 'HIGH',
          duration: Duration(minutes: (top.estimatedDurationMinutes ?? 30)),
          reason: 'High priority goal. This free window is an ideal opportunity.',
          type: RecommendationType.highPriorityTask,
          entityId: top.id,
          isCurrentActivity: false,
          entity: top,
        ),
      );
    }
  }

  // 5. General free-slot focus
  return AsyncValue.data(
    WhatShouldIDoNowItem(
      title: 'Free Focus Window',
      subtitle: 'No scheduled activity right now',
      category: 'Productivity',
      priority: 'Flexible',
      duration: const Duration(minutes: 25),
      reason: 'Use this open window for deep work, planning, or a quick recharge.',
      type: RecommendationType.freeSlotFocus,
      isCurrentActivity: false,
    ),
  );
});
