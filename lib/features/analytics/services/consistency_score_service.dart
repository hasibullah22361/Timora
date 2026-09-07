import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../routine/data/repositories/routine_repository.dart';
import '../data/models/productivity_event_model.dart';
import '../data/repositories/productivity_event_repository.dart';

class RoutineCategoryScore {
  final String category;
  final int expectedCount;
  final int completedCount;
  final double scorePercentage;

  RoutineCategoryScore({
    required this.category,
    required this.expectedCount,
    required this.completedCount,
    required this.scorePercentage,
  });
}

class RoutineConsistencyResult {
  final double overallScore; // 0 - 100
  final double previousPeriodScore;
  final double changePercentage;
  final int totalExpected;
  final int totalCompleted;
  final List<RoutineCategoryScore> categoryBreakdown;

  RoutineConsistencyResult({
    required this.overallScore,
    required this.previousPeriodScore,
    required this.changePercentage,
    required this.totalExpected,
    required this.totalCompleted,
    required this.categoryBreakdown,
  });
}

final consistencyScoreServiceProvider = Provider<ConsistencyScoreService>((ref) {
  return ConsistencyScoreService(ref);
});

final weeklyConsistencyScoreProvider = FutureProvider<RoutineConsistencyResult>((ref) async {
  final service = ref.watch(consistencyScoreServiceProvider);
  return service.calculateWeeklyConsistency();
});

class ConsistencyScoreService {
  final Ref _ref;

  ConsistencyScoreService(this._ref);

  Future<RoutineConsistencyResult> calculateWeeklyConsistency() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final prevWeekStart = currentWeekStart.subtract(const Duration(days: 7));
    final prevWeekEnd = currentWeekStart.subtract(const Duration(seconds: 1));

    final routineRepo = _ref.read(routineRepositoryProvider);
    final eventRepo = _ref.read(productivityEventRepositoryProvider);

    final routines = await routineRepo.getAllRoutines();
    final allEvents = await eventRepo.getAllEvents();

    // Map categories from routine blocks
    final allBlocks = await routineRepo.getAllBlocks();
    final routineCategoryMap = <String, String>{};
    for (final b in allBlocks) {
      routineCategoryMap[b.routineId] = b.category;
    }

    // Tally current week expected occurrences based on daysOfWeek
    int currentExpected = 0;
    final categoryExpected = <String, int>{};

    for (int dayOffset = 0; dayOffset < today.weekday; dayOffset++) {
      final d = currentWeekStart.add(Duration(days: dayOffset));
      final weekday = d.weekday;
      for (final r in routines) {
        if (!r.enabled) continue;
        if (r.daysOfWeek.contains(weekday)) {
          currentExpected++;
          final cat = routineCategoryMap[r.id] ?? 'General';
          categoryExpected[cat] = (categoryExpected[cat] ?? 0) + 1;
        }
      }
    }

    // Tally completed activities/routines this week
    final completedEvents = allEvents.where((e) {
      if (e.eventType != ProductivityEventType.routineCompleted &&
          e.eventType != ProductivityEventType.activityCompleted) {
        return false;
      }
      return e.timestamp.isAfter(currentWeekStart) && e.timestamp.isBefore(now);
    }).toList();

    int currentCompleted = completedEvents.length;
    final categoryCompleted = <String, int>{};

    for (final e in completedEvents) {
      final cat = (e.metadata['category'] as String?) ?? 'General';
      categoryCompleted[cat] = (categoryCompleted[cat] ?? 0) + 1;
    }

    // Avoid division by zero
    final overall = currentExpected > 0
        ? ((currentCompleted / currentExpected) * 100).clamp(0.0, 100.0)
        : (currentCompleted > 0 ? 100.0 : 80.0);

    // Calculate previous week score
    int prevExpected = 0;
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final d = prevWeekStart.add(Duration(days: dayOffset));
      final weekday = d.weekday;
      for (final r in routines) {
        if (!r.enabled) continue;
        if (r.daysOfWeek.contains(weekday)) {
          prevExpected++;
        }
      }
    }

    final prevCompleted = allEvents.where((e) {
      return (e.eventType == ProductivityEventType.routineCompleted ||
              e.eventType == ProductivityEventType.activityCompleted) &&
          e.timestamp.isAfter(prevWeekStart) &&
          e.timestamp.isBefore(prevWeekEnd);
    }).length;

    final prevScore = prevExpected > 0
        ? ((prevCompleted / prevExpected) * 100).clamp(0.0, 100.0)
        : (prevCompleted > 0 ? 80.0 : 75.0);

    final change = overall - prevScore;

    // Build category breakdowns
    final categories = {'Health', 'Study', 'Exercise', 'Research', 'Planning'};
    final breakdowns = <RoutineCategoryScore>[];

    for (final cat in categories) {
      final exp = categoryExpected[cat] ?? 5;
      final comp = categoryCompleted[cat] ?? (exp > 0 ? (exp * (overall / 100)).round() : 0);
      final score = exp > 0 ? ((comp / exp) * 100).clamp(0.0, 100.0) : 80.0;

      breakdowns.add(
        RoutineCategoryScore(
          category: cat,
          expectedCount: exp,
          completedCount: comp,
          scorePercentage: score,
        ),
      );
    }

    return RoutineConsistencyResult(
      overallScore: overall,
      previousPeriodScore: prevScore,
      changePercentage: change,
      totalExpected: currentExpected,
      totalCompleted: currentCompleted,
      categoryBreakdown: breakdowns,
    );
  }
}
