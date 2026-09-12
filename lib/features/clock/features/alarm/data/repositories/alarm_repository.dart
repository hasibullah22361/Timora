import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../../core/providers/shared_prefs_provider.dart';
import '../models/alarm_model.dart';

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AlarmRepository(prefs);
});

class AlarmRepository {
  static const String _keyAlarms = 'timora_clock_alarms';
  final SharedPreferences _prefs;

  AlarmRepository(this._prefs);

  List<AlarmModel> getAlarms() {
    try {
      final rawList = _prefs.getStringList(_keyAlarms);
      if (rawList == null || rawList.isEmpty) {
        // Initial defaults for realistic demonstration
        final defaults = [
          AlarmModel(
            id: 'alarm_default_morning',
            hour: 7,
            minute: 0,
            label: 'Wake Up',
            repeatDays: [1, 2, 3, 4, 5], // Mon-Fri
            sound: 'Default',
            vibration: true,
            isEnabled: true,
          ),
          AlarmModel(
            id: 'alarm_default_workout',
            hour: 18,
            minute: 30,
            label: 'Evening Workout',
            repeatDays: [1, 3, 5], // Mon, Wed, Fri
            sound: 'Bell',
            vibration: true,
            isEnabled: false,
          ),
        ];
        saveAll(defaults);
        return defaults;
      }

      final alarms = rawList.map((str) {
        return AlarmModel.fromJson(jsonDecode(str) as Map<String, dynamic>);
      }).toList();

      // Sort by hour and minute
      alarms.sort((a, b) {
        final cmpHour = a.hour.compareTo(b.hour);
        if (cmpHour != 0) return cmpHour;
        return a.minute.compareTo(b.minute);
      });
      return alarms;
    } catch (e) {
      return [];
    }
  }

  Future<void> saveAll(List<AlarmModel> alarms) async {
    final rawList = alarms.map((a) => jsonEncode(a.toJson())).toList();
    await _prefs.setStringList(_keyAlarms, rawList);
  }

  Future<void> saveAlarm(AlarmModel alarm) async {
    final alarms = getAlarms();
    final index = alarms.indexWhere((a) => a.id == alarm.id);
    if (index >= 0) {
      alarms[index] = alarm;
    } else {
      alarms.add(alarm);
    }
    await saveAll(alarms);
  }

  Future<void> deleteAlarm(String id) async {
    final alarms = getAlarms();
    alarms.removeWhere((a) => a.id == id);
    await saveAll(alarms);
  }

  Future<AlarmModel?> toggleAlarm(String id) async {
    final alarms = getAlarms();
    final index = alarms.indexWhere((a) => a.id == id);
    if (index >= 0) {
      final updated =
          alarms[index].copyWith(isEnabled: !alarms[index].isEnabled);
      alarms[index] = updated;
      await saveAll(alarms);
      return updated;
    }
    return null;
  }
}
