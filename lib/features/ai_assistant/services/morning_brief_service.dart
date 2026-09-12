import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/providers/mock_ai_provider.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/data/repositories/schedule_repository.dart';
import '../../analytics/data/models/analytics_models.dart';
import '../../analytics/services/insights_engine_service.dart';
import '../../settings/data/repositories/notification_settings_repository.dart';
import '../../notifications/application/voice_announcement_service.dart';

class MorningBriefResult {
  final String dateString;
  final String briefText;
  final List<String> priorities;
  final String? firstActivityTitle;
  final DateTime? firstActivityTime;
  final String? peakFocusWindow;
  final int totalTasksToday;
  final int scheduledActivitiesCount;
  final String duration;
  final bool generatedWithAI;

  const MorningBriefResult({
    required this.dateString,
    required this.briefText,
    this.priorities = const [],
    this.firstActivityTitle,
    this.firstActivityTime,
    this.peakFocusWindow,
    this.totalTasksToday = 0,
    this.scheduledActivitiesCount = 0,
    required this.duration,
    required this.generatedWithAI,
  });
}

final morningBriefServiceProvider = Provider<MorningBriefService>((ref) {
  return MorningBriefService(ref);
});

final todayMorningBriefProvider = FutureProvider<MorningBriefResult>((ref) async {
  final service = ref.watch(morningBriefServiceProvider);
  return service.generateMorningBrief();
});

class MorningBriefService {
  final Ref _ref;

  MorningBriefService(this._ref);

  /// Generates a personalized morning briefing strictly from real Timora data.
  Future<MorningBriefResult> generateMorningBrief({String? durationOverride}) async {
    final settingsRepo = _ref.read(notificationSettingsRepositoryProvider);
    final duration = durationOverride ?? settingsRepo.morningBriefDuration;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final dateString = DateFormat('EEEE, MMMM d').format(now);

    // 1. Fetch real Timora data
    final taskRepo = _ref.read(taskRepositoryProvider);
    final scheduleRepo = _ref.read(scheduleRepositoryProvider);

    List<TaskModel> allTasks = [];
    try {
      allTasks = await taskRepo.getTasks();
    } catch (_) {}

    List<ScheduleActivity> todayActivities = [];
    try {
      todayActivities = await scheduleRepo.getActivitiesForDate(todayStart);
    } catch (_) {}

    AnalyticsInsight? topInsight;
    try {
      final insights = await _ref.read(timoraInsightsProvider(AnalyticsPeriod.today).future);
      if (insights.isNotEmpty) {
        topInsight = insights.first;
      }
    } catch (_) {}

    // Extract pending tasks due today or without a due date that are high/urgent
    final pendingTasks = allTasks.where((t) => !t.isCompleted && !t.isDeleted).toList();
    final todayTasks = pendingTasks.where((t) {
      if (t.dueDate != null) {
        return !t.dueDate!.isBefore(todayStart) && !t.dueDate!.isAfter(todayEnd);
      }
      return false;
    }).toList();

    // Overdue tasks
    final overdueTasks = pendingTasks.where((t) {
      if (t.dueDate != null) {
        return t.dueDate!.isBefore(todayStart);
      }
      return false;
    }).toList();

    // High priority tasks
    final highPriorityTasks = pendingTasks.where((t) {
      return t.priority == TaskPriority.high || t.priority == TaskPriority.urgent;
    }).toList();

    // Sorted today schedule activities
    todayActivities.sort((a, b) => a.startTime.compareTo(b.startTime));
    final upcomingActivities = todayActivities.where((a) => a.endTime.isAfter(now)).toList();
    final firstActivity = upcomingActivities.isNotEmpty
        ? upcomingActivities.first
        : (todayActivities.isNotEmpty ? todayActivities.first : null);

    // Extract top priorities (unique, real titles)
    final Set<String> prioritySet = {};
    for (final t in todayTasks) {
      if (t.priority == TaskPriority.urgent || t.priority == TaskPriority.high) {
        prioritySet.add(t.title);
      }
    }
    for (final t in highPriorityTasks) {
      prioritySet.add(t.title);
    }
    for (final t in todayTasks) {
      prioritySet.add(t.title);
    }
    for (final t in overdueTasks) {
      prioritySet.add(t.title);
    }
    final priorities = prioritySet.take(3).toList();

    // 2. Format Structured Context for AI / Generator
    final timeFormat = DateFormat('h:mm a');
    final contextBuffer = StringBuffer();
    contextBuffer.writeln('Current Date: $dateString');
    contextBuffer.writeln('Duration Mode: $duration');
    contextBuffer.writeln('Priorities count: ${priorities.length}');
    if (priorities.isNotEmpty) {
      contextBuffer.writeln('Top Priorities: ${priorities.join(", ")}');
    }
    if (firstActivity != null) {
      contextBuffer.writeln('First Activity: "${firstActivity.title}" at ${timeFormat.format(firstActivity.startTime)}');
    }
    if (todayActivities.isNotEmpty) {
      contextBuffer.writeln('Total Scheduled Activities: ${todayActivities.length}');
      final timelineSummary = todayActivities
          .map((a) => '${a.title} (${timeFormat.format(a.startTime)})')
          .take(4)
          .join(', ');
      contextBuffer.writeln('Timeline Summary: $timelineSummary');
    }
    if (topInsight != null && topInsight.hasSufficientData) {
      contextBuffer.writeln('Productivity Window / Insight: ${topInsight.description}');
    }
    if (overdueTasks.isNotEmpty) {
      contextBuffer.writeln('Urgent Overdue Tasks: ${overdueTasks.map((t) => t.title).take(2).join(", ")}');
    }

    // 3. Generate Brief with AI or Local Deterministic Fallback
    String briefText = '';
    bool generatedWithAI = false;

    try {
      final ai = _ref.read(aiProvider);
      final prompt = _buildAIPrompt(
        duration: duration,
        priorities: priorities,
        firstActivity: firstActivity,
        todayActivities: todayActivities,
        topInsight: topInsight,
        overdueTasks: overdueTasks,
      );

      final response = await ai.generateResponse(
        prompt: prompt,
        contextContext: contextBuffer.toString(),
        history: [],
      );

      final content = response.content.trim();
      if (content.isNotEmpty && !content.toLowerCase().contains('unsupported') && !content.toLowerCase().contains('error')) {
        briefText = content;
        generatedWithAI = true;
      }
    } catch (_) {
      // Graceful offline fallback
    }

    if (briefText.isEmpty) {
      briefText = _generateDeterministicBrief(
        duration: duration,
        priorities: priorities,
        firstActivity: firstActivity,
        todayActivities: todayActivities,
        topInsight: topInsight,
        overdueTasks: overdueTasks,
      );
    }

    return MorningBriefResult(
      dateString: dateString,
      briefText: briefText,
      priorities: priorities,
      firstActivityTitle: firstActivity?.title,
      firstActivityTime: firstActivity?.startTime,
      peakFocusWindow: topInsight?.actionData?['label'] as String?,
      totalTasksToday: todayTasks.length,
      scheduledActivitiesCount: todayActivities.length,
      duration: duration,
      generatedWithAI: generatedWithAI,
    );
  }

  /// Builds a constrained, hallucination-free prompt for the AI Provider.
  String _buildAIPrompt({
    required String duration,
    required List<String> priorities,
    required ScheduleActivity? firstActivity,
    required List<ScheduleActivity> todayActivities,
    required AnalyticsInsight? topInsight,
    required List<TaskModel> overdueTasks,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Task: Generate a personalized, natural spoken Morning Brief for the user.');
    buffer.writeln('Tone: Encouraging, energetic, crisp, focused.');
    buffer.writeln('CRITICAL: Never invent tasks, activities, or names not provided in the context.');
    buffer.writeln('Length & Content Rules:');

    if (duration == 'short') {
      buffer.writeln('- SHORT mode: Keep to 2 sentences. Mention top priority and first activity only.');
    } else if (duration == 'detailed') {
      buffer.writeln('- DETAILED mode: 4 to 5 sentences. Cover priorities, timeline, focus window, overdue reminders, and an encouraging closing tip.');
    } else {
      buffer.writeln('- NORMAL mode (default): 3 sentences. Cover today\'s priorities, first activity, and recommended focus time.');
    }

    return buffer.toString();
  }

  /// Deterministic local generation ensuring 100% offline functionality with zero hallucination.
  String _generateDeterministicBrief({
    required String duration,
    required List<String> priorities,
    required ScheduleActivity? firstActivity,
    required List<ScheduleActivity> todayActivities,
    required AnalyticsInsight? topInsight,
    required List<TaskModel> overdueTasks,
  }) {
    final buffer = StringBuffer();
    final timeFormat = DateFormat('h:mm a');

    // Greeting
    buffer.write('Good morning. ');

    if (priorities.isEmpty && firstActivity == null && todayActivities.isEmpty) {
      return 'Good morning. Your schedule is clear today. Take this opportunity to make progress on your personal goals or plan ahead.';
    }

    if (duration == 'short') {
      if (priorities.isNotEmpty) {
        buffer.write('Your main priority today is "${priorities.first}". ');
      }
      if (firstActivity != null) {
        buffer.write('Your first activity is "${firstActivity.title}" at ${timeFormat.format(firstActivity.startTime)}.');
      } else {
        buffer.write('Make today count.');
      }
      return buffer.toString().trim();
    }

    // Normal & Detailed
    if (priorities.isNotEmpty) {
      if (priorities.length == 1) {
        buffer.write('Your top focus today is "${priorities[0]}". ');
      } else if (priorities.length == 2) {
        buffer.write('You have two key priorities today: first, "${priorities[0]}", and second, "${priorities[1]}". ');
      } else {
        buffer.write('You have three key priorities today: first, "${priorities[0]}"; second, "${priorities[1]}"; and third, "${priorities[2]}". ');
      }
    } else if (todayActivities.isNotEmpty) {
      buffer.write('You have ${todayActivities.length} activities scheduled for today. ');
    }

    if (firstActivity != null) {
      buffer.write('Your day starts with "${firstActivity.title}" at ${timeFormat.format(firstActivity.startTime)}. ');
    }

    if (duration == 'detailed') {
      if (overdueTasks.isNotEmpty) {
        buffer.write('Note that "${overdueTasks.first.title}" is pending from earlier this week. ');
      }
      if (topInsight != null && topInsight.hasSufficientData) {
        final rec = topInsight.recommendation.isNotEmpty ? topInsight.recommendation : topInsight.description;
        buffer.write('$rec ');
      }
      buffer.write('Stay focused and have a productive day.');
    } else {
      // Normal closing
      if (topInsight != null && topInsight.hasSufficientData && topInsight.actionData?['startHour'] != null) {
        final startH = topInsight.actionData!['startHour'] as int;
        final timeStr = startH > 12 ? '${startH - 12} PM' : '$startH AM';
        buffer.write('Your peak productivity block starts around $timeStr.');
      } else {
        buffer.write("Let's build strong momentum today.");
      }
    }

    return buffer.toString().trim();
  }

  /// Speaks the Morning Brief using the existing Timora TTS system.
  /// Respects user's male/female preference and silent/vibrate mode.
  Future<bool> speakBrief(String text, {bool checkAutoPlay = false}) async {
    final settingsRepo = _ref.read(notificationSettingsRepositoryProvider);
    final isMale = settingsRepo.morningBriefVoiceGender == 'male';
    final voiceService = _ref.read(voiceAnnouncementServiceProvider);

    return voiceService.speakMorningBrief(
      briefText: text,
      isMale: isMale,
      speed: settingsRepo.speakingSpeed,
      checkAutoPlay: checkAutoPlay,
    );
  }

  /// Stops any currently playing speech.
  Future<void> stopSpeaking() async {
    final voiceService = _ref.read(voiceAnnouncementServiceProvider);
    await voiceService.stop();
  }
}
