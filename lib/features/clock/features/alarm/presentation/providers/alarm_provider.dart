import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/clock/features/alarm/data/models/alarm_model.dart';
import 'package:timora/features/clock/features/alarm/data/repositories/alarm_repository.dart';
import 'package:timora/features/clock/features/alarm/services/alarm_service.dart';

final alarmsListProvider =
    StateNotifierProvider<AlarmNotifier, List<AlarmModel>>((ref) {
  final repo = ref.watch(alarmRepositoryProvider);
  final service = ref.watch(alarmServiceProvider);
  return AlarmNotifier(repo, service);
});

final nextUpcomingAlarmProvider = Provider<AlarmModel?>((ref) {
  final alarms = ref.watch(alarmsListProvider);
  final active = alarms.where((a) => a.isEnabled).toList();
  if (active.isEmpty) return null;

  final now = DateTime.now();
  active.sort((a, b) =>
      a.nextTriggerDateTime(now).compareTo(b.nextTriggerDateTime(now)));
  return active.first;
});

class AlarmNotifier extends StateNotifier<List<AlarmModel>> {
  final AlarmRepository _repo;
  final AlarmService _service;

  AlarmNotifier(this._repo, this._service) : super([]) {
    loadAlarms();
  }

  void loadAlarms() {
    final list = _repo.getAlarms();
    state = list;
    // Keep scheduling in sync
    _service.syncAllAlarms(list);
  }

  Future<void> addAlarm(AlarmModel alarm) async {
    await _repo.saveAlarm(alarm);
    final updated = _repo.getAlarms();
    state = updated;
    if (alarm.isEnabled) {
      await _service.scheduleAlarm(alarm);
    }
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    await _repo.saveAlarm(alarm);
    final updated = _repo.getAlarms();
    state = updated;
    if (alarm.isEnabled) {
      await _service.scheduleAlarm(alarm);
    } else {
      await _service.cancelAlarm(alarm.id);
    }
  }

  Future<void> deleteAlarm(String id) async {
    await _repo.deleteAlarm(id);
    await _service.cancelAlarm(id);
    state = _repo.getAlarms();
  }

  Future<void> toggleAlarm(String id) async {
    final updated = await _repo.toggleAlarm(id);
    state = _repo.getAlarms();
    if (updated != null) {
      if (updated.isEnabled) {
        await _service.scheduleAlarm(updated);
      } else {
        await _service.cancelAlarm(updated.id);
      }
    }
  }

  Future<void> snooze(AlarmModel alarm, {int? minutes}) async {
    await _service.snoozeAlarm(alarm, snoozeMinutes: minutes);
  }
}
