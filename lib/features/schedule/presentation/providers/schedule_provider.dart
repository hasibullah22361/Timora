import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/home/presentation/providers/home_provider.dart';
import 'package:timora/features/routine/application/routine_scheduler_service.dart';
import 'package:timora/features/notifications/application/notification_controller.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final scheduleActivitiesProvider = FutureProvider<List<ScheduleActivity>>((ref) async {
  final date = ref.watch(selectedDateProvider);
  
  // 1. Generate missing routine activities first
  final scheduler = ref.watch(routineSchedulerServiceProvider);
  await scheduler.generateScheduleForDate(date);

  // 2. Fetch the now-complete schedule
  final repo = ref.watch(scheduleRepositoryProvider);
  final activities = await repo.getActivitiesForDate(date);
  
  // 3. Sync notifications
  final notifController = ref.watch(notificationControllerProvider);
  await notifController.syncScheduleNotifications(date);
  
  // Re-evaluate statuses based on current time
  final currentTime = ref.watch(currentTimeProvider);
  
  return activities.map((activity) {
    if (activity.status == ActivityStatus.completed || activity.status == ActivityStatus.skipped) {
      return activity;
    }
    
    if (currentTime.isAfter(activity.startTime) && currentTime.isBefore(activity.endTime)) {
      return activity.copyWith(status: ActivityStatus.current);
    } else if (currentTime.isAfter(activity.endTime)) {
      return activity.copyWith(status: ActivityStatus.skipped);
    } else {
      return activity.copyWith(status: ActivityStatus.upcoming);
    }
  }).toList();
});

class ScheduleNotifier extends StateNotifier<AsyncValue<void>> {
  final ScheduleRepository _repo;
  final Ref _ref;

  ScheduleNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  void _notifyRelated(DateTime date) {
    _ref.invalidate(scheduleActivitiesProvider);
    _ref.invalidate(dailyScheduleProvider);
    _ref.invalidate(scheduleActivitiesByDateProvider(date));
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> addActivity(ScheduleActivity activity) async {
    try {
      await _repo.addActivity(activity);
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'schedule_activities',
        entityId: activity.id,
        operation: SyncOperation.create,
      );
      _notifyRelated(activity.date);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateActivity(ScheduleActivity activity) async {
    await _repo.updateActivity(activity);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'schedule_activities',
      entityId: activity.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(activity.date);
  }

  Future<void> deleteActivity(String id, [DateTime? date]) async {
    await _repo.deleteActivity(id);
    final notifController = _ref.read(notificationControllerProvider);
    await notifController.cancelAllForActivity(id);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'schedule_activities',
      entityId: id,
      operation: SyncOperation.delete,
    );
    _notifyRelated(date ?? DateTime.now());
  }

  Future<void> markCompleted(ScheduleActivity activity) async {
    final updated = activity.copyWith(
      status: ActivityStatus.completed,
      completedAt: DateTime.now(),
      isOverridden: true,
    );
    await _repo.updateActivity(updated);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'schedule_activities',
      entityId: activity.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(activity.date);
  }

  Future<void> markSkipped(ScheduleActivity activity) async {
    final updated = activity.copyWith(
      status: ActivityStatus.skipped,
      isOverridden: true,
    );
    await _repo.updateActivity(updated);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'schedule_activities',
      entityId: activity.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(activity.date);
  }

  Future<void> resetToRoutine(ScheduleActivity activity) async {
    final updated = activity.copyWith(isOverridden: false);
    await _repo.updateActivity(updated);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'schedule_activities',
      entityId: activity.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(activity.date);
  }
}

final scheduleNotifierProvider = Provider<ScheduleNotifier>((ref) {
  return ScheduleNotifier(ref.watch(scheduleRepositoryProvider), ref);
});

final scheduleActivitiesByDateProvider = FutureProvider.family<List<ScheduleActivity>, DateTime>((ref, date) async {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.getActivitiesForDate(date);
});
