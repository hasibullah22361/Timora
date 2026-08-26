import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/streak_models.dart';
import '../../focus/presentation/providers/focus_provider.dart';
import '../../focus/data/models/focus_session_model.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/data/repositories/schedule_repository.dart';
import '../../tasks/presentation/providers/task_provider.dart';

final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(ref);
});

class StreakService {
  final Ref _ref;
  
  // Temporary hardcoded freezes for proof-of-concept
  final List<StreakFreezeModel> _usedFreezes = []; 
  int _availableFreezes = 3;

  StreakService(this._ref);

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<StreakModel> calculateStreak(StreakType type, {String? targetId}) async {
    final Set<DateTime> activeDates = {};

    if (type == StreakType.routine) {
      final allActivities = await _ref.read(scheduleRepositoryProvider).getAllActivities();
      for (var a in allActivities) {
        if (a.status == ActivityStatus.completed) {
          activeDates.add(_normalizeDate(a.date));
        }
      }
    } else if (type == StreakType.focus) {
      final allSessions = await _ref.read(allFocusSessionsProvider.future);
      for (var s in allSessions) {
        if (s.status == FocusSessionStatus.completed && s.actualDurationSeconds > 0) {
          activeDates.add(_normalizeDate(s.createdAt));
        }
      }
    } else if (type == StreakType.task) {
      final allTasks = await _ref.read(allTasksProvider.future);
      for (var t in allTasks) {
        if (t.isCompleted && (t.completedAt != null || t.updatedAt != null)) {
          activeDates.add(_normalizeDate(t.completedAt ?? t.updatedAt!));
        }
      }
    }

    final today = _normalizeDate(DateTime.now());
    
    // Calculate current streak backwards from today
    int currentCount = 0;
    DateTime? startDate;
    DateTime? lastActive;
    Map<DateTime, String> history = {};
    
    DateTime checkDate = today;
    
    // Check if active today
    if (activeDates.contains(checkDate)) {
      currentCount++;
      lastActive = checkDate;
      startDate = checkDate;
      history[checkDate] = 'completed';
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else {
      // If not active today, streak isn't broken yet (user still has time today).
      // But we mark it pending.
      history[checkDate] = 'pending';
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Iterate backwards
    while (true) {
      if (activeDates.contains(checkDate)) {
        currentCount++;
        lastActive ??= checkDate;
        startDate = checkDate;
        history[checkDate] = 'completed';
      } else {
        // Check for freeze
        bool hasFreeze = _usedFreezes.any((f) => f.date == checkDate && f.streakId == type.name);
        
        if (hasFreeze) {
          history[checkDate] = 'frozen';
        } else if (_availableFreezes > 0 && currentCount > 0) {
          // Auto freeze
          _usedFreezes.add(StreakFreezeModel(
            id: const Uuid().v4(),
            streakId: type.name,
            date: checkDate,
            reason: 'Auto-freeze',
            createdAt: DateTime.now(),
          ));
          _availableFreezes--;
          history[checkDate] = 'frozen';
        } else {
          // Streak broken
          history[checkDate] = 'missed';
          break;
        }
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Populate a full 7-day history for the calendar
    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      if (!history.containsKey(d)) {
         history[d] = 'missed';
      }
    }

    // Calculate best streak (simplified for this MVP: just setting it to current if it's the highest we've seen)
    // A true best streak calculation would iterate the entire Set<DateTime> looking for the longest consecutive sequence.
    int bestCount = currentCount; // Placeholder for Best calculation

    return StreakModel(
      id: type.name,
      type: type,
      targetId: targetId,
      currentCount: currentCount,
      bestCount: bestCount,
      currentStartDate: startDate,
      lastActiveDate: lastActive,
      updatedAt: DateTime.now(),
      recentHistory: history,
    );
  }

  StreakSettingsModel getSettings() {
    return StreakSettingsModel(
      availableFreezes: _availableFreezes,
    );
  }
}
