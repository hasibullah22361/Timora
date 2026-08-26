import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/home/presentation/providers/home_provider.dart';
import 'package:timora/features/routine/application/routine_scheduler_service.dart';
import 'package:timora/features/notifications/application/notification_controller.dart';

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
      // If it's in the past and wasn't completed, mark as skipped or keep as upcoming? 
      // Usually past uncompleted is skipped or missed. Let's just keep it as is for now or mark skipped.
      // We will leave it as upcoming/missed, but UI will show it differently.
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

  Future<void> addActivity(ScheduleActivity activity) async {
    try {
      await _repo.addActivity(activity);
      _ref.invalidate(scheduleActivitiesProvider);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateActivity(ScheduleActivity activity) async {
    await _repo.updateActivity(activity);
    _ref.invalidate(scheduleActivitiesProvider);
  }

  Future<void> deleteActivity(String id) async {
    await _repo.deleteActivity(id);
    final notifController = _ref.read(notificationControllerProvider);
    await notifController.cancelAllForActivity(id);
    _ref.invalidate(scheduleActivitiesProvider);
  }

  Future<void> markCompleted(ScheduleActivity activity) async {
    await _repo.updateActivity(activity.copyWith(
      status: ActivityStatus.completed,
      completedAt: DateTime.now(),
      isOverridden: true, // marking completed manually implies overriding the routine block logic
    ));
    _ref.invalidate(scheduleActivitiesProvider);
  }

  Future<void> markSkipped(ScheduleActivity activity) async {
    await _repo.updateActivity(activity.copyWith(
      status: ActivityStatus.skipped,
      isOverridden: true,
    ));
    _ref.invalidate(scheduleActivitiesProvider);
  }

  Future<void> resetToRoutine(ScheduleActivity activity) async {
    // We revert the override by fetching the routine block it came from, 
    // or simply marking it as not overridden, but realistically resetting implies getting original values back.
    // For now, if we reset, we just toggle isOverridden. Real logic would pull the original block times.
    await _repo.updateActivity(activity.copyWith(isOverridden: false));
    _ref.invalidate(scheduleActivitiesProvider);
  }
}

final scheduleNotifierProvider = Provider<ScheduleNotifier>((ref) {
  return ScheduleNotifier(ref.watch(scheduleRepositoryProvider), ref);
});

final scheduleActivitiesByDateProvider = FutureProvider.family<List<ScheduleActivity>, DateTime>((ref, date) async {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.getActivitiesForDate(date);
});
