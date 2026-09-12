import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/analytics/data/models/analytics_models.dart';
import 'package:timora/features/analytics/data/models/productivity_event_model.dart';
import 'package:timora/features/analytics/data/repositories/productivity_event_repository.dart';
import 'package:timora/features/analytics/services/consistency_score_service.dart';
import 'package:timora/features/analytics/services/insight_action_service.dart';
import 'package:timora/features/analytics/services/insights_engine_service.dart';
import 'package:timora/features/analytics/services/ai_insight_explainer_service.dart';
import 'package:timora/features/analytics/services/report_generator_service.dart';
import 'package:timora/features/focus/data/models/focus_session_model.dart';
import 'package:timora/features/focus/data/repositories/focus_repository.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/routine/data/models/routine_block.dart';
import 'package:timora/features/routine/data/repositories/routine_repository.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late TaskRepository taskRepo;
  late ProductivityEventRepository eventRepo;
  late ScheduleRepository scheduleRepo;
  late RoutineRepository routineRepo;
  late FocusRepository focusRepo;
  late InsightsEngineService insightsService;
  late ConsistencyScoreService consistencyService;
  late InsightActionService actionService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

    taskRepo = container.read(taskRepositoryProvider);
    eventRepo = container.read(productivityEventRepositoryProvider);
    scheduleRepo = container.read(scheduleRepositoryProvider);
    routineRepo = container.read(routineRepositoryProvider);
    focusRepo = container.read(focusRepositoryProvider);
    insightsService = container.read(insightsEngineServiceProvider);
    consistencyService = container.read(consistencyScoreServiceProvider);
    actionService = container.read(insightActionServiceProvider);
  });

  tearDown(() {
    container.dispose();
  });

  group('Timora Insights Engine — Comprehensive Specification Tests', () {
    // =========================================================================
    // Test A — Productivity Pattern Detection
    // =========================================================================
    test('Test A: Correctly identifies peak productivity window (9 AM–12 PM) from real tasks and focus', () async {
      final now = DateTime.now();
      // Add tasks completed between 9 AM and 12 PM
      for (int i = 0; i < 4; i++) {
        final task = TaskModel(
          id: 'task_morning_$i',
          title: 'Morning Focus Task $i',
          status: TaskStatus.completed,
          completedAt: DateTime(now.year, now.month, now.day, 10, 30),
          createdAt: DateTime(now.year, now.month, now.day, 9, 0),
        );
        await taskRepo.createTask(task);
      }

      // Add a completed focus session between 9 AM and 12 PM (60 minutes)
      final session = FocusSessionModel(
        id: 'session_morning_1',
        startedAt: DateTime(now.year, now.month, now.day, 9, 30),
        endedAt: DateTime(now.year, now.month, now.day, 10, 30),
        status: FocusSessionStatus.completed,
        plannedDurationSeconds: 3600,
        actualDurationSeconds: 3600,
        createdAt: DateTime(now.year, now.month, now.day, 9, 30),
      );
      await focusRepo.saveSession(session);

      // Add 1 task in the afternoon (1 PM–5 PM)
      final afternoonTask = TaskModel(
        id: 'task_afternoon_1',
        title: 'Afternoon Admin',
        status: TaskStatus.completed,
        completedAt: DateTime(now.year, now.month, now.day, 14, 0),
        createdAt: DateTime(now.year, now.month, now.day, 13, 30),
      );
      await taskRepo.createTask(afternoonTask);

      final insights = await insightsService.generateInsights(AnalyticsPeriod.today);
      final peakInsight = insights.where((i) => i.category == InsightCategory.productivityPattern).firstOrNull;

      expect(peakInsight, isNotNull);
      expect(peakInsight!.hasSufficientData, isTrue);
      expect(peakInsight.description, contains('9 AM–12 PM'));
      expect(peakInsight.description, contains('% completion'));
      // Verify no hardcoded 90% when calculated rate is 100%
      expect(peakInsight.description, contains('100% completion'));
      expect(peakInsight.actionType, InsightActionType.scheduleFocusBlock);
      expect(peakInsight.actionLabel, contains('Use This Time'));
    });

    // =========================================================================
    // Test B — Routine Consistency
    // =========================================================================
    test('Test B: Calculates meaningful consistency score strictly from real user routines and activities', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));

      // Create a Morning Routine
      final routine = Routine(
        id: 'rt_morning',
        name: 'Morning Routine',
        icon: '🌅',
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        createdAt: weekStart,
      );

      final block1 = RoutineBlock(
        id: 'blk_stretch',
        routineId: 'rt_morning',
        title: 'Hydration & Stretching',
        icon: '🧘',
        startTime: const TimeOfDay(hour: 7, minute: 0),
        endTime: const TimeOfDay(hour: 7, minute: 15),
        category: 'Health',
        order: 1,
      );

      await routineRepo.addRoutine(routine, [block1]);

      // Add 4 completed schedule activities for this block this week
      for (int i = 0; i < 4; i++) {
        final date = weekStart.add(Duration(days: i));
        await scheduleRepo.addActivity(ScheduleActivity(
          id: 'act_rt_$i',
          title: 'Hydration & Stretching',
          date: date,
          startTime: DateTime(date.year, date.month, date.day, 7, 0),
          endTime: DateTime(date.year, date.month, date.day, 7, 15),
          routineBlockId: 'blk_stretch',
          status: ActivityStatus.completed,
          completedAt: DateTime(date.year, date.month, date.day, 7, 14),
          createdAt: date,
        ));
      }

      final result = await consistencyService.calculateWeeklyConsistency();
      expect(result.hasSufficientData, isTrue);
      expect(result.totalCompleted, greaterThanOrEqualTo(4));
      expect(result.overallScore, greaterThan(0));

      final insights = await insightsService.generateInsights(AnalyticsPeriod.thisWeek);
      final routineInsight = insights.where((i) => i.category == InsightCategory.routineConsistency).firstOrNull;

      expect(routineInsight, isNotNull);
      expect(routineInsight!.description, contains('Morning Routine'));
      expect(routineInsight.description, contains('consistency score'));
      expect(routineInsight.actionType, InsightActionType.reviewRoutines);
    });

    // =========================================================================
    // Test C — Missed & Postponed Tasks
    // =========================================================================
    test('Test C: Detects repeatedly postponed task and recommends moving it to peak focus window', () async {
      final now = DateTime.now();

      final task = TaskModel(
        id: 'task_research_paper',
        title: 'Research Paper',
        status: TaskStatus.pending,
        dueDate: now.add(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 4)),
      );
      await taskRepo.createTask(task);

      // Log 4 task rescheduled events this week
      for (int i = 1; i <= 4; i++) {
        await eventRepo.recordEvent(ProductivityEventModel(
          eventType: ProductivityEventType.taskRescheduled,
          entityType: 'task',
          entityId: 'task_research_paper',
          timestamp: now.subtract(Duration(days: 4 - i, hours: 2)),
          metadata: {'title': 'Research Paper'},
        ));
      }

      final insights = await insightsService.generateInsights(AnalyticsPeriod.last7Days);
      final frictionInsight = insights.where((i) => i.category == InsightCategory.missedTask).firstOrNull;

      expect(frictionInsight, isNotNull);
      expect(frictionInsight!.description, contains('You postponed "Research Paper" 4 times'));
      expect(frictionInsight.recommendation, contains('Research Paper'));
      expect(frictionInsight.actionType, InsightActionType.rescheduleTask);
      expect(frictionInsight.actionData?['taskId'], 'task_research_paper');
    });

    // =========================================================================
    // Test D — Schedule Effectiveness
    // =========================================================================
    test('Test D: Compares planned night before vs same-day completion without fake hardcoded numbers', () async {
      final now = DateTime.now();
      final targetDate = DateTime(now.year, now.month, now.day);

      // 2 tasks planned night before: 2 completed (100% completion)
      for (int i = 1; i <= 2; i++) {
        final t = TaskModel(
          id: 'preplanned_$i',
          title: 'Advance Task $i',
          dueDate: targetDate,
          status: TaskStatus.completed,
          completedAt: targetDate,
          createdAt: targetDate.subtract(const Duration(hours: 14)), // Night before
        );
        await taskRepo.createTask(t);
      }

      // 2 same-day tasks: 1 completed, 1 pending (50% completion)
      final sameDay1 = TaskModel(
        id: 'sameday_1',
        title: 'Same Day Done',
        dueDate: targetDate,
        status: TaskStatus.completed,
        completedAt: DateTime(targetDate.year, targetDate.month, targetDate.day, 11, 0),
        createdAt: DateTime(targetDate.year, targetDate.month, targetDate.day, 9, 0),
      );
      final sameDay2 = TaskModel(
        id: 'sameday_2',
        title: 'Same Day Pending',
        dueDate: targetDate,
        status: TaskStatus.pending,
        createdAt: DateTime(targetDate.year, targetDate.month, targetDate.day, 10, 0),
      );
      await taskRepo.createTask(sameDay1);
      await taskRepo.createTask(sameDay2);

      final insights = await insightsService.generateInsights(AnalyticsPeriod.today);
      final schedInsight = insights.where((i) => i.category == InsightCategory.scheduleEffectiveness).firstOrNull;

      expect(schedInsight, isNotNull);
      expect(schedInsight!.hasSufficientData, isTrue);
      // Real difference: 100% - 50% = 50% (NOT hardcoded 27!)
      expect(schedInsight.description, contains('50% more tasks when you plan them the night before'));
      expect(schedInsight.actionType, InsightActionType.planTomorrow);
    });

    // =========================================================================
    // Test E — Action Execution
    // =========================================================================
    test('Test E: Executing rescheduleTask updates task schedule in TaskRepository', () async {
      final now = DateTime.now();
      final task = TaskModel(
        id: 'target_reschedule_task',
        title: 'Quarterly Report',
        dueDate: now.subtract(const Duration(days: 1)),
        status: TaskStatus.pending,
        createdAt: now.subtract(const Duration(days: 2)),
      );
      await taskRepo.createTask(task);

      final insight = AnalyticsInsight(
        id: 'ins_action_1',
        type: 'test_action',
        description: 'Test friction',
        actionType: InsightActionType.rescheduleTask,
        actionLabel: 'Move to 9 AM Focus Block',
        actionData: {
          'taskId': 'target_reschedule_task',
          'taskTitle': 'Quarterly Report',
          'targetHour': 9,
          'durationMinutes': 60,
        },
      );

      final result = await actionService.executeAction(insight);
      expect(result.success, isTrue);
      expect(result.message, contains('Quarterly Report'));

      // Verify task in repository was updated
      final updatedTask = await taskRepo.getTask('target_reschedule_task');
      expect(updatedTask, isNotNull);
      expect(updatedTask!.dueTime?.hour, 9);
      expect(updatedTask.startTime?.hour, 9);
    });

    test('Test E2: Executing scheduleFocusBlock creates activity in ScheduleRepository', () async {
      final insight = AnalyticsInsight(
        id: 'ins_action_2',
        type: 'test_focus_block',
        description: 'Schedule focus block',
        actionType: InsightActionType.scheduleFocusBlock,
        actionLabel: 'Use This Time',
        actionData: {
          'startHour': 10,
          'endHour': 12,
          'label': '10 AM–12 PM',
        },
      );

      final result = await actionService.executeAction(insight);
      expect(result.success, isTrue);
      expect(result.message, contains('Scheduled Deep Focus Block'));

      final now = DateTime.now();
      final targetDate = now.hour >= 12
          ? DateTime(now.year, now.month, now.day).add(const Duration(days: 1))
          : DateTime(now.year, now.month, now.day);
      final activities = await scheduleRepo.getActivitiesForDate(targetDate);
      final focusBlock = activities.where((a) => a.title == 'Deep Focus Block').firstOrNull;
      expect(focusBlock, isNotNull);
      expect(focusBlock!.startTime.hour, 10);
      expect(focusBlock.endTime.hour, 12);
    });

    // =========================================================================
    // Test F — Insufficient Data
    // =========================================================================
    test('Test F: When data history is insufficient (<3 activities), shows honest learning message', () async {
      // 0 tasks, 0 focus sessions
      final insights = await insightsService.generateInsights(AnalyticsPeriod.today);
      final peakInsight = insights.where((i) => i.category == InsightCategory.productivityPattern).firstOrNull;

      expect(peakInsight, isNotNull);
      expect(peakInsight!.hasSufficientData, isFalse);
      expect(peakInsight.description, 'Keep completing tasks and focus sessions. Timora needs more data to identify your strongest productivity hours.');
    });

    // =========================================================================
    // Test G — Report Integration
    // =========================================================================
    test('Test G: Daily, Weekly, and Monthly reports include intelligent insights', () async {
      final reportService = container.read(reportGeneratorServiceProvider);

      final daily = await reportService.generateDailyReport();
      expect(daily.date, isNotNull);
      expect(daily.completionPercentage, isA<double>());

      final weekly = await reportService.generateWeeklyReport();
      expect(weekly.weeklyInsights, isNotNull);
      expect(weekly.completionRate, isA<double>());

      final monthly = await reportService.generateMonthlyReport();
      expect(monthly.monthlyInsights, isNotNull);
      expect(monthly.improvementSuggestions, isNotEmpty);
    });

    // =========================================================================
    // Test H — Offline Reliability & Null Safety
    // =========================================================================
    test('Test H: Insights Engine never crashes on null dates, empty lists, or deleted items', () async {
      // Add a task with null dueDate, null completedAt, marked deleted
      final brokenTask = TaskModel(
        id: 'broken_task',
        title: 'Broken Task',
        dueDate: null,
        completedAt: null,
        isDeleted: true,
        createdAt: DateTime.now(),
      );
      await taskRepo.createTask(brokenTask);

      // Add corrupt productivity event
      await eventRepo.recordEvent(ProductivityEventModel(
        eventType: 'CORRUPTED_EVENT',
        entityType: 'unknown',
        entityId: '',
        metadata: {},
      ));

      // Run insights generation across all periods
      for (final period in AnalyticsPeriod.values) {
        final list = await insightsService.generateInsights(period);
        expect(list, isA<List<AnalyticsInsight>>());
      }
    });

    // =========================================================================
    // Test I — AI Interpretation with Offline Fallback
    // =========================================================================
    test('Test I: AI explainer enriches verified metrics and safely falls back offline', () async {
      final explainer = container.read(aiInsightExplainerServiceProvider);

      final rawInsight = AnalyticsInsight(
        id: 'ins_ai_1',
        type: 'productivity_peak',
        title: 'Peak Productivity Window',
        description: "You're most productive between 9 AM–12 PM (91% completion).",
        recommendation: 'Schedule difficult tasks between 9 AM–12 PM.',
        category: InsightCategory.productivityPattern,
        hasSufficientData: true,
      );

      final enriched = await explainer.enrichInsightWithAI(rawInsight);
      expect(enriched.id, rawInsight.id);
      expect(enriched.description, rawInsight.description);
      expect(enriched.explanation, isNotEmpty);
      expect(enriched.recommendation, isNotEmpty);
    });
  });
}
