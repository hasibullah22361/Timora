import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/schedule_activity.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return ScheduleRepository(prefs, userId: currentUser?.id);
});

class ScheduleRepository {
  static const String _defaultStorageKey = 'timora_schedule_activities_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<ScheduleActivity> _activities = [];

  ScheduleRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _storageKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_schedule_activities_${_userId}_data'
      : _defaultStorageKey;

  void _loadFromStorage() {
    final jsonString = _prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _activities.clear();
        for (var item in decoded) {
          _activities.add(ScheduleActivity.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {
        // Fallback on error
      }
    }
  }

  Future<void> _saveToStorage() async {
    final jsonString = jsonEncode(_activities.map((a) => a.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }

  Future<List<ScheduleActivity>> getActivitiesForDate(DateTime date) async {
    return _activities
        .where((a) =>
            a.date.year == date.year &&
            a.date.month == date.month &&
            a.date.day == date.day)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<List<ScheduleActivity>> getAllActivities() async {
    return List.from(_activities);
  }

  Future<void> addActivity(ScheduleActivity activity) async {
    // Check overlaps
    final daily = await getActivitiesForDate(activity.date);
    for (var existing in daily) {
      if (existing.status == ActivityStatus.replaced ||
          existing.id == activity.replacesActivityId) {
        continue;
      }
      if (activity.startTime.isBefore(existing.endTime) &&
          activity.endTime.isAfter(existing.startTime)) {
        throw Exception('These activities overlap with "${existing.title}".');
      }
    }
    _activities.add(activity);
    await _saveToStorage();
  }

  Future<void> replaceActivity({
    required ScheduleActivity originalActivity,
    required ScheduleActivity replacementActivity,
  }) async {
    // Strictly preserve original time block, duration, date, position, routine info, and ID:
    final updated = replacementActivity.copyWith(
      id: originalActivity.id,
      date: originalActivity.date,
      startTime: originalActivity.startTime,
      endTime: originalActivity.endTime,
      routineBlockId: originalActivity.routineBlockId,
      reminderEnabled: originalActivity.reminderEnabled,
      isOverridden: true,
      replacesActivityId: originalActivity.id,
      originalActivityTitle: originalActivity.originalActivityTitle ?? originalActivity.title,
      updatedAt: DateTime.now(),
    );

    final originalIndex = _activities.indexWhere((a) => a.id == originalActivity.id);
    if (originalIndex >= 0) {
      _activities[originalIndex] = updated;
    } else {
      _activities.add(updated);
    }

    // Clean up any extra entry if replacementActivity had a different temporary ID
    if (replacementActivity.id != originalActivity.id) {
      _activities.removeWhere((a) => a.id == replacementActivity.id);
    }

    // Clean up any duplicate blocks on this day for the same routine block
    if (originalActivity.routineBlockId != null) {
      _activities.removeWhere((a) =>
          a.id != originalActivity.id &&
          a.routineBlockId == originalActivity.routineBlockId &&
          a.date.year == originalActivity.date.year &&
          a.date.month == originalActivity.date.month &&
          a.date.day == originalActivity.date.day);
    }

    await _saveToStorage();
  }

  Future<void> addActivities(List<ScheduleActivity> activities) async {
    _activities.addAll(activities);
    await _saveToStorage();
  }

  Future<void> updateActivity(ScheduleActivity activity) async {
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index >= 0) {
      _activities[index] = activity.copyWith(updatedAt: DateTime.now());
    } else {
      _activities.add(activity);
    }
    await _saveToStorage();
  }

  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    await _saveToStorage();
  }

  Future<void> deleteActivitiesForRoutineBlockIds(List<String> blockIds) async {
    if (blockIds.isEmpty) return;
    _activities.removeWhere((a) => a.routineBlockId != null && blockIds.contains(a.routineBlockId));
    await _saveToStorage();
  }

  Future<ScheduleActivity?> getActivityById(String id) async {
    try {
      return _activities.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}

