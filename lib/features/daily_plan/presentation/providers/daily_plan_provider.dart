import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:timora/features/daily_plan/data/models/daily_plan_model.dart';
import 'package:timora/features/daily_plan/data/models/planned_task_block_model.dart';
import 'package:timora/features/daily_plan/data/models/timeline_item.dart';
import 'package:timora/features/daily_plan/data/repositories/daily_plan_repository.dart';
import 'package:timora/features/routine/presentation/providers/routine_provider.dart';
import 'package:timora/features/schedule/presentation/providers/schedule_provider.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import 'package:timora/features/focus/presentation/providers/focus_provider.dart';
import 'package:timora/features/focus/data/repositories/focus_repository.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final timelineProvider =
    FutureProvider.family<List<TimelineItem>, DateTime>((ref, date) async {
  final items = <TimelineItem>[];

  // Watch active focus timer state with minute-level selector to prevent re-querying all tables every second
  final activeFocus = ref.watch(focusTimerProvider.select((s) => s.activeSession));
  final activeElapsedMins = ref.watch(focusTimerProvider.select((s) => s.elapsedSeconds ~/ 60));
  final activeElapsedSecs = activeElapsedMins * 60;

  // Completed focus sessions
  final focusRepo = ref.watch(focusRepositoryProvider);
  final completedSessions = await focusRepo.getAllCompletedSessions();

  int getCompletedMinutesForSource(
      String sourceId, bool isAlreadyCompleted, int plannedMins) {
    int totalSecs = 0;
    for (final s in completedSessions) {
      if (s.scheduleActivityId == sourceId ||
          s.plannedTaskBlockId == sourceId) {
        totalSecs += s.actualDurationSeconds > 0
            ? s.actualDurationSeconds
            : s.plannedDurationSeconds;
      }
    }
    if (activeFocus != null &&
        (activeFocus.scheduleActivityId == sourceId ||
            activeFocus.plannedTaskBlockId == sourceId)) {
      totalSecs += activeElapsedSecs;
    }
    if (isAlreadyCompleted && totalSecs == 0) {
      return plannedMins;
    }
    final mins = (totalSecs / 60).round();
    return (mins >= plannedMins && plannedMins > 0) ? plannedMins : mins;
  }

  // 1. Fetch Routine Blocks
  final routineAsync = await ref.watch(activeRoutineProvider.future);
  if (routineAsync != null) {
    final blocks =
        await ref.watch(routineBlocksProvider(routineAsync.id).future);
    for (var b in blocks) {
      if (b.enabled) {
        final plannedMins = ((b.endTime.hour * 60 + b.endTime.minute) -
                (b.startTime.hour * 60 + b.startTime.minute))
            .clamp(0, 1440);
        final completedMins =
            getCompletedMinutesForSource(b.id, false, plannedMins);

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
          customPlannedMinutes: plannedMins,
          completedMinutes: completedMins,
        ));
      }
    }
  }

  // 2. Fetch Schedule Activities for the date
  final scheduleActivities =
      await ref.watch(scheduleActivitiesByDateProvider(date).future);
  for (var a in scheduleActivities) {
    if (a.status == ActivityStatus.replaced) {
      continue;
    }
    final plannedMins = (a.endTime.difference(a.startTime).inMinutes).abs();
    final isDone = a.status == ActivityStatus.completed;
    final completedMins =
        getCompletedMinutesForSource(a.id, isDone, plannedMins);

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
      isCompleted: isDone || (plannedMins > 0 && completedMins >= plannedMins),
      customPlannedMinutes: plannedMins > 0 ? plannedMins : 20,
      completedMinutes: completedMins,
    ));
  }

  // 3. Fetch Planned Task Blocks
  final repo = ref.watch(dailyPlanRepositoryProvider);
  final persistedPlan = await repo.getPlanForDate(date);
  if (persistedPlan != null) {
    final blocks = await repo.getBlocksForDate(persistedPlan.id);
    final tasks = await ref.watch(allTasksProvider.future);

    for (var b in blocks) {
      final task = tasks.where((t) => t.id == b.taskId).firstOrNull;
      final taskTitle = task?.title ?? 'Planned Task';
      final isDone = b.status == PlannedBlockStatus.completed ||
          (task?.isCompleted ?? false);
      final plannedMins = b.estimatedDurationSeconds > 0
          ? (b.estimatedDurationSeconds / 60).round()
          : ((b.endTime.hour * 60 + b.endTime.minute) -
                  (b.startTime.hour * 60 + b.startTime.minute))
              .clamp(0, 1440);
      final completedMins =
          getCompletedMinutesForSource(b.id, isDone, plannedMins);

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
        isCompleted: isDone || (plannedMins > 0 && completedMins >= plannedMins),
        customPlannedMinutes: plannedMins > 0 ? plannedMins : 20,
        completedMinutes: completedMins,
      ));
    }
  }

  // Sort chronologically
  items.sort((a, b) {
    final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
    final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
    return aMinutes.compareTo(bMinutes);
  });

  return items;
});

final dailyPlanProvider =
    FutureProvider.family<DailyPlanModel, DateTime>((ref, date) async {
  final repo = ref.watch(dailyPlanRepositoryProvider);
  var plan = await repo.getPlanForDate(date);

  // Compute real planned & completed minutes from timeline items
  final items = await ref.watch(timelineProvider(date).future);

  int totalPlannedMins = 0;
  int totalCompletedMins = 0;
  for (final item in items) {
    totalPlannedMins += item.plannedMinutes;
    totalCompletedMins += item.completedMinutes;
  }

  final plannedSeconds = totalPlannedMins * 60;
  final completedSeconds = totalCompletedMins * 60;
  final isCompleted =
      totalPlannedMins > 0 && totalCompletedMins >= totalPlannedMins;

  if (plan == null) {
    plan = DailyPlanModel(
      id: const Uuid().v4(),
      date: date,
      plannedDurationSeconds: plannedSeconds,
      completedDurationSeconds: completedSeconds,
      status: isCompleted ? DailyPlanStatus.completed : DailyPlanStatus.planned,
      createdAt: DateTime.now(),
    );
  } else {
    plan = plan.copyWith(
      plannedDurationSeconds: plannedSeconds,
      completedDurationSeconds: completedSeconds,
      status: isCompleted ? DailyPlanStatus.completed : plan.status,
    );
  }
  return plan;
});

final plannedBlocksProvider =
    FutureProvider.family<List<PlannedTaskBlockModel>, String>(
        (ref, planId) async {
  final repo = ref.watch(dailyPlanRepositoryProvider);
  return repo.getBlocksForDate(planId);
});

class DailyPlanNotifier extends StateNotifier<AsyncValue<void>> {
  final DailyPlanRepository _repo;
  final Ref _ref;

  DailyPlanNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> addPlannedBlock(
      PlannedTaskBlockModel block, DateTime date) async {
    var plan = await _repo.getPlanForDate(date);
    if (plan == null) {
      plan = DailyPlanModel(
        id: block.dailyPlanId,
        date: date,
        plannedDurationSeconds: block.estimatedDurationSeconds,
        createdAt: DateTime.now(),
      );
      await _repo.savePlan(plan);
      await _ref.read(syncRepositoryProvider).enqueueChange(
            entityType: 'daily_plans',
            entityId: plan.id,
            operation: SyncOperation.create,
          );
    }

    await _repo.saveBlock(block);
    await _ref.read(syncRepositoryProvider).enqueueChange(
          entityType: 'planned_task_blocks',
          entityId: block.id,
          operation: SyncOperation.create,
        );

    _ref.invalidate(dailyPlanProvider(date));
    _ref.invalidate(plannedBlocksProvider(plan.id));
    _ref.invalidate(timelineProvider(date));
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> deletePlannedBlock(String blockId, DateTime date) async {
    await _repo.deleteBlock(blockId);
    await _ref.read(syncRepositoryProvider).enqueueChange(
          entityType: 'planned_task_blocks',
          entityId: blockId,
          operation: SyncOperation.delete,
        );
    final plan = await _repo.getPlanForDate(date);
    if (plan != null) {
      _ref.invalidate(dailyPlanProvider(date));
      _ref.invalidate(plannedBlocksProvider(plan.id));
      _ref.invalidate(timelineProvider(date));
    }
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> deleteDayPlan(DateTime date) async {
    final deletedPlan = await _repo.deletePlanForDate(date);
    if (deletedPlan != null) {
      await _ref.read(syncRepositoryProvider).enqueueChange(
            entityType: 'daily_plans',
            entityId: deletedPlan.id,
            operation: SyncOperation.delete,
          );
    }
    _ref.invalidate(dailyPlanProvider(date));
    if (deletedPlan != null) {
      _ref.invalidate(plannedBlocksProvider(deletedPlan.id));
    }
    _ref.invalidate(timelineProvider(date));
    _ref.read(syncServiceProvider).autoSync();
  }
}

final dailyPlanNotifierProvider = Provider<DailyPlanNotifier>((ref) {
  return DailyPlanNotifier(ref.watch(dailyPlanRepositoryProvider), ref);
});
