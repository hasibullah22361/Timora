import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/clock/features/stopwatch/domain/models/stopwatch_state.dart';

final stopwatchProvider =
    StateNotifierProvider<StopwatchNotifier, StopwatchState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StopwatchNotifier(prefs);
});

class StopwatchNotifier extends StateNotifier<StopwatchState> {
  static const String _keyStopwatch = 'timora_clock_stopwatch_state';
  final SharedPreferences _prefs;
  Timer? _displayTimer;

  StopwatchNotifier(this._prefs) : super(const StopwatchState()) {
    _loadState();
  }

  void _loadState() {
    try {
      final raw = _prefs.getString(_keyStopwatch);
      if (raw != null && raw.isNotEmpty) {
        final decoded =
            StopwatchState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        state = decoded;
        if (state.isRunning) {
          _startDisplayTimer();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveState() async {
    try {
      await _prefs.setString(_keyStopwatch, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void _startDisplayTimer() {
    _displayTimer?.cancel();
    // 33ms interval = ~30fps, perfect for hundredths of a second display without battery waste
    _displayTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted && state.isRunning) {
        // Trigger state refresh for UI rebuild
        state = state.copyWith();
      }
    });
  }

  void start() {
    if (state.isRunning) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    state = state.copyWith(
      isRunning: true,
      startEpoch: now,
    );
    _startDisplayTimer();
    _saveState();
  }

  void pause() {
    if (!state.isRunning) return;
    _displayTimer?.cancel();
    final total = state.currentElapsedMs;
    state = state.copyWith(
      isRunning: false,
      pausedElapsedMs: total,
      clearStartEpoch: true,
    );
    _saveState();
  }

  void resume() {
    start();
  }

  void reset() {
    _displayTimer?.cancel();
    state = const StopwatchState();
    _prefs.remove(_keyStopwatch);
  }

  void lap() {
    if (!state.isRunning && state.pausedElapsedMs == 0) return;
    final currentMs = state.currentElapsedMs;
    final lastTotal =
        state.laps.isNotEmpty ? state.laps.first.totalElapsedMs : 0;
    final split = currentMs - lastTotal;

    final newLap = LapModel(
      lapNumber: state.laps.length + 1,
      splitMs: split,
      totalElapsedMs: currentMs,
    );

    final updatedLaps = [newLap, ...state.laps];
    state = state.copyWith(laps: updatedLaps);
    _saveState();
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    super.dispose();
  }
}
