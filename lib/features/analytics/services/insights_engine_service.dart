import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/analytics_models.dart';
import '../data/models/productivity_event_model.dart';
import '../data/repositories/productivity_event_repository.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../focus/data/models/focus_session_model.dart';
import '../../focus/presentation/providers/focus_provider.dart';
import 'consistency_score_service.dart';

final insightsEngineServiceProvider = Provider<InsightsEngineService>((ref) {
  return InsightsEngineService(ref);
});

final timoraInsightsProvider = FutureProvider.family<List<AnalyticsInsight>, AnalyticsPeriod>((ref, period) async {
  final service = ref.watch(insightsEngineServiceProvider);
  return service.generateInsights(period);
});

final todayTopInsightProvider = FutureProvider<AnalyticsInsight?>((ref) async {
  final service = ref.watch(insightsEngineServiceProvider);
  final insights = await service.generateInsights(AnalyticsPeriod.today);
  if (insights.isNotEmpty) return insights.first;
  // Fallback to 7-day top insight if today is empty
  final weekly = await service.generateInsights(AnalyticsPeriod.last7Days);
  return weekly.isNotEmpty ? weekly.first : null;
});

class InsightsEngineService {
  final Ref _ref;

  InsightsEngineService(this._ref);

  DateTimeRange _getDateRange(AnalyticsPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);

    switch (period) {
      case AnalyticsPeriod.today:
        return DateTimeRange(start: today, end: endOfToday);
      case AnalyticsPeriod.last7Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: endOfToday,
        );
      case AnalyticsPeriod.last30Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: endOfToday,
        );
      case AnalyticsPeriod.last90Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 89)),
          end: endOfToday,
        );
      case AnalyticsPeriod.thisWeek:
        final daysToSubtract = today.weekday - 1;
        final startOfWeek = today.subtract(Duration(days: daysToSubtract));
        final endOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 7, 23, 59, 59);
        return DateTimeRange(start: startOfWeek, end: endOfWeek);
      case AnalyticsPeriod.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
    }
  }

  /// Generates a comprehensive list of intelligent, actionable insights grounded in real data.
  Future<List<AnalyticsInsight>> generateInsights(AnalyticsPeriod period) async {
    final range = _getDateRange(period);
    final insights = <AnalyticsInsight>[];

    // Fetch real data from existing repositories
    final taskRepo = _ref.read(taskRepositoryProvider);
    final eventRepo = _ref.read(productivityEventRepositoryProvider);
    final consistencyService = _ref.read(consistencyScoreServiceProvider);

    final allTasks = await taskRepo.getTasks();
    final allEvents = await eventRepo.getAllEvents();
    final allFocusSessions = await _ref.read(allFocusSessionsProvider.future);

    // 1. Productivity Pattern Detection (Peak cognitive hours from real tasks + focus)
    final productivityInsight = _detectProductivityPattern(
      range: range,
      tasks: allTasks,
      focusSessions: allFocusSessions,
    );
    if (productivityInsight != null) {
      insights.add(productivityInsight);
    }

    // 2. Missed & Postponed Task Analysis (Repeated task problems & friction alerts)
    final peakHourSlot = _findPeakHourSlot(range: range, tasks: allTasks, focusSessions: allFocusSessions);
    final missedTaskInsight = _analyzeMissedAndPostponedTasks(
      tasks: allTasks,
      events: allEvents,
      range: range,
      peakSlotLabel: peakHourSlot?.label ?? '9 AM–12 PM',
      peakStartHour: peakHourSlot?.startHour ?? 9,
    );
    if (missedTaskInsight != null) {
      insights.add(missedTaskInsight);
    }

    // 3. Schedule Effectiveness Analysis (Planned night before vs same-day from real timestamps)
    final scheduleInsight = _analyzeScheduleEffectiveness(
      range: range,
      tasks: allTasks,
    );
    if (scheduleInsight != null) {
      insights.add(scheduleInsight);
    }

    // 4. Routine Consistency Insights (Real routine adherence without fake scores)
    final routineInsight = await _analyzeRoutineConsistency(
      consistencyService: consistencyService,
      range: range,
    );
    if (routineInsight != null) {
      insights.add(routineInsight);
    }

    // 5. Multi-Signal Cognitive Alignment (Combining task completion, focus, and missed tasks)
    final multiSignalInsight = _detectMultiSignalAlignment(
      range: range,
      tasks: allTasks,
      focusSessions: allFocusSessions,
      events: allEvents,
      peakSlot: peakHourSlot,
    );
    if (multiSignalInsight != null) {
      insights.add(multiSignalInsight);
    }

    // 6. Performance Trend Detection (Comparing current vs previous period)
    final trendInsight = _detectTrends(
      period: period,
      range: range,
      tasks: allTasks,
      focusSessions: allFocusSessions,
    );
    if (trendInsight != null) {
      insights.add(trendInsight);
    }

    return insights;
  }

  // ===========================================================================
  // 1. PRODUCTIVITY PATTERN DETECTION
  // ===========================================================================

  ProductivityTimeSlotStats? _findPeakHourSlot({
    required DateTimeRange range,
    required List<TaskModel> tasks,
    required List<FocusSessionModel> focusSessions,
  }) {
    final slots = _computeTimeSlotStats(
      range: range,
      tasks: tasks,
      focusSessions: focusSessions,
    );

    ProductivityTimeSlotStats? bestSlot;
    double maxScore = -1;

    for (final slot in slots) {
      // Combined cognitive volume score: completed tasks * 10 + focus minutes
      final score = (slot.completedTasks * 10.0) + slot.focusMinutes;
      if (score > maxScore && (slot.completedTasks > 0 || slot.focusMinutes > 0)) {
        maxScore = score;
        bestSlot = slot;
      }
    }

    return bestSlot;
  }

  List<ProductivityTimeSlotStats> _computeTimeSlotStats({
    required DateTimeRange range,
    required List<TaskModel> tasks,
    required List<FocusSessionModel> focusSessions,
  }) {
    // 4 standard cognitive windows
    // Morning: 9 AM–12 PM
    // Afternoon: 1 PM–5 PM (13:00–17:00)
    // Evening: 6 PM–10 PM (18:00–22:00)
    // Early Morning: 6 AM–9 AM (06:00–09:00)
    final slotDefs = [
      {'label': '9 AM–12 PM', 'start': 9, 'end': 12},
      {'label': '1 PM–5 PM', 'start': 13, 'end': 17},
      {'label': '6 PM–10 PM', 'start': 18, 'end': 22},
      {'label': '6 AM–9 AM', 'start': 6, 'end': 9},
    ];

    final result = <ProductivityTimeSlotStats>[];

    final completedSessions = focusSessions.where((s) {
      if (s.status != FocusSessionStatus.completed) return false;
      return !s.createdAt.isBefore(range.start) && !s.createdAt.isAfter(range.end);
    }).toList();

    for (final def in slotDefs) {
      final start = def['start'] as int;
      final end = def['end'] as int;
      final label = def['label'] as String;

      int slotCompletedTasks = 0;
      int slotTotalTasks = 0;

      for (final t in tasks) {
        final time = t.completedAt ?? t.createdAt;
        if (!time.isBefore(range.start) && !time.isAfter(range.end)) {
          if (time.hour >= start && time.hour < end) {
            slotTotalTasks++;
            if (t.isCompleted) slotCompletedTasks++;
          }
        }
      }

      int slotFocusMins = 0;
      for (final s in completedSessions) {
        if (s.createdAt.hour >= start && s.createdAt.hour < end) {
          slotFocusMins += (s.actualDurationSeconds / 60).round();
        }
      }

      final rate = slotTotalTasks > 0 ? (slotCompletedTasks / slotTotalTasks) : 0.0;

      result.add(ProductivityTimeSlotStats(
        label: label,
        startHour: start,
        endHour: end,
        completedTasks: slotCompletedTasks,
        totalTasks: slotTotalTasks,
        focusMinutes: slotFocusMins,
        completionRate: rate,
      ));
    }

    return result;
  }

  AnalyticsInsight? _detectProductivityPattern({
    required DateTimeRange range,
    required List<TaskModel> tasks,
    required List<FocusSessionModel> focusSessions,
  }) {
    final completedTasks = tasks.where((t) {
      if (!t.isCompleted || t.completedAt == null) return false;
      return !t.completedAt!.isBefore(range.start) && !t.completedAt!.isAfter(range.end);
    }).toList();

    final completedSessions = focusSessions.where((s) {
      return s.status == FocusSessionStatus.completed &&
          !s.createdAt.isBefore(range.start) &&
          !s.createdAt.isAfter(range.end);
    }).toList();

    final totalDataPoints = completedTasks.length + completedSessions.length;

    // Requirement 3: Do not claim a reliable pattern from only 1 or 2 activities.
    if (totalDataPoints < 3) {
      return AnalyticsInsight(
        id: const Uuid().v4(),
        type: 'productivity_pattern',
        category: InsightCategory.productivityPattern,
        impact: InsightImpact.medium,
        hasSufficientData: false,
        confidence: 0.2,
        title: 'Productivity Rhythm Learning',
        description: 'Keep completing tasks and focus sessions. Timora needs more data to identify your strongest productivity hours.',
        explanation: 'To pinpoint your high-performance cognitive hours with statistical confidence, Timora requires at least 3 completed tasks or focus sessions.',
        recommendation: 'Log a focus session or complete your next task today to start mapping your rhythm.',
        actionType: InsightActionType.startFocusSession,
        actionLabel: 'Start Focus Session',
        actionData: {'durationMinutes': 25},
      );
    }

    final peakSlot = _findPeakHourSlot(
      range: range,
      tasks: tasks,
      focusSessions: focusSessions,
    );

    if (peakSlot == null || (peakSlot.completedTasks == 0 && peakSlot.focusMinutes == 0)) {
      return null;
    }

    // Calculate REAL percentage from actual user data, never fallback to demo numbers
    final int pct;
    if (peakSlot.totalTasks > 0) {
      pct = (peakSlot.completionRate * 100).toInt();
    } else {
      // If no tasks were tagged in this slot, calculate percentage of total focus time spent here
      final totalFocusMins = completedSessions.fold<int>(0, (sum, s) => sum + (s.actualDurationSeconds / 60).round());
      pct = totalFocusMins > 0 ? ((peakSlot.focusMinutes / totalFocusMins) * 100).round() : 100;
    }

    final focusNote = peakSlot.focusMinutes > 0 ? ' and ${peakSlot.focusMinutes}m focus' : '';

    return AnalyticsInsight(
      id: const Uuid().v4(),
      type: 'productivity_peak',
      category: InsightCategory.productivityPattern,
      impact: InsightImpact.high,
      hasSufficientData: true,
      confidence: (totalDataPoints / 10).clamp(0.6, 0.98),
      title: 'Peak Productivity Window',
      description: "You're most productive between ${peakSlot.label} ($pct% completion).",
      explanation: 'Your real completion metrics show you achieve peak cognitive output and follow-through during ${peakSlot.label}. You logged ${peakSlot.completedTasks} completed items$focusNote here.',
      recommendation: 'Schedule your highest-priority or most complex tasks during ${peakSlot.label} to capitalize on your natural momentum.',
      actionType: InsightActionType.scheduleFocusBlock,
      actionLabel: 'Use This Time for Important Tasks',
      actionData: {
        'startHour': peakSlot.startHour,
        'endHour': peakSlot.endHour,
        'label': peakSlot.label,
      },
    );
  }

  // ===========================================================================
  // 2. MISSED AND POSTPONED TASK ANALYSIS
  // ===========================================================================

  AnalyticsInsight? _analyzeMissedAndPostponedTasks({
    required List<TaskModel> tasks,
    required List<ProductivityEventModel> events,
    required DateTimeRange range,
    required String peakSlotLabel,
    required int peakStartHour,
  }) {
    // 1. Tally reschedule events per task
    final rescheduleEvents = events.where((e) {
      return e.eventType == ProductivityEventType.taskRescheduled &&
          !e.timestamp.isBefore(range.start) &&
          !e.timestamp.isAfter(range.end);
    }).toList();

    final taskPostponeCounts = <String, int>{};
    final taskTitles = <String, String>{};

    for (final e in rescheduleEvents) {
      final id = e.entityId;
      taskPostponeCounts[id] = (taskPostponeCounts[id] ?? 0) + 1;
      if (e.metadata['title'] != null) {
        taskTitles[id] = e.metadata['title'] as String;
      }
    }

    // Also check tasks updated repeatedly without completion or overdue
    for (final t in tasks) {
      if (!t.isCompleted && !t.isDeleted) {
        taskTitles[t.id] = t.title;
        if (t.isOverdue && t.updatedAt != null && t.updatedAt!.isAfter(t.createdAt.add(const Duration(hours: 12)))) {
          taskPostponeCounts[t.id] = (taskPostponeCounts[t.id] ?? 0) + 1;
        }
      }
    }

    // Find the task postponed most often (at least twice)
    String? problematicTaskId;
    int maxPostpones = 1;

    taskPostponeCounts.forEach((id, count) {
      if (count > maxPostpones) {
        maxPostpones = count;
        problematicTaskId = id;
      }
    });

    if (problematicTaskId != null) {
      final taskTitle = taskTitles[problematicTaskId] ?? 'Priority Task';

      return AnalyticsInsight(
        id: const Uuid().v4(),
        type: 'repeated_postpone',
        category: InsightCategory.missedTask,
        impact: InsightImpact.high,
        hasSufficientData: true,
        confidence: 0.95,
        title: 'Task Friction Alert',
        description: 'You postponed "$taskTitle" $maxPostpones times this week.',
        explanation: 'Repeatedly rescheduling "$taskTitle" indicates friction, scope overload, or scheduling it during low-energy periods.',
        recommendation: 'Move "$taskTitle" to your $peakSlotLabel focus block?',
        actionType: InsightActionType.rescheduleTask,
        actionLabel: 'Move to $peakSlotLabel Focus Block',
        actionData: {
          'taskId': problematicTaskId,
          'taskTitle': taskTitle,
          'targetHour': peakStartHour,
          'durationMinutes': 45,
        },
      );
    }

    // Fallback: Check for overdue tasks
    final overdue = tasks.where((t) => t.isOverdue && !t.isCompleted && !t.isDeleted).toList();
    if (overdue.isNotEmpty) {
      final firstOverdue = overdue.first;
      return AnalyticsInsight(
        id: const Uuid().v4(),
        type: 'overdue_task',
        category: InsightCategory.missedTask,
        impact: InsightImpact.medium,
        hasSufficientData: true,
        confidence: 0.85,
        title: 'Overdue Task Attention',
        description: 'You have ${overdue.length} overdue ${overdue.length == 1 ? 'task' : 'tasks'} waiting for attention.',
        explanation: '"${firstOverdue.title}" is pending past its due date. Clearing or rescheduling overdue tasks immediately relieves mental clutter.',
        recommendation: 'Move "${firstOverdue.title}" to an active focus block today.',
        actionType: InsightActionType.rescheduleTask,
        actionLabel: 'Reschedule "${firstOverdue.title}"',
        actionData: {
          'taskId': firstOverdue.id,
          'taskTitle': firstOverdue.title,
          'targetHour': peakStartHour,
          'durationMinutes': 30,
        },
      );
    }

    return null;
  }

  // ===========================================================================
  // 3. SCHEDULE EFFECTIVENESS ANALYSIS
  // ===========================================================================

  AnalyticsInsight? _analyzeScheduleEffectiveness({
    required DateTimeRange range,
    required List<TaskModel> tasks,
  }) {
    // Tasks with dueDate in the range
    final relevantTasks = tasks.where((t) {
      if (t.isDeleted || t.dueDate == null) return false;
      return !t.dueDate!.isBefore(range.start) && !t.dueDate!.isAfter(range.end);
    }).toList();

    int plannedNightBeforeTotal = 0;
    int plannedNightBeforeCompleted = 0;

    int sameDayTotal = 0;
    int sameDayCompleted = 0;

    for (final t in relevantTasks) {
      final due = t.dueDate!;
      final dueStartOfDay = DateTime(due.year, due.month, due.day);

      // Planned before midnight of due date
      final isNightBefore = t.createdAt.isBefore(dueStartOfDay);

      if (isNightBefore) {
        plannedNightBeforeTotal++;
        if (t.isCompleted) plannedNightBeforeCompleted++;
      } else {
        sameDayTotal++;
        if (t.isCompleted) sameDayCompleted++;
      }
    }

    // Check statistical significance: need at least 2 tasks in each group
    if (plannedNightBeforeTotal < 2 || sameDayTotal < 2) {
      return AnalyticsInsight(
        id: const Uuid().v4(),
        type: 'schedule_effectiveness_sparse',
        category: InsightCategory.scheduleEffectiveness,
        impact: InsightImpact.low,
        hasSufficientData: false,
        confidence: 0.3,
        title: 'Planning Cadence Analysis',
        description: 'Plan tasks the night before to unlock planning effectiveness insights.',
        explanation: 'Timora tracks whether organizing your schedule in advance improves your daily follow-through versus spontaneous tasks.',
        recommendation: 'Plan your top 3 tasks for tomorrow evening before shutting down.',
        actionType: InsightActionType.planTomorrow,
        actionLabel: 'Plan Tomorrow',
      );
    }

    final nightBeforeRate = plannedNightBeforeTotal > 0
        ? (plannedNightBeforeCompleted / plannedNightBeforeTotal)
        : 0.0;
    final sameDayRate = sameDayTotal > 0
        ? (sameDayCompleted / sameDayTotal)
        : 0.0;

    if (nightBeforeRate > sameDayRate) {
      // Calculate genuine percentage difference strictly from real data. NO hardcoded 27!
      final diffPct = ((nightBeforeRate - sameDayRate) * 100).round();
      final displayPct = diffPct > 0 ? diffPct : 1;

      return AnalyticsInsight(
        id: const Uuid().v4(),
        type: 'schedule_night_before_win',
        category: InsightCategory.scheduleEffectiveness,
        impact: InsightImpact.high,
        hasSufficientData: true,
        confidence: 0.88,
        title: 'Advance Planning Advantage',
        description: 'You complete $displayPct% more tasks when you plan them the night before.',
        explanation: 'Setting up tasks prior to sleep reduces morning decision fatigue. You completed ${(nightBeforeRate * 100).toInt()}% of pre-planned tasks versus ${(sameDayRate * 100).toInt()}% of same-day tasks.',
        recommendation: 'Spend 5 minutes tonight outlining your top deliverables for tomorrow.',
        actionType: InsightActionType.planTomorrow,
        actionLabel: 'Plan Tomorrow',
      );
    } else {
      return AnalyticsInsight(
        id: const Uuid().v4(),
        type: 'schedule_agile_execution',
        category: InsightCategory.scheduleEffectiveness,
        impact: InsightImpact.medium,
        hasSufficientData: true,
        confidence: 0.82,
        title: 'Agile Execution Balance',
        description: 'You completed ${(sameDayRate * 100).toInt()}% of same-day tasks and ${(nightBeforeRate * 100).toInt()}% of pre-planned tasks.',
        explanation: 'Your real-time adaptability is strong. Combining advance planning with flexible daytime slots will maximize long-term milestone completion.',
        recommendation: 'Balance tomorrow by scheduling 2 fixed priority anchors with open afternoon buffers.',
        actionType: InsightActionType.planTomorrow,
        actionLabel: 'Plan Tomorrow',
      );
    }
  }

  // ===========================================================================
  // 4. ROUTINE CONSISTENCY INSIGHTS
  // ===========================================================================

  Future<AnalyticsInsight?> _analyzeRoutineConsistency({
    required ConsistencyScoreService consistencyService,
    required DateTimeRange range,
  }) async {
    try {
      final result = await consistencyService.calculateWeeklyConsistency();

      if (!result.hasSufficientData || (result.totalExpected == 0 && result.totalCompleted == 0)) {
        return AnalyticsInsight(
          id: const Uuid().v4(),
          type: 'routine_empty',
          category: InsightCategory.routineConsistency,
          impact: InsightImpact.low,
          hasSufficientData: false,
          confidence: 0.2,
          title: 'Routine Consistency Tracker',
          description: 'Establish your morning or evening routine to start tracking consistency.',
          explanation: 'Consistent routines anchor your focus and build automatic daily momentum without draining willpower.',
          recommendation: 'Create a 15-minute morning routine to establish an intentional start to your day.',
          actionType: InsightActionType.reviewRoutines,
          actionLabel: 'Explore Routines',
        );
      }

      final strongest = result.strongestRoutine;
      final weakest = result.weakestRoutine;

      if (strongest != null && strongest.scorePercentage >= 70) {
        final score = strongest.scorePercentage.round();
        final routineName = strongest.routineName;

        return AnalyticsInsight(
          id: const Uuid().v4(),
          type: 'routine_strong',
          category: InsightCategory.routineConsistency,
          impact: InsightImpact.high,
          hasSufficientData: true,
          confidence: 0.92,
          title: 'Routine Consistency Score',
          description: 'Your $routineName has an $score% consistency score.',
          explanation: 'Your $routineName is your most consistent anchor this week (${strongest.completedCount} of ${strongest.expectedCount} scheduled items completed).',
          recommendation: 'Keep your streak alive. Preserve your routine timeframe against unscheduled meetings.',
          actionType: InsightActionType.reviewRoutines,
          actionLabel: 'View Routines',
        );
      } else if (weakest != null && weakest.scorePercentage < 65) {
        final weakScore = weakest.scorePercentage.round();
        final weakName = weakest.routineName;

        return AnalyticsInsight(
          id: const Uuid().v4(),
          type: 'routine_friction',
          category: InsightCategory.routineConsistency,
          impact: InsightImpact.medium,
          hasSufficientData: true,
          confidence: 0.86,
          title: 'Routine Friction Detected',
          description: 'Your $weakName was completed only $weakScore% of the time this week.',
          explanation: 'Inconsistent completion usually indicates a routine is either too long or scheduled when energy is depleted.',
          recommendation: 'Shrink your $weakName down to a 5-minute essential version to rebuild consistency.',
          actionType: InsightActionType.reviewRoutines,
          actionLabel: 'Optimize $weakName',
        );
      } else {
        final overallScore = result.overallScore.round();
        return AnalyticsInsight(
          id: const Uuid().v4(),
          type: 'routine_balanced',
          category: InsightCategory.routineConsistency,
          impact: InsightImpact.medium,
          hasSufficientData: true,
          confidence: 0.85,
          title: 'Routine Consistency Overview',
          description: 'Overall routine execution is steady at $overallScore% this week.',
          explanation: 'You completed ${result.totalCompleted} of ${result.totalExpected} scheduled routine activities.',
          recommendation: 'Maintain your core anchors and review frequently skipped steps to streamline momentum.',
          actionType: InsightActionType.reviewRoutines,
          actionLabel: 'Review Routines',
        );
      }
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // 5. MULTI-SIGNAL COGNITIVE ALIGNMENT
  // ===========================================================================

  AnalyticsInsight? _detectMultiSignalAlignment({
    required DateTimeRange range,
    required List<TaskModel> tasks,
    required List<FocusSessionModel> focusSessions,
    required List<ProductivityEventModel> events,
    required ProductivityTimeSlotStats? peakSlot,
  }) {
    if (peakSlot == null || peakSlot.completedTasks < 2) return null;

    // Check if missed or postponed tasks concentrated in late hours (after 6 PM)
    final eveningFrictionEvents = events.where((e) {
      if (e.eventType != ProductivityEventType.taskRescheduled &&
          e.eventType != ProductivityEventType.taskMissed &&
          e.eventType != ProductivityEventType.activityMissed) {
        return false;
      }
      return e.timestamp.isAfter(range.start) &&
          e.timestamp.isBefore(range.end) &&
          e.timestamp.hour >= 18;
    }).length;

    if (peakSlot.startHour <= 12 && eveningFrictionEvents >= 2) {
      return AnalyticsInsight(
        id: const Uuid().v4(),
        type: 'multi_signal_energy_shift',
        category: InsightCategory.productivityPattern,
        impact: InsightImpact.high,
        hasSufficientData: true,
        confidence: 0.93,
        title: 'Cognitive Rhythm Alignment',
        description: 'Your strongest work period is ${peakSlot.label} with lower fatigue.',
        explanation: 'Multi-signal analysis confirms high execution flow during ${peakSlot.label} (${peakSlot.completedTasks} items completed, ${peakSlot.focusMinutes}m focus), while $eveningFrictionEvents task postponements occurred in the evening.',
        recommendation: 'Consider moving high-priority work into your morning focus block and reserve evenings for low-cognitive recovery.',
        actionType: InsightActionType.scheduleFocusBlock,
        actionLabel: 'Protect Morning Focus Block',
        actionData: {
          'startHour': peakSlot.startHour,
          'endHour': peakSlot.endHour,
          'label': peakSlot.label,
        },
      );
    }

    return null;
  }

  // ===========================================================================
  // 6. TREND DETECTION
  // ===========================================================================

  AnalyticsInsight? _detectTrends({
    required AnalyticsPeriod period,
    required DateTimeRange range,
    required List<TaskModel> tasks,
    required List<FocusSessionModel> focusSessions,
  }) {
    final duration = range.end.difference(range.start);
    final priorRange = DateTimeRange(
      start: range.start.subtract(duration),
      end: range.start.subtract(const Duration(seconds: 1)),
    );

    final currentCompleted = tasks.where((t) {
      return t.isCompleted &&
          t.completedAt != null &&
          t.completedAt!.isAfter(range.start) &&
          t.completedAt!.isBefore(range.end);
    }).length;

    final priorCompleted = tasks.where((t) {
      return t.isCompleted &&
          t.completedAt != null &&
          t.completedAt!.isAfter(priorRange.start) &&
          t.completedAt!.isBefore(priorRange.end);
    }).length;

    if (currentCompleted == 0 && priorCompleted == 0) return null;

    if (priorCompleted > 0) {
      final changePct = (((currentCompleted - priorCompleted) / priorCompleted) * 100).round();
      if (changePct > 5) {
        return AnalyticsInsight(
          id: const Uuid().v4(),
          type: 'trend_positive',
          category: InsightCategory.trend,
          impact: InsightImpact.high,
          hasSufficientData: true,
          confidence: 0.9,
          title: 'Productivity Momentum',
          description: 'Your completed tasks increased $changePct% compared with last period.',
          explanation: 'You completed $currentCompleted tasks this period versus $priorCompleted in the preceding period. Your momentum is accelerating.',
          recommendation: 'Maintain momentum by identifying your next major deliverable before your streak cools down.',
          actionType: InsightActionType.scheduleFocusBlock,
          actionLabel: 'Schedule Next Milestone',
        );
      } else if (changePct < -10) {
        return AnalyticsInsight(
          id: const Uuid().v4(),
          type: 'trend_decline',
          category: InsightCategory.trend,
          impact: InsightImpact.medium,
          hasSufficientData: true,
          confidence: 0.85,
          title: 'Pacing Reset Opportunity',
          description: 'Task completion softened by ${changePct.abs()}% compared with last period.',
          explanation: 'Fluctuations in output are natural after heavy execution sprints. Use this interval for strategic planning and recovery.',
          recommendation: 'Select just 1 essential focus task for tomorrow to restore flow.',
          actionType: InsightActionType.startFocusSession,
          actionLabel: 'Quick 25m Focus Reset',
          actionData: {'durationMinutes': 25},
        );
      }
    }

    return null;
  }
}
