import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit_model.dart';
import '../../data/models/habit_log_model.dart';
import '../../data/repositories/habit_repository.dart';
import '../../../cloud_sync/data/models/cloud_models.dart';
import '../../../cloud_sync/data/repositories/sync_repository.dart';
import '../../../cloud_sync/services/sync_service.dart';
import '../../../goals/presentation/providers/goal_provider.dart';

final allHabitsProvider = FutureProvider<List<HabitModel>>((ref) async {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.getHabits();
});

final habitLogsProvider = FutureProvider.family<List<HabitLogModel>, String>((ref, habitId) async {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.getHabitLogs(habitId);
});

final habitCompletedTodayProvider = FutureProvider.family<bool, String>((ref, habitId) async {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.isHabitCompletedOnDate(habitId, DateTime.now());
});

class HabitNotifier extends StateNotifier<AsyncValue<void>> {
  final HabitRepository _repo;
  final Ref _ref;

  HabitNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  void _notifyRelated(String? goalId) {
    _ref.invalidate(allHabitsProvider);
    if (goalId != null && goalId.isNotEmpty) {
      _ref.invalidate(allGoalsProvider);
      _ref.invalidate(goalProgressProvider(goalId));
    }
    _ref.read(syncServiceProvider).autoSync();
  }

  Future<void> createHabit(HabitModel habit) async {
    await _repo.createHabit(habit);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'habits',
      entityId: habit.id,
      operation: SyncOperation.create,
    );
    _notifyRelated(habit.goalId);
  }

  Future<void> updateHabit(HabitModel habit) async {
    await _repo.updateHabit(habit);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'habits',
      entityId: habit.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(habit.goalId);
  }

  Future<void> deleteHabit(String id, {String? goalId}) async {
    await _repo.deleteHabit(id);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'habits',
      entityId: id,
      operation: SyncOperation.delete,
    );
    _notifyRelated(goalId);
  }

  Future<bool> toggleHabit(String habitId, DateTime date, {String? goalId}) async {
    final isCompleted = await _repo.toggleHabitLog(habitId, date);
    _ref.invalidate(allHabitsProvider);
    _ref.invalidate(habitLogsProvider(habitId));
    _ref.invalidate(habitCompletedTodayProvider(habitId));
    if (goalId != null && goalId.isNotEmpty) {
      _ref.invalidate(goalProgressProvider(goalId));
    }
    final logId = _repo.lastToggledLogId;
    if (logId != null) {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'habit_logs',
        entityId: logId,
        operation: isCompleted ? SyncOperation.create : SyncOperation.delete,
      );
    }
    _ref.read(syncServiceProvider).autoSync();
    return isCompleted;
  }
}

final habitNotifierProvider = Provider<HabitNotifier>((ref) {
  return HabitNotifier(ref.watch(habitRepositoryProvider), ref);
});
