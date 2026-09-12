import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/notifications/application/notification_service.dart';
import 'package:timora/features/clock/features/timer/domain/models/timer_state.dart';

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final notifService = ref.watch(notificationServiceProvider);
  return TimerNotifier(prefs, notifService);
});

class TimerNotifier extends StateNotifier<TimerState> {
  static const String _keyTimer = 'timora_clock_timer_state';
  static const int _timerNotificationId = 99999;

  final SharedPreferences _prefs;
  final NotificationService _notificationService;
  Timer? _countdownTimer;

  TimerNotifier(this._prefs, this._notificationService)
      : super(const TimerState()) {
    _loadState();
  }

  void _loadState() {
    try {
      final raw = _prefs.getString(_keyTimer);
      if (raw != null && raw.isNotEmpty) {
        final saved =
            TimerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (saved.status == TimerStatus.running && saved.endEpoch != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now >= saved.endEpoch!) {
            state = saved.copyWith(
              remainingSeconds: 0,
              status: TimerStatus.finished,
              clearEpochs: true,
            );
          } else {
            final remaining = ((saved.endEpoch! - now) / 1000).ceil();
            state = saved.copyWith(remainingSeconds: remaining);
            _startTicker();
          }
        } else {
          state = saved;
        }
      }
    } catch (_) {}
  }

  Future<void> _saveState() async {
    try {
      await _prefs.setString(_keyTimer, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void _startTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !state.isRunning || state.endEpoch == null) {
        _countdownTimer?.cancel();
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final diffMs = state.endEpoch! - now;
      final remaining = (diffMs / 1000).ceil();

      if (remaining <= 0) {
        _countdownTimer?.cancel();
        state = state.copyWith(
          remainingSeconds: 0,
          status: TimerStatus.finished,
          clearEpochs: true,
        );
        _saveState();
      } else if (remaining != state.remainingSeconds) {
        state = state.copyWith(remainingSeconds: remaining);
      }
    });
  }

  Future<void> start() async {
    if (state.remainingSeconds <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final end = now + (state.remainingSeconds * 1000);

    state = state.copyWith(
      status: TimerStatus.running,
      startEpoch: now,
      endEpoch: end,
    );

    // Schedule background notification
    final scheduledDate = DateTime.fromMillisecondsSinceEpoch(end);
    final payload = jsonEncode({
      'type': 'timer',
      'totalSeconds': state.totalSeconds,
    });

    await _notificationService.scheduleNotification(
      _timerNotificationId,
      '⏳ Timora Timer',
      'Your ${TimerState.formatSeconds(state.totalSeconds)} timer is finished.',
      scheduledDate,
      channelId: 'timora_timer',
      payload: payload,
      playSound: true,
      enableVibration: true,
    );

    _startTicker();
    _saveState();
  }

  Future<void> pause() async {
    if (!state.isRunning) return;
    _countdownTimer?.cancel();

    // Cancel scheduled notification since timer is paused
    await _notificationService.cancelNotification(_timerNotificationId);

    state = state.copyWith(
      status: TimerStatus.paused,
      clearEpochs: true,
    );
    _saveState();
  }

  Future<void> resume() async {
    await start();
  }

  Future<void> reset() async {
    _countdownTimer?.cancel();
    await _notificationService.cancelNotification(_timerNotificationId);

    state = state.copyWith(
      remainingSeconds: state.totalSeconds,
      status: TimerStatus.initial,
      clearEpochs: true,
    );
    _saveState();
  }

  Future<void> cancelTimer() async {
    await reset();
  }

  Future<void> setPreset(int seconds) async {
    _countdownTimer?.cancel();
    await _notificationService.cancelNotification(_timerNotificationId);

    state = TimerState(
      totalSeconds: seconds,
      remainingSeconds: seconds,
      status: TimerStatus.initial,
    );
    _saveState();
  }

  Future<void> setCustomDuration(int hours, int minutes, int seconds) async {
    final total = (hours * 3600) + (minutes * 60) + seconds;
    if (total > 0) {
      await setPreset(total);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
