import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../models/task_model.dart';
import '../models/subtask_model.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TaskRepository(prefs);
});

class TaskRepository {
  static const String _tasksKey = 'timora_tasks_data';
  static const String _subtasksKey = 'timora_subtasks_data';

  final SharedPreferences _prefs;
  final List<TaskModel> _tasks = [];
  final List<SubtaskModel> _subtasks = [];
  final _uuid = const Uuid();

  TaskRepository(this._prefs) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final tasksJson = _prefs.getString(_tasksKey);
    final subtasksJson = _prefs.getString(_subtasksKey);

    if (tasksJson != null) {
      try {
        final List<dynamic> decodedTasks = jsonDecode(tasksJson);
        _tasks.clear();
        for (var item in decodedTasks) {
          _tasks.add(TaskModel.fromJson(item as Map<String, dynamic>));
        }

        if (subtasksJson != null) {
          final List<dynamic> decodedSubtasks = jsonDecode(subtasksJson);
          _subtasks.clear();
          for (var item in decodedSubtasks) {
            _subtasks.add(SubtaskModel.fromJson(item as Map<String, dynamic>));
          }
        }

        if (_tasks.isNotEmpty) {
          return;
        }
      } catch (_) {
        // Fallback on error
      }
    }

    _seedData();
  }

  Future<void> _saveToStorage() async {
    final tasksJson = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    final subtasksJson = jsonEncode(_subtasks.map((s) => s.toJson()).toList());
    await _prefs.setString(_tasksKey, tasksJson);
    await _prefs.setString(_subtasksKey, subtasksJson);
  }

  void _seedData() {
    final now = DateTime.now();
    _tasks.add(
      TaskModel(
        id: _uuid.v4(),
        title: 'Complete ML assignment',
        description: 'Read the prompt and implement the neural network.',
        priority: TaskPriority.high,
        category: 'AI & Data Science',
        dueDate: DateTime(now.year, now.month, now.day),
        dueTime: const TimeOfDay(hour: 18, minute: 0),
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    );
    _tasks.add(
      TaskModel(
        id: _uuid.v4(),
        title: 'Read research paper',
        priority: TaskPriority.medium,
        category: 'Research',
        dueDate: DateTime(now.year, now.month, now.day),
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    );
    _tasks.add(
      TaskModel(
        id: _uuid.v4(),
        title: 'Review lecture notes',
        status: TaskStatus.completed,
        priority: TaskPriority.low,
        category: 'Study',
        dueDate: DateTime(now.year, now.month, now.day),
        createdAt: now.subtract(const Duration(hours: 12)),
        completedAt: now.subtract(const Duration(minutes: 30)),
      ),
    );
    _tasks.add(
      TaskModel(
        id: _uuid.v4(),
        title: 'Complete research methodology',
        status: TaskStatus.pending,
        priority: TaskPriority.high,
        category: 'Research',
        dueDate: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    );
    _saveToStorage();
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

  Future<void> createTask(TaskModel task) async {
    _tasks.add(task);
    await _saveToStorage();
  }

  Future<void> updateTask(TaskModel task) async {
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
      await _saveToStorage();
    }
  }

  Future<void> deleteSubtask(String id) async {
    _subtasks.removeWhere((s) => s.id == id);
    await _saveToStorage();
  }
}

