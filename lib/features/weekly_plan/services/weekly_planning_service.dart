import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../daily_plan/presentation/providers/daily_plan_provider.dart';
import '../../daily_plan/data/models/planned_task_block_model.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../tasks/data/models/task_model.dart';

final weeklyPlanningServiceProvider = Provider<WeeklyPlanningService>((ref) {
  return WeeklyPlanningService(ref);
});

class WeeklyPlanningService {
  final Ref _ref;

  WeeklyPlanningService(this._ref);

  Future<Map<DateTime, List<PlannedTaskBlockModel>>> autoPlanWeek(DateTime startOfWeek) async {
    final suggestions = <DateTime, List<PlannedTaskBlockModel>>{};
    
    // Total weekly capacity (e.g., 32 hours ~ 115,200 seconds max across the week)
    const int maxWeeklySeconds = 32 * 3600; 
    int scheduledSeconds = 0;

    // Get all incomplete tasks sorted by priority
    final allTasks = await _ref.read(allTasksProvider.future);
    final incompleteTasks = allTasks.where((t) => !t.isCompleted).toList();
    
    incompleteTasks.sort((a, b) {
      // Overdue first (if due date < now)
      final now = DateTime.now();
      final aOverdue = a.dueDate != null && a.dueDate!.isBefore(now);
      final bOverdue = b.dueDate != null && b.dueDate!.isBefore(now);
      if (aOverdue && !bOverdue) return -1;
      if (!aOverdue && bOverdue) return 1;

      // Then Priority
      return b.priority.index.compareTo(a.priority.index);
    });

    final taskQueue = List<TaskModel>.from(incompleteTasks);

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      
      // Stop scheduling if we hit our weekly buffer threshold
      if (scheduledSeconds >= maxWeeklySeconds) break;
      
      final plan = await _ref.read(dailyPlanProvider(date).future);
      
      // Assuming a simplistic slot generation here to keep code clean and self-contained
      // For a real app, I would extract _calculateAvailableSlots from DailyPlanningService 
      // into a public helper. For now, we approximate 4 hours per day (14400 seconds) capacity for this test
      
      const dailyMaxSeconds = 14400; // 4 hours
      int dailyScheduled = 0;
      final dailyBlocks = <PlannedTaskBlockModel>[];

      final tasksToSchedule = List<TaskModel>.from(taskQueue);
      for (var task in tasksToSchedule) {
        if (dailyScheduled >= dailyMaxSeconds) break;
        if (scheduledSeconds >= maxWeeklySeconds) break;

        int neededSeconds = (task.estimatedDurationMinutes ?? 30) * 60;
        
        // Very simplified block creation
        dailyBlocks.add(PlannedTaskBlockModel(
          id: 'temp_${task.id}_${date.day}',
          dailyPlanId: plan.id,
          taskId: task.id,
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 10, minute: 0),
          estimatedDurationSeconds: neededSeconds,
          createdAt: DateTime.now(),
        ));
        
        dailyScheduled += neededSeconds;
        scheduledSeconds += neededSeconds;
        taskQueue.remove(task); // Remove from queue since it's scheduled
      }
      
      if (dailyBlocks.isNotEmpty) {
        suggestions[date] = dailyBlocks;
      }
    }

    return suggestions;
  }
}
