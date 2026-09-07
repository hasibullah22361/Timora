import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/goal_model.dart';
import '../models/milestone_model.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return GoalRepository(prefs, userId: currentUser?.id);
});

class GoalRepository {
  static const String _defaultGoalsKey = 'timora_goals_data';
  static const String _defaultMilestonesKey = 'timora_milestones_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<GoalModel> _goals = [];
  final List<MilestoneModel> _milestones = [];

  GoalRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _goalsKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_goals_${_userId}_data'
      : _defaultGoalsKey;

  String get _milestonesKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_milestones_${_userId}_data'
      : _defaultMilestonesKey;

  void _loadFromStorage() {
    final goalsJson = _prefs.getString(_goalsKey);
    final milestonesJson = _prefs.getString(_milestonesKey);

    _goals.clear();
    _milestones.clear();

    if (goalsJson != null && goalsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedGoals = jsonDecode(goalsJson);
        for (var item in decodedGoals) {
          _goals.add(GoalModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    if (milestonesJson != null && milestonesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedMilestones = jsonDecode(milestonesJson);
        for (var item in decodedMilestones) {
          _milestones.add(MilestoneModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final goalsJson = jsonEncode(_goals.map((g) => g.toJson()).toList());
    final milestonesJson = jsonEncode(_milestones.map((m) => m.toJson()).toList());
    await _prefs.setString(_goalsKey, goalsJson);
    await _prefs.setString(_milestonesKey, milestonesJson);
  }

  // GOALS CRUD
  Future<List<GoalModel>> getGoals() async {
    return _goals.where((g) => !g.isDeleted).toList();
  }

  Future<GoalModel?> getGoal(String id) async {
    try {
      return _goals.firstWhere((g) => g.id == id && !g.isDeleted);
    } catch (_) {
      return null;
    }
  }

  Future<void> createGoal(GoalModel goal) async {
    _goals.add(goal);
    await _saveToStorage();
  }

  Future<void> updateGoal(GoalModel goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index >= 0) {
      _goals[index] = goal.copyWith(updatedAt: DateTime.now());
      await _saveToStorage();
    }
  }

  Future<void> deleteGoal(String id) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index >= 0) {
      _goals[index] = _goals[index].copyWith(isDeleted: true, updatedAt: DateTime.now());
      await _saveToStorage();
    }
  }

  // MILESTONES CRUD
  Future<List<MilestoneModel>> getMilestonesForGoal(String goalId) async {
    return _milestones.where((m) => m.goalId == goalId).toList()..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> createMilestone(MilestoneModel milestone) async {
    _milestones.add(milestone);
    await _saveToStorage();
  }

  Future<void> updateMilestone(MilestoneModel milestone) async {
    final index = _milestones.indexWhere((m) => m.id == milestone.id);
    if (index >= 0) {
      _milestones[index] = milestone.copyWith(updatedAt: DateTime.now());
    } else {
      _milestones.add(milestone);
    }
    await _saveToStorage();
  }

  Future<void> deleteMilestone(String id) async {
    _milestones.removeWhere((m) => m.id == id);
    await _saveToStorage();
  }

  Future<void> reorderMilestones(String goalId, List<MilestoneModel> orderedMilestones) async {
    for (int i = 0; i < orderedMilestones.length; i++) {
      final m = orderedMilestones[i];
      final index = _milestones.indexWhere((sm) => sm.id == m.id);
      if (index >= 0) {
        _milestones[index] = _milestones[index].copyWith(order: i, updatedAt: DateTime.now());
      }
    }
    await _saveToStorage();
  }

  Future<List<MilestoneModel>> getAllMilestones() async {
    return List.from(_milestones);
  }
}

