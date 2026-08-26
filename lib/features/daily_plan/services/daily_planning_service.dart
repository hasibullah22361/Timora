import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/daily_plan_model.dart';
import '../data/models/planned_task_block_model.dart';
import '../data/models/timeline_item.dart';
import '../presentation/providers/daily_plan_provider.dart';
import '../../tasks/presentation/providers/task_provider.dart';

final dailyPlanningServiceProvider = Provider<DailyPlanningService>((ref) {
  return DailyPlanningService(ref);
});

class DailyPlanningService {
  final Ref _ref;

  DailyPlanningService(this._ref);

  Future<List<PlannedTaskBlockModel>> autoPlan(DateTime date, DailyPlanModel plan) async {
    // 1. Get all incomplete tasks
    final allTasks = await _ref.read(allTasksProvider.future);
    final incompleteTasks = allTasks.where((t) => !t.isCompleted).toList();
    
    // 2. Sort by priority (Overdue/Due Today -> Priority)
    // Simple heuristic for now: sort by Priority enum
    incompleteTasks.sort((a, b) {
      if (a.priority != b.priority) {
        // High priority first (Priority is an enum, assuming higher index is higher priority, wait TaskPriority.urgent is 4)
        return b.priority.index.compareTo(a.priority.index);
      }
      return 0; // fallback to arbitrary
    });
    
    // 3. Find available slots
    final items = await _ref.read(timelineProvider(date).future);
    final busyBlocks = items.where((i) => i.type == TimelineItemType.routine || i.type == TimelineItemType.schedule).toList();
    
    final availableSlots = _calculateAvailableSlots(busyBlocks);
    
    // 4. Fill slots with tasks
    final suggestedBlocks = <PlannedTaskBlockModel>[];
    
    for (var task in incompleteTasks) {
      if (availableSlots.isEmpty) break;
      
      int neededMinutes = task.estimatedDurationMinutes ?? 30; // default 30 min
      
      for (int i = 0; i < availableSlots.length; i++) {
        final slot = availableSlots[i];
        final slotMinutes = (slot.end.hour * 60 + slot.end.minute) - (slot.start.hour * 60 + slot.start.minute);
        
        if (slotMinutes >= neededMinutes) {
          // Fits perfectly or with room to spare
          final endHour = slot.start.hour + (slot.start.minute + neededMinutes) ~/ 60;
          final endMinute = (slot.start.minute + neededMinutes) % 60;
          
          suggestedBlocks.add(PlannedTaskBlockModel(
            id: const Uuid().v4(),
            dailyPlanId: plan.id,
            taskId: task.id,
            startTime: slot.start,
            endTime: TimeOfDay(hour: endHour, minute: endMinute),
            estimatedDurationSeconds: neededMinutes * 60,
            createdAt: DateTime.now(),
          ));
          
          // Shrink slot
          final newStartHour = slot.start.hour + (slot.start.minute + neededMinutes + 15) ~/ 60; // 15 min buffer
          final newStartMinute = (slot.start.minute + neededMinutes + 15) % 60;
          availableSlots[i] = _TimeSlot(
            start: TimeOfDay(hour: newStartHour, minute: newStartMinute),
            end: slot.end,
          );
          
          break; // move to next task
        }
      }
    }
    
    return suggestedBlocks;
  }
  
  List<_TimeSlot> _calculateAvailableSlots(List<TimelineItem> busyBlocks) {
    // Start with one big slot for the waking day (e.g., 08:00 to 22:00)
    List<_TimeSlot> slots = [
      _TimeSlot(start: const TimeOfDay(hour: 8, minute: 0), end: const TimeOfDay(hour: 22, minute: 0))
    ];
    
    for (var busy in busyBlocks) {
      final busyStartMins = busy.startTime.hour * 60 + busy.startTime.minute;
      final busyEndMins = busy.endTime.hour * 60 + busy.endTime.minute;
      
      List<_TimeSlot> newSlots = [];
      for (var slot in slots) {
        final slotStartMins = slot.start.hour * 60 + slot.start.minute;
        final slotEndMins = slot.end.hour * 60 + slot.end.minute;
        
        if (busyEndMins <= slotStartMins || busyStartMins >= slotEndMins) {
          // No overlap
          newSlots.add(slot);
        } else {
          // Overlap, split slot
          if (busyStartMins > slotStartMins) {
            newSlots.add(_TimeSlot(
              start: slot.start,
              end: busy.startTime,
            ));
          }
          if (busyEndMins < slotEndMins) {
            newSlots.add(_TimeSlot(
              start: busy.endTime,
              end: slot.end,
            ));
          }
        }
      }
      slots = newSlots;
    }
    
    // Filter out tiny slots (< 15 mins)
    return slots.where((s) {
      final startMins = s.start.hour * 60 + s.start.minute;
      final endMins = s.end.hour * 60 + s.end.minute;
      return (endMins - startMins) >= 15;
    }).toList();
  }
}

class _TimeSlot {
  final TimeOfDay start;
  final TimeOfDay end;
  _TimeSlot({required this.start, required this.end});
}
