import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/report_model.dart';
import '../data/models/productivity_event_model.dart';
import '../data/repositories/productivity_event_repository.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/data/repositories/schedule_repository.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../focus/presentation/providers/focus_provider.dart';
import '../../focus/data/models/focus_session_model.dart';
import '../../goals/data/models/goal_model.dart';
import '../../goals/data/repositories/goal_repository.dart';
import '../../projects/data/models/project_model.dart';
import '../../projects/data/repositories/project_repository.dart';
import 'consistency_score_service.dart';
import '../data/models/analytics_models.dart';
import 'insights_engine_service.dart';

final reportGeneratorServiceProvider = Provider<ReportGeneratorService>((ref) {
  return ReportGeneratorService(ref);
});

final dailyReportProvider = FutureProvider<DailyReportModel>((ref) async {
  final service = ref.watch(reportGeneratorServiceProvider);
  return service.generateDailyReport();
});

final weeklyReportProvider = FutureProvider<WeeklyReportModel>((ref) async {
  final service = ref.watch(reportGeneratorServiceProvider);
  return service.generateWeeklyReport();
});

final monthlyReportProvider = FutureProvider<MonthlyReportModel>((ref) async {
  final service = ref.watch(reportGeneratorServiceProvider);
  return service.generateMonthlyReport();
});

class ReportGeneratorService {
  final Ref _ref;

  ReportGeneratorService(this._ref);

  Future<DailyReportModel> generateDailyReport([DateTime? targetDate]) async {
    final now = DateTime.now();
    final date = targetDate ?? DateTime(now.year, now.month, now.day);

    final scheduleRepo = _ref.read(scheduleRepositoryProvider);
    final taskRepo = _ref.read(taskRepositoryProvider);
    final eventRepo = _ref.read(productivityEventRepositoryProvider);
    final consistencyService = _ref.read(consistencyScoreServiceProvider);
    final insightsEngine = _ref.read(insightsEngineServiceProvider);

    final activities = await scheduleRepo.getActivitiesForDate(date);
    final allTasks = await taskRepo.getTasks();
    final events = await eventRepo.getAllEvents();

    final plannedList = activities.where((a) => a.status != ActivityStatus.replaced).toList();
    final completedList = activities.where((a) => a.status == ActivityStatus.completed).toList();
    final missedList = activities.where((a) => a.status == ActivityStatus.skipped || (a.endTime.isBefore(now) && a.status != ActivityStatus.completed && a.status != ActivityStatus.replaced)).toList();
    final replacedList = activities.where((a) => a.status == ActivityStatus.replaced).toList();

    // Recovered events for today
    final recoveredEvents = events.where((e) {
      return e.eventType == ProductivityEventType.taskRecovered &&
          e.timestamp.year == date.year &&
          e.timestamp.month == date.month &&
          e.timestamp.day == date.day;
    }).toList();
    final recovered = recoveredEvents.length;

    final recoveredEntityIds = recoveredEvents.map((e) => e.entityId).toSet();
    final recoveredList = activities.where((a) => recoveredEntityIds.contains(a.id) || a.isOverridden).toList();

    final planned = plannedList.length;
    final completed = completedList.length;
    final missed = missedList.length;
    final replaced = replacedList.length;

    final completionPct = planned > 0
        ? ((completed / planned) * 100).clamp(0.0, 100.0)
        : (completed > 0 ? 100.0 : 0.0);

    // Focus sessions today
    final focusSessions = await _ref.read(allFocusSessionsProvider.future);
    int focusMins = 0;
    for (final s in focusSessions) {
      if (s.createdAt.year == date.year &&
          s.createdAt.month == date.month &&
          s.createdAt.day == date.day &&
          s.status == FocusSessionStatus.completed) {
        focusMins += (s.actualDurationSeconds / 60).round();
      }
    }

    // Tasks completed today
    final tasksCompleted = allTasks.where((t) {
      return t.isCompleted &&
          t.completedAt != null &&
          t.completedAt!.year == date.year &&
          t.completedAt!.month == date.month &&
          t.completedAt!.day == date.day;
    }).length;

    final tasksRemaining = allTasks.where((t) => !t.isCompleted && !t.isDeleted).length;

    final consistency = await consistencyService.calculateWeeklyConsistency();

    // Generate intelligent daily insight
    final todayInsights = await insightsEngine.generateInsights(AnalyticsPeriod.today);
    final topDailyInsight = todayInsights.isNotEmpty ? todayInsights.first : null;

    return DailyReportModel(
      date: date,
      plannedActivities: planned,
      completedActivities: completed,
      missedActivities: missed,
      recoveredActivities: recovered,
      replacedActivities: replaced,
      completionPercentage: completionPct,
      focusTimeMinutes: focusMins,
      routineConsistency: consistency.overallScore,
      tasksCompleted: tasksCompleted,
      tasksRemaining: tasksRemaining,
      topInsight: topDailyInsight,
      plannedList: plannedList,
      completedList: completedList,
      missedList: missedList,
      recoveredList: recoveredList,
      replacedList: replacedList,
    );
  }

  Future<WeeklyReportModel> generateWeeklyReport() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final scheduleRepo = _ref.read(scheduleRepositoryProvider);
    final taskRepo = _ref.read(taskRepositoryProvider);
    final goalRepo = _ref.read(goalRepositoryProvider);
    final projectRepo = _ref.read(projectRepositoryProvider);
    final consistencyService = _ref.read(consistencyScoreServiceProvider);
    final eventRepo = _ref.read(productivityEventRepositoryProvider);

    double totalPlannedMins = 0;
    double totalCompletedMins = 0;
    int completedCount = 0;
    int plannedCount = 0;
    int replacedCount = 0;

    final weeklyPlanned = <ScheduleActivity>[];
    final weeklyCompleted = <ScheduleActivity>[];
    final weeklyMissed = <ScheduleActivity>[];
    final weeklyReplaced = <ScheduleActivity>[];

    final dayCompletions = <int, int>{}; // weekday -> count

    for (int i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      final acts = await scheduleRepo.getActivitiesForDate(d);
      for (final a in acts) {
        if (a.status == ActivityStatus.replaced) {
          replacedCount++;
          weeklyReplaced.add(a);
        } else {
          plannedCount++;
          weeklyPlanned.add(a);
          final dur = a.endTime.difference(a.startTime).inMinutes.toDouble();
          totalPlannedMins += dur;
          if (a.status == ActivityStatus.completed) {
            completedCount++;
            weeklyCompleted.add(a);
            totalCompletedMins += dur;
            dayCompletions[d.weekday] = (dayCompletions[d.weekday] ?? 0) + 1;
          } else if (a.status == ActivityStatus.skipped || (a.endTime.isBefore(now) && a.status != ActivityStatus.completed)) {
            weeklyMissed.add(a);
          }
        }
      }
    }

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    int bestDayIdx = 1;
    int maxComp = -1;
    int weakestDayIdx = 7;
    int minComp = 999999;

    for (int w = 1; w <= 7; w++) {
      final c = dayCompletions[w] ?? 0;
      if (c > maxComp) {
        maxComp = c;
        bestDayIdx = w;
      }
      if (c < minComp) {
        minComp = c;
        weakestDayIdx = w;
      }
    }

    final rate = plannedCount > 0 ? ((completedCount / plannedCount) * 100).clamp(0.0, 100.0) : 0.0;

    final allTasks = await taskRepo.getTasks();
    final missedTasks = allTasks.where((t) => t.isOverdue && !t.isCompleted).length;

    final events = await eventRepo.getAllEvents();
    final recoveredTasks = events.where((e) => e.eventType == ProductivityEventType.taskRecovered).length;

    final consistency = await consistencyService.calculateWeeklyConsistency();

    // Goals & Projects progress
    final goals = await goalRepo.getGoals();
    final completedGoals = goals.where((g) => g.status == GoalStatus.completed).length;
    final goalProgress = goals.isNotEmpty ? (completedGoals / goals.length) * 100 : 0.0;

    final projects = await projectRepo.getProjects();
    final completedProjects = projects.where((p) => p.status == ProjectStatus.completed).length;
    final projectProgress = projects.isNotEmpty ? (completedProjects / projects.length) * 100 : 0.0;

    final insightsEngine = _ref.read(insightsEngineServiceProvider);
    final weeklyInsights = await insightsEngine.generateInsights(AnalyticsPeriod.thisWeek);
    final peakInsight = weeklyInsights.where((i) => i.category == InsightCategory.productivityPattern).firstOrNull;
    final mostProductiveTime = peakInsight != null && peakInsight.hasSufficientData
        ? (peakInsight.actionData?['label'] as String? ?? '9 AM–12 PM')
        : (maxComp > 0 ? 'Peak Window Identified' : 'Gathering weekly data');

    return WeeklyReportModel(
      weekStart: weekStart,
      weekEnd: weekEnd,
      totalPlannedHours: double.parse((totalPlannedMins / 60).toStringAsFixed(1)),
      totalCompletedHours: double.parse((totalCompletedMins / 60).toStringAsFixed(1)),
      completionRate: rate,
      missedTasks: missedTasks,
      recoveredTasks: recoveredTasks,
      replacedActivities: replacedCount,
      bestDay: maxComp > 0 ? weekdays[bestDayIdx - 1] : 'No activity yet',
      weakestDay: weekdays[weakestDayIdx - 1],
      mostProductiveTime: mostProductiveTime,
      routineConsistency: consistency.overallScore,
      goalProgress: goalProgress,
      projectProgress: projectProgress,
      weeklyInsights: weeklyInsights,
      plannedList: weeklyPlanned,
      completedList: weeklyCompleted,
      missedList: weeklyMissed,
      recoveredList: const [],
      replacedList: weeklyReplaced,
    );
  }

  Future<MonthlyReportModel> generateMonthlyReport() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final scheduleRepo = _ref.read(scheduleRepositoryProvider);
    final consistencyService = _ref.read(consistencyScoreServiceProvider);
    final goalRepo = _ref.read(goalRepositoryProvider);
    final projectRepo = _ref.read(projectRepositoryProvider);
    final taskRepo = _ref.read(taskRepositoryProvider);
    final allTasks = await taskRepo.getTasks();

    int monthlyReplacedCount = 0;
    final monthlyPlanned = <ScheduleActivity>[];
    final monthlyCompleted = <ScheduleActivity>[];
    final monthlyMissed = <ScheduleActivity>[];
    final monthlyReplaced = <ScheduleActivity>[];

    final totalDays = monthEnd.day;
    for (int i = 1; i <= totalDays; i++) {
      final d = DateTime(monthStart.year, monthStart.month, i);
      final acts = await scheduleRepo.getActivitiesForDate(d);
      for (final a in acts) {
        if (a.status == ActivityStatus.replaced) {
          monthlyReplacedCount++;
          monthlyReplaced.add(a);
        } else {
          monthlyPlanned.add(a);
          if (a.status == ActivityStatus.completed) {
            monthlyCompleted.add(a);
          } else if (a.status == ActivityStatus.skipped || (a.endTime.isBefore(now) && a.status != ActivityStatus.completed)) {
            monthlyMissed.add(a);
          }
        }
      }
    }

    final consistency = await consistencyService.calculateWeeklyConsistency();
    final goals = await goalRepo.getGoals();
    final projects = await projectRepo.getProjects();

    final completedGoals = goals.where((g) => g.status == GoalStatus.completed).length;
    final goalProg = goals.isNotEmpty ? (completedGoals / goals.length) * 100 : 0.0;

    final completedProj = projects.where((p) => p.status == ProjectStatus.completed).length;
    final projProg = projects.isNotEmpty ? (completedProj / projects.length) * 100 : 0.0;

    // Real monthly task metrics
    final monthTasks = allTasks.where((t) {
      if (t.isDeleted) return false;
      return t.createdAt.isAfter(monthStart) && t.createdAt.isBefore(monthEnd);
    }).toList();

    final monthCompletedTasks = monthTasks.where((t) => t.isCompleted).length;
    final completionTrend = monthTasks.isNotEmpty
        ? ((monthCompletedTasks / monthTasks.length) * 100).clamp(0.0, 100.0)
        : 0.0;

    final insightsEngine = _ref.read(insightsEngineServiceProvider);
    final monthlyInsights = await insightsEngine.generateInsights(AnalyticsPeriod.thisMonth);
    final peakInsight = monthlyInsights.where((i) => i.category == InsightCategory.productivityPattern).firstOrNull;

    final strongestHours = peakInsight != null && peakInsight.hasSufficientData
        ? (peakInsight.actionData?['label'] as String? ?? '9 AM–12 PM')
        : (monthCompletedTasks > 0 ? 'Morning Window' : 'Gathering monthly data');

    final dynamicSuggestions = <String>[];
    for (final ins in monthlyInsights.take(3)) {
      if (ins.recommendation.isNotEmpty) {
        dynamicSuggestions.add(ins.recommendation);
      } else if (ins.description.isNotEmpty) {
        dynamicSuggestions.add(ins.description);
      }
    }
    if (dynamicSuggestions.isEmpty) {
      dynamicSuggestions.add('Log tasks and focus sessions consistently to unlock personalized monthly recommendations.');
    }

    return MonthlyReportModel(
      monthStart: monthStart,
      monthEnd: monthEnd,
      completionTrend: completionTrend,
      productivityTrend: (completionTrend * 0.6 + consistency.overallScore * 0.4).clamp(0.0, 100.0),
      routineConsistencyTrend: consistency.overallScore,
      goalProgress: goalProg,
      projectProgress: projProg,
      strongestProductivityHours: strongestHours,
      weakestPeriod: 'Late evening hours',
      improvementSuggestions: dynamicSuggestions,
      monthlyInsights: monthlyInsights,
      replacedActivities: monthlyReplacedCount,
      plannedList: monthlyPlanned,
      completedList: monthlyCompleted,
      missedList: monthlyMissed,
      recoveredList: const [],
      replacedList: monthlyReplaced,
    );
  }
}
