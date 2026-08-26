import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../models/schedule_activity.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ScheduleRepository(prefs);
});

class ScheduleRepository {
  static const String _storageKey = 'timora_schedule_activities_data';

  final SharedPreferences _prefs;
  final List<ScheduleActivity> _activities = [];

  ScheduleRepository(this._prefs) {
    _loadFromStorage();
  }

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
      if (activity.startTime.isBefore(existing.endTime) &&
          activity.endTime.isAfter(existing.startTime)) {
        throw Exception('These activities overlap with "${existing.title}".');
      }
    }
    _activities.add(activity);
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
      await _saveToStorage();
    }
  }

  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    await _saveToStorage();
  }
}

