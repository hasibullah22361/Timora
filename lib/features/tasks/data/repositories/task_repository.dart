import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/task_model.dart';
import '../models/subtask_model.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return TaskRepository(prefs, userId: currentUser?.id);
});

class TaskRepository {
  static const String _defaultTasksKey = 'timora_tasks_data';
  static const String _defaultSubtasksKey = 'timora_subtasks_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<TaskModel> _tasks = [];
  final List<SubtaskModel> _subtasks = [];

  TaskRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _tasksKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_tasks_${_userId}_data'
      : _defaultTasksKey;

  String get _subtasksKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_subtasks_${_userId}_data'
      : _defaultSubtasksKey;

  void _loadFromStorage() {
    final tasksJson = _prefs.getString(_tasksKey);
    final subtasksJson = _prefs.getString(_subtasksKey);

    _tasks.clear();
    _subtasks.clear();

    if (tasksJson != null && tasksJson.isNotEmpty) {
      try {
        final List<dynamic> decodedTasks = jsonDecode(tasksJson);
        for (var item in decodedTasks) {
          _tasks.add(TaskModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {
        // Fallback on error
      }
    }

    if (subtasksJson != null && subtasksJson.isNotEmpty) {
      try {
        final List<dynamic> decodedSubtasks = jsonDecode(subtasksJson);
        for (var item in decodedSubtasks) {
          _subtasks.add(SubtaskModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {
        // Fallback on error
      }
    }
  }

  Future<void> _saveToStorage() async {
    final tasksJson = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    final subtasksJson = jsonEncode(_subtasks.map((s) => s.toJson()).toList());
    await _prefs.setString(_tasksKey, tasksJson);
    await _prefs.setString(_subtasksKey, subtasksJson);
  }

  Future<List<TaskModel>> getTasks() async {
    return _tasks.where((t) => !t.isDeleted).toList();
  }

  Future<TaskModel?> getTask(String id) async {
    try {
      return _tasks.firstWhere((t) => t.id == id && !t.isDeleted);
    } catch (_) {
      return null;
    }
  }

  // --- Dependency Management ---

  /// Validates that adding [dependsOnIds] to [taskId] will not create a circular dependency
  bool validateNoCircularDependencies(String taskId, List<String> dependsOnIds) {
    if (dependsOnIds.contains(taskId)) return false;

    final visited = <String>{};
    final recursionStack = <String>{taskId};

    bool hasCycle(String currentId) {
      if (recursionStack.contains(currentId)) return true;
      if (visited.contains(currentId)) return false;

      visited.add(currentId);
      recursionStack.add(currentId);

      final task = _tasks.where((t) => t.id == currentId && !t.isDeleted).firstOrNull;
      if (task != null) {
        final dependencies = currentId == taskId ? dependsOnIds : task.dependsOnTaskIds;
        for (final depId in dependencies) {
          if (hasCycle(depId)) return true;
        }
      }

      recursionStack.remove(currentId);
      return false;
    }

    for (final depId in dependsOnIds) {
      if (hasCycle(depId)) return false;
    }

    return true;
  }

  /// Checks if a task is currently blocked by incomplete prerequisite dependencies
  bool isTaskBlocked(String taskId) {
    final task = _tasks.where((t) => t.id == taskId && !t.isDeleted).firstOrNull;
    if (task == null || task.dependsOnTaskIds.isEmpty) return false;

    for (final depId in task.dependsOnTaskIds) {
      final prerequisite = _tasks.where((t) => t.id == depId && !t.isDeleted).firstOrNull;
      if (prerequisite != null && !prerequisite.isCompleted) {
        return true;
      }
    }
    return false;
  }

  /// Returns prerequisite tasks for a given task
  List<TaskModel> getPrerequisitesForTask(String taskId) {
    final task = _tasks.where((t) => t.id == taskId && !t.isDeleted).firstOrNull;
    if (task == null || task.dependsOnTaskIds.isEmpty) return [];

    return _tasks.where((t) => task.dependsOnTaskIds.contains(t.id) && !t.isDeleted).toList();
  }

  /// Returns tasks that depend on this task
  List<TaskModel> getDependentTasks(String taskId) {
    return _tasks.where((t) => t.dependsOnTaskIds.contains(taskId) && !t.isDeleted).toList();
  }

  // --- CRUD Operations ---

  Future<void> createTask(TaskModel task) async {
    if (!validateNoCircularDependencies(task.id, task.dependsOnTaskIds)) {
      throw Exception('Circular dependency detected. Task cannot depend on itself or its dependents.');
    }
    _tasks.add(task);
    await _saveToStorage();
  }

  Future<void> updateTask(TaskModel task) async {
    if (!validateNoCircularDependencies(task.id, task.dependsOnTaskIds)) {
      throw Exception('Circular dependency detected. Task cannot depend on itself or its dependents.');
    }
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _tasks[index] = task.copyWith(updatedAt: DateTime.now());
      await _saveToStorage();
    }
  }

  Future<void> deleteTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index >= 0) {
      _tasks[index] = _tasks[index].copyWith(
        isDeleted: true,
        updatedAt: DateTime.now(),
      );
      await _saveToStorage();
    }
  }

  Future<void> restoreTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index >= 0) {
      _tasks[index] = _tasks[index].copyWith(
        isDeleted: false,
        updatedAt: DateTime.now(),
      );
      await _saveToStorage();
    }
  }

  // Subtasks
  Future<List<SubtaskModel>> getSubtasksForTask(String taskId) async {
    return _subtasks.where((s) => s.taskId == taskId).toList()..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> createSubtask(SubtaskModel subtask) async {
    _subtasks.add(subtask);
    await _saveToStorage();
  }

  Future<void> updateSubtask(SubtaskModel subtask) async {
    final index = _subtasks.indexWhere((s) => s.id == subtask.id);
    if (index >= 0) {
      _subtasks[index] = subtask.copyWith(updatedAt: DateTime.now());
    } else {
      _subtasks.add(subtask);
    }
    await _saveToStorage();
  }

  Future<void> deleteSubtask(String id) async {
    _subtasks.removeWhere((s) => s.id == id);
    await _saveToStorage();
  }

  Future<List<SubtaskModel>> getAllSubtasks() async {
    return List.from(_subtasks);
  }
}
