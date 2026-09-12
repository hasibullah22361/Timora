import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/goals/data/models/goal_model.dart';
import 'package:timora/features/goals/data/models/milestone_model.dart';
import 'package:timora/features/goals/data/repositories/goal_repository.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import 'package:timora/features/habits/presentation/providers/habit_provider.dart';
import 'package:timora/features/widget/services/widget_update_service.dart';

final allGoalsProvider = FutureProvider<List<GoalModel>>((ref) async {
  final repo = ref.watch(goalRepositoryProvider);
  return repo.getGoals();
});

final activeGoalsProvider = FutureProvider<List<GoalModel>>((ref) async {
  final goals = await ref.watch(allGoalsProvider.future);
  return goals.where((g) => g.status == GoalStatus.active).toList();
});

final completedGoalsProvider = FutureProvider<List<GoalModel>>((ref) async {
  final goals = await ref.watch(allGoalsProvider.future);
  return goals.where((g) => g.status == GoalStatus.completed).toList();
});

final pausedGoalsProvider = FutureProvider<List<GoalModel>>((ref) async {
  final goals = await ref.watch(allGoalsProvider.future);
  return goals.where((g) => g.status == GoalStatus.paused).toList();
});

final archivedGoalsProvider = FutureProvider<List<GoalModel>>((ref) async {
  final goals = await ref.watch(allGoalsProvider.future);
  return goals.where((g) => g.status == GoalStatus.archived).toList();
});

final goalDetailsProvider = FutureProvider.family<GoalModel?, String>((ref, id) async {
  final repo = ref.watch(goalRepositoryProvider);
  return repo.getGoal(id);
});

final milestonesProvider = FutureProvider.family<List<MilestoneModel>, String>((ref, goalId) async {
  final repo = ref.watch(goalRepositoryProvider);
  return repo.getMilestonesForGoal(goalId);
});

// Dynamic calculated progress
final goalProgressProvider = FutureProvider.family<double, String>((ref, goalId) async {
  final goal = await ref.watch(goalDetailsProvider(goalId).future);
  if (goal == null) return 0.0;
  
  if (goal.progressMode == ProgressMode.manual) {
    return goal.manualProgress;
  }
  
  // Auto mode: check milestones
  final milestones = await ref.watch(milestonesProvider(goalId).future);
  if (milestones.isNotEmpty) {
    final completed = milestones.where((m) => m.status == MilestoneStatus.completed).length;
    return completed / milestones.length;
  }
  
  // If no milestones, check linked tasks and habits
  final allTasks = await ref.watch(allTasksProvider.future);
  final linkedTasks = allTasks.where((t) => t.goalId == goalId).toList();
  final allHabits = ref.watch(allHabitsProvider).valueOrNull ?? [];
  final linkedHabits = allHabits.where((h) => h.goalId == goalId).toList();

  final totalItems = linkedTasks.length + linkedHabits.length;
  if (totalItems > 0) {
    final completedTasks = linkedTasks.where((t) => t.isCompleted).length;
    final activeHabitsOnStreak = linkedHabits.where((h) => h.currentStreak > 0).length;
    return (completedTasks + activeHabitsOnStreak) / totalItems;
  }
  
  return 0.0;
});

class GoalNotifier extends StateNotifier<AsyncValue<void>> {
  final GoalRepository _repo;
  final Ref _ref;

  GoalNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  void _notifyRelated(String goalId) {
    _ref.invalidate(allGoalsProvider);
    _ref.invalidate(goalDetailsProvider(goalId));
    _ref.invalidate(milestonesProvider(goalId));
    _ref.invalidate(goalProgressProvider(goalId));
    _ref.read(syncServiceProvider).autoSync();
    _ref.read(widgetUpdateServiceProvider).updateWidgets();
  }

  Future<void> createGoal(GoalModel goal) async {
    await _repo.createGoal(goal);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'goals',
      entityId: goal.id,
      operation: SyncOperation.create,
    );
    _notifyRelated(goal.id);
  }

  Future<void> updateGoal(GoalModel goal) async {
    await _repo.updateGoal(goal);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'goals',
      entityId: goal.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(goal.id);
  }

  Future<void> deleteGoal(String id) async {
    await _repo.deleteGoal(id);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'goals',
      entityId: id,
      operation: SyncOperation.delete,
    );
    _notifyRelated(id);
  }
  
  Future<void> pauseGoal(GoalModel goal) async {
    await _repo.updateGoal(goal.copyWith(status: GoalStatus.paused));
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'goals',
      entityId: goal.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(goal.id);
  }
  
  Future<void> completeGoal(GoalModel goal) async {
    await _repo.updateGoal(goal.copyWith(status: GoalStatus.completed, completedAt: DateTime.now()));
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'goals',
      entityId: goal.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(goal.id);
  }
  
  Future<void> resumeGoal(GoalModel goal) async {
    await _repo.updateGoal(goal.copyWith(status: GoalStatus.active, completedAt: null));
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'goals',
      entityId: goal.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(goal.id);
  }
  
  Future<void> archiveGoal(GoalModel goal) async {
    await _repo.updateGoal(goal.copyWith(status: GoalStatus.archived));
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'goals',
      entityId: goal.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(goal.id);
  }

  // Milestones
  Future<void> createMilestone(MilestoneModel milestone) async {
    await _repo.createMilestone(milestone);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'milestones',
      entityId: milestone.id,
      operation: SyncOperation.create,
    );
    _notifyRelated(milestone.goalId);
  }

  Future<void> updateMilestone(MilestoneModel milestone) async {
    await _repo.updateMilestone(milestone);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'milestones',
      entityId: milestone.id,
      operation: SyncOperation.update,
    );
    _notifyRelated(milestone.goalId);
  }

  Future<void> deleteMilestone(String id, String goalId) async {
    await _repo.deleteMilestone(id);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'milestones',
      entityId: id,
      operation: SyncOperation.delete,
    );
    _notifyRelated(goalId);
  }

  Future<void> reorderMilestones(String goalId, List<MilestoneModel> ordered) async {
    await _repo.reorderMilestones(goalId, ordered);
    _notifyRelated(goalId);
  }
}

final goalNotifierProvider = Provider<GoalNotifier>((ref) {
  return GoalNotifier(ref.watch(goalRepositoryProvider), ref);
});
