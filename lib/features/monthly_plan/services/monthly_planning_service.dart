import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../daily_plan/presentation/providers/daily_plan_provider.dart';
import '../../daily_plan/data/models/planned_task_block_model.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../tasks/data/models/task_model.dart';

final monthlyPlanningServiceProvider = Provider<MonthlyPlanningService>((ref) {
  return MonthlyPlanningService(ref);
});

class MonthlyPlanningService {
  final Ref _ref;

  MonthlyPlanningService(this._ref);

  Future<Map<DateTime, List<PlannedTaskBlockModel>>> autoPlanMonth(DateTime monthDate) async {
    final suggestions = <DateTime, List<PlannedTaskBlockModel>>{};
    
    // Roughly 4.3 weeks per month, assuming ~120 hours max capacity per month (with 20% buffer included)
    const int maxMonthlySeconds = 120 * 3600; 
    int scheduledSeconds = 0;

    final allTasks = await _ref.read(allTasksProvider.future);
    final incompleteTasks = allTasks.where((t) => !t.isCompleted).toList();
    
    // Priorities
    incompleteTasks.sort((a, b) {
      final now = DateTime.now();
      final aOverdue = a.dueDate != null && a.dueDate!.isBefore(now);
      final bOverdue = b.dueDate != null && b.dueDate!.isBefore(now);
      if (aOverdue && !bOverdue) return -1;
      if (!aOverdue && bOverdue) return 1;
      return b.priority.index.compareTo(a.priority.index);
    });

    final taskQueue = List<TaskModel>.from(incompleteTasks);
    
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    
    // Distribute long tasks by splitting them.
    // For this proof-of-concept, we'll iterate through tasks. If a task is > 4 hours, we split it into 3-hour blocks
    // and place them in subsequent weeks.
    
    int currentDayIndex = 1;
    
    for (var task in taskQueue) {
      if (scheduledSeconds >= maxMonthlySeconds) break;
      
      int neededSeconds = (task.estimatedDurationMinutes ?? 30) * 60;
      
      if (neededSeconds > 4 * 3600) {
        // Splitting logic
        int remainingSecondsForTask = neededSeconds;
        int weekOffset = 0;
        
        while (remainingSecondsForTask > 0 && scheduledSeconds < maxMonthlySeconds) {
          int chunk = (remainingSecondsForTask > 3 * 3600) ? 3 * 3600 : remainingSecondsForTask;
          
          // Place chunk at least a few days apart
          int targetDay = currentDayIndex + (weekOffset * 7);
          if (targetDay > daysInMonth) break;
          
          final date = DateTime(monthDate.year, monthDate.month, targetDay);
          final plan = await _ref.read(dailyPlanProvider(date).future);
          
          final block = PlannedTaskBlockModel(
            id: 'temp_${task.id}_chunk$weekOffset',
            dailyPlanId: plan.id,
            taskId: task.id,
            startTime: const TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 9 + (chunk ~/ 3600), minute: 0),
            estimatedDurationSeconds: chunk,
            createdAt: DateTime.now(),
          );
          
          suggestions.putIfAbsent(date, () => []).add(block);
          
          scheduledSeconds += chunk;
          remainingSecondsForTask -= chunk;
          weekOffset++;
        }
      } else {
        // Normal scheduling, just find next day with room
        final date = DateTime(monthDate.year, monthDate.month, currentDayIndex);
        final plan = await _ref.read(dailyPlanProvider(date).future);
        
        final block = PlannedTaskBlockModel(
          id: 'temp_${task.id}',
          dailyPlanId: plan.id,
          taskId: task.id,
          startTime: const TimeOfDay(hour: 14, minute: 0), // arbitrary afternoon
          endTime: TimeOfDay(hour: 14 + (neededSeconds ~/ 3600), minute: (neededSeconds % 3600) ~/ 60),
          estimatedDurationSeconds: neededSeconds,
          createdAt: DateTime.now(),
        );
        
        suggestions.putIfAbsent(date, () => []).add(block);
        scheduledSeconds += neededSeconds;
      }
      
      currentDayIndex++;
      if (currentDayIndex > daysInMonth) currentDayIndex = 1; // loop around if we hit end of month
    }

    return suggestions;
  }
}
