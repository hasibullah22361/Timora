import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/habit_model.dart';
import '../models/habit_log_model.dart';

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return HabitRepository(prefs, userId: currentUser?.id);
});

class HabitRepository {
  static const String _defaultHabitsKey = 'timora_habits_data';
  static const String _defaultLogsKey = 'timora_habit_logs_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<HabitModel> _habits = [];
  final List<HabitLogModel> _logs = [];
  final _uuid = const Uuid();

  HabitRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _habitsKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_habits_${_userId}_data'
      : _defaultHabitsKey;

  String get _logsKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_habit_logs_${_userId}_data'
      : _defaultLogsKey;

  void _loadFromStorage() {
    final habitsJson = _prefs.getString(_habitsKey);
    final logsJson = _prefs.getString(_logsKey);

    _habits.clear();
    _logs.clear();

    if (habitsJson != null && habitsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedHabits = jsonDecode(habitsJson);
        for (var item in decodedHabits) {
          _habits.add(HabitModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    if (logsJson != null && logsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedLogs = jsonDecode(logsJson);
        for (var item in decodedLogs) {
          _logs.add(HabitLogModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final habitsJson = jsonEncode(_habits.map((h) => h.toJson()).toList());
    final logsJson = jsonEncode(_logs.map((l) => l.toJson()).toList());
    await _prefs.setString(_habitsKey, habitsJson);
    await _prefs.setString(_logsKey, logsJson);
  }

  Future<List<HabitModel>> getHabits() async {
    return _habits.where((h) => !h.isArchived).toList();
  }

  Future<HabitModel?> getHabit(String id) async {
    try {
      return _habits.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> createHabit(HabitModel habit) async {
    _habits.add(habit);
    await _saveToStorage();
  }

  Future<void> updateHabit(HabitModel habit) async {
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index >= 0) {
      _habits[index] = habit.copyWith(updatedAt: DateTime.now());
      await _saveToStorage();
    }
  }

  Future<void> deleteHabit(String id) async {
    _habits.removeWhere((h) => h.id == id);
    _logs.removeWhere((l) => l.habitId == id);
    await _saveToStorage();
  }

  // --- Habit Logs & Streaks ---

  String? _lastToggledLogId;
  String? get lastToggledLogId => _lastToggledLogId;

  Future<bool> toggleHabitLog(String habitId, DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final existingIndex = _logs.indexWhere(
      (l) => l.habitId == habitId &&
             l.logDate.year == normalized.year &&
             l.logDate.month == normalized.month &&
             l.logDate.day == normalized.day,
    );

    bool isNowCompleted;
    if (existingIndex >= 0) {
      final removed = _logs.removeAt(existingIndex);
      _lastToggledLogId = removed.id;
      isNowCompleted = false;
    } else {
      final newLog = HabitLogModel(
        id: _uuid.v4(),
        habitId: habitId,
        logDate: normalized,
        completed: true,
        createdAt: DateTime.now(),
      );
      _logs.add(newLog);
      _lastToggledLogId = newLog.id;
      isNowCompleted = true;
    }

    // Recalculate streak for this habit
    await _recalculateStreaks(habitId);
    await _saveToStorage();
    return isNowCompleted;
  }

  Future<HabitLogModel?> getHabitLogForDate(String habitId, DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    try {
      return _logs.firstWhere(
        (l) => l.habitId == habitId &&
               l.logDate.year == normalized.year &&
               l.logDate.month == normalized.month &&
               l.logDate.day == normalized.day,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<HabitLogModel>> getAllLogs() async {
    return List.unmodifiable(_logs);
  }

  Future<HabitLogModel?> getLogById(String id) async {
    try {
      return _logs.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHabitLog(HabitLogModel log) async {
    final index = _logs.indexWhere((l) => l.id == log.id);
    if (index >= 0) {
      _logs[index] = log;
    } else {
      _logs.add(log);
    }
    await _recalculateStreaks(log.habitId);
    await _saveToStorage();
  }

  Future<void> deleteHabitLog(String id) async {
    final index = _logs.indexWhere((l) => l.id == id);
    if (index >= 0) {
      final removed = _logs.removeAt(index);
      await _recalculateStreaks(removed.habitId);
      await _saveToStorage();
    }
  }

  Future<List<HabitLogModel>> getHabitLogs(
    String habitId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _logs.where((l) {
      if (l.habitId != habitId) return false;
      if (startDate != null && l.logDate.isBefore(startDate)) return false;
      if (endDate != null && l.logDate.isAfter(endDate)) return false;
      return true;
    }).toList();
  }

  Future<bool> isHabitCompletedOnDate(String habitId, DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _logs.any(
      (l) => l.habitId == habitId &&
             l.completed &&
             l.logDate.year == normalized.year &&
             l.logDate.month == normalized.month &&
             l.logDate.day == normalized.day,
    );
  }

  Future<void> _recalculateStreaks(String habitId) async {
    final habitIndex = _habits.indexWhere((h) => h.id == habitId);
    if (habitIndex < 0) return;

    final habit = _habits[habitIndex];
    final habitLogs = _logs
        .where((l) => l.habitId == habitId && l.completed)
        .map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day))
        .toSet();

    if (habitLogs.isEmpty) {
      _habits[habitIndex] = habit.copyWith(currentStreak: 0);
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    int currentStreak = 0;
    DateTime checkDate = habitLogs.contains(today) ? today : yesterday;

    while (habitLogs.contains(checkDate)) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // If today is not completed yet and yesterday was not either, streak is 0
    if (!habitLogs.contains(today) && !habitLogs.contains(yesterday)) {
      currentStreak = 0;
    }

    int bestStreak = habit.bestStreak;
    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    _habits[habitIndex] = habit.copyWith(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      updatedAt: DateTime.now(),
    );
  }
}
