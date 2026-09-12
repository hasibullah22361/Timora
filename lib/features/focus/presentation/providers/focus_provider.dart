import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:timora/features/focus/data/models/focus_session_model.dart';
import 'package:timora/features/focus/data/models/focus_stats_model.dart';
import 'package:timora/features/focus/data/repositories/focus_repository.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import '../../../notifications/application/notification_service.dart';
import '../../../widget/services/widget_update_service.dart';
import '../../../analytics/services/insights_engine_service.dart';
import '../../../analytics/services/report_generator_service.dart';
import '../../../analytics/presentation/providers/analytics_provider.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/schedule/presentation/providers/schedule_provider.dart';
import 'package:timora/features/daily_plan/data/models/planned_task_block_model.dart';
import 'package:timora/features/daily_plan/data/repositories/daily_plan_repository.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';

class FocusTimerState {
  final FocusSessionModel? activeSession;
  final int elapsedSeconds;
  
  FocusTimerState({
    this.activeSession,
    this.elapsedSeconds = 0,
  });
  
  int get remainingSeconds {
    if (activeSession == null) return 0;
    final remaining = activeSession!.plannedDurationSeconds - elapsedSeconds;
    return remaining > 0 ? remaining : 0;
  }
}

class FocusTimerNotifier extends StateNotifier<FocusTimerState> {
  final FocusRepository _repo;
  final Ref _ref;
  Timer? _uiTimer;

  FocusTimerNotifier(this._repo, this._ref) : super(FocusTimerState()) {
    _restoreSession();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final session = await _repo.getActiveSession();
    if (session != null) {
      state = FocusTimerState(activeSession: session);
      _recalculateElapsed();
      if (session.status == FocusSessionStatus.running || session.status == FocusSessionStatus.breakTime) {
        _startUiTimer();
      }
    }
  }

  void _recalculateElapsed() {
    if (state.activeSession == null) return;
    
    final s = state.activeSession!;
    int elapsed = s.totalPausedDurationSeconds;
    
    if (s.status == FocusSessionStatus.running || s.status == FocusSessionStatus.breakTime) {
      final diff = DateTime.now().difference(s.startedAt).inSeconds;
      // We must subtract the total paused duration from the diff
      // Wait, if it was paused in the past, startedAt remains the original start time.
      // So total elapsed active time = (now - startedAt) - totalPausedTime.
      elapsed = diff - s.totalPausedDurationSeconds;
    }
    
    // Check if we passed the end implicitly while backgrounded
    if (s.plannedDurationSeconds - elapsed <= 0 && (s.status == FocusSessionStatus.running || s.status == FocusSessionStatus.breakTime)) {
      _finishSessionAutomatically();
      return;
    }

    state = FocusTimerState(activeSession: s, elapsedSeconds: elapsed);
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recalculateElapsed();
    });
  }

  Future<void> startSession({
    required int durationMinutes,
    FocusSessionMode mode = FocusSessionMode.focus,
    String? taskId,
    String? projectId,
    String? goalId,
    String? milestoneId,
    String? scheduleActivityId,
    String? plannedTaskBlockId,
  }) async {
    if (state.activeSession != null && (state.activeSession!.status == FocusSessionStatus.running || state.activeSession!.status == FocusSessionStatus.paused)) {
      // Allow only one
      return;
    }

    final session = FocusSessionModel(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
      plannedDurationSeconds: durationMinutes * 60,
      mode: mode,
      taskId: taskId,
      projectId: projectId,
      goalId: goalId,
      milestoneId: milestoneId,
      scheduleActivityId: scheduleActivityId,
      plannedTaskBlockId: plannedTaskBlockId,
      createdAt: DateTime.now(),
    );

    await _repo.saveSession(session);
    state = FocusTimerState(activeSession: session, elapsedSeconds: 0);
    _startUiTimer();
    _scheduleNotification(session.plannedDurationSeconds);
    _updateWidgets();
  }

  Future<void> pauseSession() async {
    if (state.activeSession == null || state.activeSession!.status != FocusSessionStatus.running) return;
    
    _uiTimer?.cancel();
    _cancelNotification();
    
    final s = state.activeSession!.copyWith(
      status: FocusSessionStatus.paused,
      pausedAt: DateTime.now(),
    );
    
    await _repo.saveSession(s);
    state = FocusTimerState(activeSession: s, elapsedSeconds: state.elapsedSeconds);
    _updateWidgets();
  }

  Future<void> resumeSession() async {
    if (state.activeSession == null || state.activeSession!.status != FocusSessionStatus.paused) return;
    
    final pausedTime = DateTime.now().difference(state.activeSession!.pausedAt!).inSeconds;
    
    final s = state.activeSession!.copyWith(
      status: FocusSessionStatus.running,
      pausedAt: null, // clear pausedAt
      totalPausedDurationSeconds: state.activeSession!.totalPausedDurationSeconds + pausedTime,
    );
    
    await _repo.saveSession(s);
    state = FocusTimerState(activeSession: s, elapsedSeconds: state.elapsedSeconds);
    _startUiTimer();
    _scheduleNotification(state.remainingSeconds);
    _updateWidgets();
  }

  Future<void> _updateLinkedEntities(FocusSessionModel finished) async {
    try {
      if (finished.scheduleActivityId != null && finished.scheduleActivityId!.isNotEmpty) {
        final scheduleRepo = _ref.read(scheduleRepositoryProvider);
        final act = await scheduleRepo.getActivityById(finished.scheduleActivityId!);
        if (act != null) {
          final plannedSecs = act.endTime.difference(act.startTime).inSeconds.abs();
          if (finished.actualDurationSeconds >= plannedSecs || finished.status == FocusSessionStatus.completed) {
            final updated = act.copyWith(status: ActivityStatus.completed, completedAt: DateTime.now());
            await scheduleRepo.updateActivity(updated);
            _ref.invalidate(scheduleActivitiesProvider);
            _ref.invalidate(scheduleActivitiesByDateProvider(act.date));
          }
        }
      }

      if (finished.plannedTaskBlockId != null && finished.plannedTaskBlockId!.isNotEmpty) {
        final dailyPlanRepo = _ref.read(dailyPlanRepositoryProvider);
        final block = await dailyPlanRepo.getBlockById(finished.plannedTaskBlockId!);
        if (block != null) {
          if (finished.actualDurationSeconds >= block.estimatedDurationSeconds || finished.status == FocusSessionStatus.completed) {
            final updated = block.copyWith(status: PlannedBlockStatus.completed);
            await dailyPlanRepo.saveBlock(updated);
          }
        }
      }

      final today = DateTime.now();
      final dateOnly = DateTime(today.year, today.month, today.day);
      _ref.invalidate(dailyPlanProvider(dateOnly));
      _ref.invalidate(timelineProvider(dateOnly));
    } catch (_) {}
  }

  Future<void> _finishSessionAutomatically() async {
    _uiTimer?.cancel();
    final s = state.activeSession!;
    final finished = s.copyWith(
      status: FocusSessionStatus.completed,
      endedAt: DateTime.now(),
      actualDurationSeconds: s.plannedDurationSeconds,
    );
    await _repo.saveSession(finished);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'focus_sessions',
      entityId: finished.id,
      operation: SyncOperation.create,
    );
    state = FocusTimerState(activeSession: finished, elapsedSeconds: s.plannedDurationSeconds);
    await _updateLinkedEntities(finished);
    _ref.invalidate(todayFocusSessionsProvider);
    _ref.invalidate(allFocusSessionsProvider);
    _ref.invalidate(focusStatsProvider);
    try {
      _ref.invalidate(timoraInsightsProvider);
      _ref.invalidate(todayTopInsightProvider);
      _ref.invalidate(analyticsInsightsProvider);
      _ref.invalidate(dailyReportProvider);
      _ref.invalidate(weeklyReportProvider);
      _ref.invalidate(monthlyReportProvider);
    } catch (_) {}
    _ref.read(syncServiceProvider).autoSync();
    _updateWidgets();
  }

  Future<FocusSessionModel?> stopSession() async {
    if (state.activeSession == null) return null;
    _uiTimer?.cancel();
    _cancelNotification();
    
    final s = state.activeSession!;
    final now = DateTime.now();
    int actualDurationSeconds;
    if (s.status == FocusSessionStatus.paused && s.pausedAt != null) {
      actualDurationSeconds = s.pausedAt!.difference(s.startedAt).inSeconds - s.totalPausedDurationSeconds;
    } else {
      actualDurationSeconds = now.difference(s.startedAt).inSeconds - s.totalPausedDurationSeconds;
    }
    if (actualDurationSeconds < 0) actualDurationSeconds = 0;

    final finished = s.copyWith(
      status: FocusSessionStatus.completed,
      endedAt: now,
      actualDurationSeconds: actualDurationSeconds,
    );
    await _repo.saveSession(finished);
    await _ref.read(syncRepositoryProvider).enqueueChange(
      entityType: 'focus_sessions',
      entityId: finished.id,
      operation: SyncOperation.create,
    );
    state = FocusTimerState(activeSession: finished, elapsedSeconds: actualDurationSeconds);
    await _updateLinkedEntities(finished);
    _ref.invalidate(todayFocusSessionsProvider);
    _ref.invalidate(allFocusSessionsProvider);
    _ref.invalidate(focusStatsProvider);
    try {
      _ref.invalidate(timoraInsightsProvider);
      _ref.invalidate(todayTopInsightProvider);
      _ref.invalidate(analyticsInsightsProvider);
      _ref.invalidate(dailyReportProvider);
      _ref.invalidate(weeklyReportProvider);
      _ref.invalidate(monthlyReportProvider);
    } catch (_) {}
    _ref.read(syncServiceProvider).autoSync();
    _updateWidgets();
    return finished;
  }

  Future<void> finishSessionEarly() async {
    await stopSession();
  }

  Future<void> cancelSession() async {
    if (state.activeSession == null) return;
    _uiTimer?.cancel();
    _cancelNotification();
    
    final s = state.activeSession!.copyWith(
      status: FocusSessionStatus.cancelled,
      endedAt: DateTime.now(),
    );
    await _repo.saveSession(s);
    state = FocusTimerState(); // Clear UI
    _updateWidgets();
  }

  void _updateWidgets() {
    try {
      _ref.read(widgetUpdateServiceProvider).updateWidgets();
    } catch (_) {}
  }
  
  void _scheduleNotification(int secondsDelay) {
    if (secondsDelay <= 0) return;
    _ref.read(notificationServiceProvider).scheduleNotification(
      state.activeSession!.id.hashCode,
      'Focus session complete 🎉',
      'Great job staying focused!',
      DateTime.now().add(Duration(seconds: secondsDelay)),
    );
  }
  
  void _cancelNotification() {
    if (state.activeSession != null) {
      _ref.read(notificationServiceProvider).cancelNotification(state.activeSession!.id.hashCode);
    }
  }
}

final focusTimerProvider = StateNotifierProvider<FocusTimerNotifier, FocusTimerState>((ref) {
  return FocusTimerNotifier(ref.watch(focusRepositoryProvider), ref);
});

final todayFocusSessionsProvider = FutureProvider<List<FocusSessionModel>>((ref) async {
  return ref.watch(focusRepositoryProvider).getSessionsForToday();
});

final allFocusSessionsProvider = FutureProvider<List<FocusSessionModel>>((ref) async {
  return ref.watch(focusRepositoryProvider).getAllCompletedSessions();
});

final focusStatsProvider = FutureProvider<FocusStatsModel>((ref) async {
  final sessions = await ref.watch(allFocusSessionsProvider.future);
  return FocusStatsModel.fromSessions(sessions);
});
