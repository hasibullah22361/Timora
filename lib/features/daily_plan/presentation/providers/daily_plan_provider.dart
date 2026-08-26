import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:timora/features/daily_plan/data/models/daily_plan_model.dart';
import 'package:timora/features/daily_plan/data/models/planned_task_block_model.dart';
import 'package:timora/features/daily_plan/data/models/timeline_item.dart';
import 'package:timora/features/daily_plan/data/repositories/daily_plan_repository.dart';
import 'package:timora/features/routine/presentation/providers/routine_provider.dart';
import 'package:timora/features/schedule/presentation/providers/schedule_provider.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final dailyPlanProvider = FutureProvider.family<DailyPlanModel, DateTime>((ref, date) async {
  final repo = ref.watch(dailyPlanRepositoryProvider);
  var plan = await repo.getPlanForDate(date);
  
  if (plan == null) {
    plan = DailyPlanModel(
      id: const Uuid().v4(),
      date: date,
      createdAt: DateTime.now(),
    );
    await repo.savePlan(plan);
  }
  return plan;
});

final plannedBlocksProvider = FutureProvider.family<List<PlannedTaskBlockModel>, String>((ref, planId) async {
  final repo = ref.watch(dailyPlanRepositoryProvider);
  return repo.getBlocksForDate(planId);
});

final timelineProvider = FutureProvider.family<List<TimelineItem>, DateTime>((ref, date) async {
  final items = <TimelineItem>[];
  
  // 1. Fetch Routine Blocks (assuming active routine)
  final routineAsync = await ref.watch(activeRoutineProvider.future);
  if (routineAsync != null) {
    final blocks = await ref.watch(routineBlocksProvider(routineAsync.id).future);
    for (var b in blocks) {
      if (b.enabled) {
        items.add(TimelineItem(
          id: 'routine_${b.id}',
          sourceId: b.id,
          type: TimelineItemType.routine,
          title: b.title,
          subtitle: 'Fixed routine',
          startTime: b.startTime,
          endTime: b.endTime,
          color: b.color,
          icon: b.icon,
        ));
      }
    }
  }

  // 2. Fetch Schedule Activities for the date
  final scheduleActivities = await ref.watch(scheduleActivitiesByDateProvider(date).future);
  for (var a in scheduleActivities) {
    items.add(TimelineItem(
      id: 'schedule_${a.id}',
      sourceId: a.id,
      type: TimelineItemType.schedule,
      title: a.title,
      subtitle: 'Scheduled activity',
      startTime: TimeOfDay.fromDateTime(a.startTime),
      endTime: TimeOfDay.fromDateTime(a.endTime),
      color: a.color,
      icon: a.icon,
    ));
  }
  
  // 3. Fetch Planned Task Blocks
  final plan = await ref.watch(dailyPlanProvider(date).future);
  final blocks = await ref.watch(plannedBlocksProvider(plan.id).future);
  final tasks = await ref.watch(allTasksProvider.future);
  
  for (var b in blocks) {
    final task = tasks.where((t) => t.id == b.taskId).firstOrNull;
    final taskTitle = task?.title ?? 'Planned Task';
    final isCompleted = b.status == PlannedBlockStatus.completed || (task?.isCompleted ?? false);
    items.add(TimelineItem(
      id: 'block_${b.id}',
      sourceId: b.id,
      type: TimelineItemType.block,
      title: taskTitle,
      subtitle: 'Planned task',
      startTime: b.startTime,
      endTime: b.endTime,
      color: Colors.blue,
      icon: '📝',
      isCompleted: isCompleted,
    ));
  }
  
  // Sort chronologically
  items.sort((a, b) {
    final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
    final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
    return aMinutes.compareTo(bMinutes);
  });
  
  return items;
});

class DailyPlanNotifier extends StateNotifier<AsyncValue<void>> {
  final DailyPlanRepository _repo;
  final Ref _ref;

  DailyPlanNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> addPlannedBlock(PlannedTaskBlockModel block, DateTime date) async {
    await _repo.saveBlock(block);
    final plan = await _repo.getPlanForDate(date);
    if (plan != null) {
      _ref.invalidate(plannedBlocksProvider(plan.id));
      _ref.invalidate(timelineProvider(date));
    }
  }

  Future<void> deletePlannedBlock(String blockId, DateTime date) async {
    await _repo.deleteBlock(blockId);
    final plan = await _repo.getPlanForDate(date);
    if (plan != null) {
      _ref.invalidate(plannedBlocksProvider(plan.id));
      _ref.invalidate(timelineProvider(date));
    }
  }
}

final dailyPlanNotifierProvider = Provider<DailyPlanNotifier>((ref) {
  return DailyPlanNotifier(ref.watch(dailyPlanRepositoryProvider), ref);
});
