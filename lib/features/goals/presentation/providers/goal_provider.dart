import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/goals/data/models/goal_model.dart';
import 'package:timora/features/goals/data/models/milestone_model.dart';
import 'package:timora/features/goals/data/repositories/goal_repository.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';

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
  
  // If no milestones, check linked tasks
  final allTasks = await ref.watch(allTasksProvider.future);
  final linkedTasks = allTasks.where((t) => t.goalId == goalId).toList();
  if (linkedTasks.isNotEmpty) {
    final completed = linkedTasks.where((t) => t.isCompleted).length;
    return completed / linkedTasks.length;
  }
  
  return 0.0;
});

class GoalNotifier extends StateNotifier<AsyncValue<void>> {
  final GoalRepository _repo;
  final Ref _ref;

  GoalNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> createGoal(GoalModel goal) async {
    await _repo.createGoal(goal);
    _ref.invalidate(allGoalsProvider);
  }

  Future<void> updateGoal(GoalModel goal) async {
    await _repo.updateGoal(goal);
    _ref.invalidate(allGoalsProvider);
    _ref.invalidate(goalDetailsProvider(goal.id));
  }

  Future<void> deleteGoal(String id) async {
    await _repo.deleteGoal(id);
    _ref.invalidate(allGoalsProvider);
    _ref.invalidate(goalDetailsProvider(id));
  }
  
  Future<void> pauseGoal(GoalModel goal) async {
    await _repo.updateGoal(goal.copyWith(status: GoalStatus.paused));
    _ref.invalidate(allGoalsProvider);
    _ref.invalidate(goalDetailsProvider(goal.id));
  }
  
  Future<void> completeGoal(GoalModel goal) async {
    await _repo.updateGoal(goal.copyWith(status: GoalStatus.completed, completedAt: DateTime.now()));
    _ref.invalidate(allGoalsProvider);
    _ref.invalidate(goalDetailsProvider(goal.id));
  }
  
  Future<void> resumeGoal(GoalModel goal) async {
    await _repo.updateGoal(goal.copyWith(status: GoalStatus.active, completedAt: null));
    _ref.invalidate(allGoalsProvider);
    _ref.invalidate(goalDetailsProvider(goal.id));
  }
  
  Future<void> archiveGoal(GoalModel goal) async {
    await _repo.updateGoal(goal.copyWith(status: GoalStatus.archived));
    _ref.invalidate(allGoalsProvider);
    _ref.invalidate(goalDetailsProvider(goal.id));
  }

  // Milestones
  Future<void> createMilestone(MilestoneModel milestone) async {
    await _repo.createMilestone(milestone);
    _ref.invalidate(milestonesProvider(milestone.goalId));
    _ref.invalidate(goalProgressProvider(milestone.goalId));
  }

  Future<void> updateMilestone(MilestoneModel milestone) async {
    await _repo.updateMilestone(milestone);
    _ref.invalidate(milestonesProvider(milestone.goalId));
    _ref.invalidate(goalProgressProvider(milestone.goalId));
  }

  Future<void> deleteMilestone(String id, String goalId) async {
    await _repo.deleteMilestone(id);
    _ref.invalidate(milestonesProvider(goalId));
    _ref.invalidate(goalProgressProvider(goalId));
  }

  Future<void> reorderMilestones(String goalId, List<MilestoneModel> ordered) async {
    // Optimistic update
    await _repo.reorderMilestones(goalId, ordered);
    _ref.invalidate(milestonesProvider(goalId));
  }
}

final goalNotifierProvider = Provider<GoalNotifier>((ref) {
  return GoalNotifier(ref.watch(goalRepositoryProvider), ref);
});
