import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../routine/data/models/routine.dart';
import '../../routine/data/models/routine_block.dart';
import '../../routine/data/repositories/routine_repository.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/data/repositories/schedule_repository.dart';
import '../data/models/productivity_event_model.dart';
import '../data/repositories/productivity_event_repository.dart';

class RoutineScoreBreakdown {
  final String routineId;
  final String routineName;
  final String icon;
  final int expectedCount;
  final int completedCount;
  final int skippedCount;
  final double scorePercentage;

  const RoutineScoreBreakdown({
    required this.routineId,
    required this.routineName,
    required this.icon,
    required this.expectedCount,
    required this.completedCount,
    this.skippedCount = 0,
    required this.scorePercentage,
  });
}

class RoutineCategoryScore {
  final String category;
  final int expectedCount;
  final int completedCount;
  final double scorePercentage;

  const RoutineCategoryScore({
    required this.category,
    required this.expectedCount,
    required this.completedCount,
    required this.scorePercentage,
  });
}

class SkippedRoutineItem {
  final String blockId;
  final String title;
  final String routineName;
  final int skipCount;

  const SkippedRoutineItem({
    required this.blockId,
    required this.title,
    required this.routineName,
    required this.skipCount,
  });
}

class RoutineConsistencyResult {
  final double overallScore; // 0 - 100
  final double previousPeriodScore;
  final double changePercentage;
  final int totalExpected;
  final int totalCompleted;
  final int totalSkipped;
  final bool hasSufficientData;
  final List<RoutineScoreBreakdown> routineBreakdowns;
  final RoutineScoreBreakdown? strongestRoutine;
  final RoutineScoreBreakdown? weakestRoutine;
  final List<SkippedRoutineItem> frequentlySkippedItems;

  const RoutineConsistencyResult({
    required this.overallScore,
    required this.previousPeriodScore,
    required this.changePercentage,
    required this.totalExpected,
    required this.totalCompleted,
    this.totalSkipped = 0,
    this.hasSufficientData = true,
    required this.routineBreakdowns,
    this.strongestRoutine,
    this.weakestRoutine,
    this.frequentlySkippedItems = const [],
  });

  List<RoutineCategoryScore> get categoryBreakdown => routineBreakdowns
      .map((r) => RoutineCategoryScore(
            category: r.icon.isNotEmpty ? '${r.icon} ${r.routineName}' : r.routineName,
            expectedCount: r.expectedCount,
            completedCount: r.completedCount,
            scorePercentage: r.scorePercentage,
          ))
      .toList();

  factory RoutineConsistencyResult.empty() {
    return const RoutineConsistencyResult(
      overallScore: 0.0,
      previousPeriodScore: 0.0,
      changePercentage: 0.0,
      totalExpected: 0,
      totalCompleted: 0,
      totalSkipped: 0,
      hasSufficientData: false,
      routineBreakdowns: [],
    );
  }
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

  Future<RoutineConsistencyResult> calculateWeeklyConsistency([DateTime? customNow]) async {
    final now = customNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday as start of current week
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final prevWeekStart = currentWeekStart.subtract(const Duration(days: 7));
    final prevWeekEnd = currentWeekStart.subtract(const Duration(seconds: 1));

    final routineRepo = _ref.read(routineRepositoryProvider);
    final scheduleRepo = _ref.read(scheduleRepositoryProvider);
    final eventRepo = _ref.read(productivityEventRepositoryProvider);

    final routines = await routineRepo.getAllRoutines();
    final allBlocks = await routineRepo.getAllBlocks();
    final allEvents = await eventRepo.getAllEvents();

    if (routines.isEmpty || allBlocks.isEmpty) {
      return RoutineConsistencyResult.empty();
    }

    // Map blockId -> routine
    final blockRoutineMap = <String, Routine>{};
    final blockMap = <String, RoutineBlock>{};
    final routineBlocksMap = <String, List<RoutineBlock>>{};

    for (final r in routines) {
      routineBlocksMap[r.id] = [];
    }

    for (final b in allBlocks) {
      blockMap[b.id] = b;
      final routine = routines.where((r) => r.id == b.routineId).firstOrNull;
      if (routine != null) {
        blockRoutineMap[b.id] = routine;
        routineBlocksMap[routine.id]?.add(b);
      }
    }

    // Collect schedule activities for the current week (from Monday up to today)
    final currentWeekActivities = <ScheduleActivity>[];
    for (int dayOffset = 0; dayOffset < today.weekday; dayOffset++) {
      final date = currentWeekStart.add(Duration(days: dayOffset));
      try {
        final acts = await scheduleRepo.getActivitiesForDate(date);
        currentWeekActivities.addAll(acts.where((a) => a.routineBlockId != null));
      } catch (_) {}
    }

    // Collect schedule activities for previous week
    final prevWeekActivities = <ScheduleActivity>[];
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = prevWeekStart.add(Duration(days: dayOffset));
      try {
        final acts = await scheduleRepo.getActivitiesForDate(date);
        prevWeekActivities.addAll(acts.where((a) => a.routineBlockId != null));
      } catch (_) {}
    }

    // Tally expected occurrences per routine for current week
    final expectedCounts = <String, int>{};
    for (int dayOffset = 0; dayOffset < today.weekday; dayOffset++) {
      final date = currentWeekStart.add(Duration(days: dayOffset));
      for (final r in routines) {
        if (!r.enabled) continue;
        if (r.isActiveOn(date)) {
          final enabledBlocks = (routineBlocksMap[r.id] ?? []).where((b) => b.enabled).length;
          expectedCounts[r.id] = (expectedCounts[r.id] ?? 0) + (enabledBlocks > 0 ? enabledBlocks : 1);
        }
      }
    }

    // Tally actual completions and skips per routine
    final completedCounts = <String, int>{};
    final skippedCounts = <String, int>{};
    final blockSkipCounts = <String, int>{};

    for (final act in currentWeekActivities) {
      final blockId = act.routineBlockId;
      if (blockId == null) continue;
      final routine = blockRoutineMap[blockId];
      final routineId = routine?.id ?? '';

      if (act.status == ActivityStatus.completed) {
        completedCounts[routineId] = (completedCounts[routineId] ?? 0) + 1;
      } else if (act.status == ActivityStatus.skipped) {
        skippedCounts[routineId] = (skippedCounts[routineId] ?? 0) + 1;
        blockSkipCounts[blockId] = (blockSkipCounts[blockId] ?? 0) + 1;
      }
    }

    // Also factor in logged productivity events
    for (final e in allEvents) {
      if (e.timestamp.isAfter(currentWeekStart) && e.timestamp.isBefore(now)) {
        if (e.eventType == ProductivityEventType.routineCompleted) {
          final rid = e.entityId;
          // Avoid double counting if already captured by activity status
          if ((completedCounts[rid] ?? 0) == 0) {
            completedCounts[rid] = (completedCounts[rid] ?? 0) + 1;
          }
        }
      }
    }

    int totalExpected = expectedCounts.values.fold(0, (sum, val) => sum + val);
    int totalCompleted = completedCounts.values.fold(0, (sum, val) => sum + val);
    int totalSkipped = skippedCounts.values.fold(0, (sum, val) => sum + val);

    if (totalExpected == 0 && totalCompleted == 0) {
      return RoutineConsistencyResult.empty();
    }

    // Ensure totalExpected is at least totalCompleted to prevent percentages > 100%
    if (totalCompleted > totalExpected) {
      totalExpected = totalCompleted;
    }

    final overall = totalExpected > 0
        ? ((totalCompleted / totalExpected) * 100).clamp(0.0, 100.0)
        : 0.0;

    // Previous week calculation
    int prevExpected = 0;
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = prevWeekStart.add(Duration(days: dayOffset));
      for (final r in routines) {
        if (!r.enabled) continue;
        if (r.isActiveOn(date)) {
          final enabledBlocks = (routineBlocksMap[r.id] ?? []).where((b) => b.enabled).length;
          prevExpected += (enabledBlocks > 0 ? enabledBlocks : 1);
        }
      }
    }

    int prevCompleted = 0;
    for (final act in prevWeekActivities) {
      if (act.status == ActivityStatus.completed) {
        prevCompleted++;
      }
    }

    for (final e in allEvents) {
      if (e.timestamp.isAfter(prevWeekStart) && e.timestamp.isBefore(prevWeekEnd)) {
        if (e.eventType == ProductivityEventType.routineCompleted) {
          if (prevCompleted == 0) prevCompleted++;
        }
      }
    }

    final prevScore = prevExpected > 0
        ? ((prevCompleted / prevExpected) * 100).clamp(0.0, 100.0)
        : 0.0;

    final change = overall - prevScore;

    // Build real breakdowns per active routine
    final breakdowns = <RoutineScoreBreakdown>[];
    for (final r in routines) {
      final exp = expectedCounts[r.id] ?? 0;
      final comp = completedCounts[r.id] ?? 0;
      final skip = skippedCounts[r.id] ?? 0;

      if (exp > 0 || comp > 0) {
        final realExp = exp > comp ? exp : comp;
        final score = realExp > 0 ? ((comp / realExp) * 100).clamp(0.0, 100.0) : 0.0;
        breakdowns.add(RoutineScoreBreakdown(
          routineId: r.id,
          routineName: r.name,
          icon: r.icon,
          expectedCount: realExp,
          completedCount: comp,
          skippedCount: skip,
          scorePercentage: score,
        ));
      }
    }

    breakdowns.sort((a, b) => b.scorePercentage.compareTo(a.scorePercentage));

    final strongest = breakdowns.isNotEmpty ? breakdowns.first : null;
    final weakest = (breakdowns.length > 1 && breakdowns.last.scorePercentage < (strongest?.scorePercentage ?? 100))
        ? breakdowns.last
        : null;

    // Frequently skipped items
    final frequentlySkipped = <SkippedRoutineItem>[];
    blockSkipCounts.forEach((blockId, count) {
      if (count > 0) {
        final block = blockMap[blockId];
        final routine = blockRoutineMap[blockId];
        frequentlySkipped.add(SkippedRoutineItem(
          blockId: blockId,
          title: block?.title ?? 'Routine Item',
          routineName: routine?.name ?? 'Routine',
          skipCount: count,
        ));
      }
    });

    frequentlySkipped.sort((a, b) => b.skipCount.compareTo(a.skipCount));

    return RoutineConsistencyResult(
      overallScore: overall,
      previousPeriodScore: prevScore,
      changePercentage: change,
      totalExpected: totalExpected,
      totalCompleted: totalCompleted,
      totalSkipped: totalSkipped,
      hasSufficientData: totalExpected >= 2 || totalCompleted >= 2,
      routineBreakdowns: breakdowns,
      strongestRoutine: strongest,
      weakestRoutine: weakest,
      frequentlySkippedItems: frequentlySkipped,
    );
  }
}
