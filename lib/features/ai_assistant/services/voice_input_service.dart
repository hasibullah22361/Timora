import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../quick_add/services/quick_add_parser.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/data/repositories/schedule_repository.dart';
import '../../schedule/presentation/providers/schedule_provider.dart';
import '../../diary/data/models/diary_entry_model.dart';
import '../../diary/data/repositories/diary_repository.dart';
import '../../diary/presentation/providers/diary_provider.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../../notifications/application/voice_announcement_service.dart';
import '../domain/models/voice_note_models.dart';
import 'voice_note_ai_service.dart';
import '../services/ai_service.dart';

class VoiceNoteExecutionSummary {
  final DiaryEntryModel? createdDiaryEntry;
  final List<TaskModel> createdTasks;
  final List<ScheduleActivity> createdActivities;
  final String message;
  final bool isDuplicate;

  VoiceNoteExecutionSummary({
    this.createdDiaryEntry,
    this.createdTasks = const [],
    this.createdActivities = const [],
    required this.message,
    this.isDuplicate = false,
  });
}

enum VoiceInputState {
  idle,
  listening,
  processing,
  success,
  error,
}

enum VoiceRoutingTarget {
  task,
  activity,
  reschedule,
  cancel,
  querySchedule,
  queryWhatShouldIDoNow,
  aiAssistant,
  auto,
}

class VoiceInputResult {
  final String transcript;
  final VoiceRoutingTarget target;
  final TaskModel? parsedTask;
  final ScheduleActivity? parsedActivity;
  final String? spokenFeedback;
  final String? errorMessage;
  final bool requiresConfirmation;
  final bool isAmbiguous;
  final String? clarificationPrompt;

  VoiceInputResult({
    required this.transcript,
    required this.target,
    this.parsedTask,
    this.parsedActivity,
    this.spokenFeedback,
    this.errorMessage,
    this.requiresConfirmation = false,
    this.isAmbiguous = false,
    this.clarificationPrompt,
  });
}

final voiceInputStateProvider = StateProvider<VoiceInputState>((ref) => VoiceInputState.idle);
final voiceTranscriptProvider = StateProvider<String>((ref) => '');

final voiceInputServiceProvider = Provider<VoiceInputService>((ref) {
  return VoiceInputService(ref);
});

class VoiceInputService {
  final Ref _ref;

  VoiceInputService(this._ref);

  /// Analyzes transcribed voice text and determines its intent
  static VoiceRoutingTarget determineTarget(String text) {
    final lower = text.toLowerCase().trim();

    // 1. Query "What should I do now?"
    if (lower.contains('what should i do now') ||
        lower.contains('what to do now') ||
        lower == 'what now' ||
        lower.contains('what do i do now')) {
      return VoiceRoutingTarget.queryWhatShouldIDoNow;
    }

    // 2. Query Schedule
    if (lower.startsWith('what do i have') ||
        lower.startsWith('what is my schedule') ||
        lower.contains('show my schedule') ||
        lower.contains('read my schedule')) {
      return VoiceRoutingTarget.querySchedule;
    }

    // 3. Cancel activity
    if (lower.startsWith('cancel ') || lower.startsWith('delete activity')) {
      return VoiceRoutingTarget.cancel;
    }

    // 4. Move / Reschedule
    if (lower.startsWith('move ') ||
        lower.startsWith('reschedule ') ||
        lower.contains('postpone ') ||
        lower.contains('delay ')) {
      return VoiceRoutingTarget.reschedule;
    }

    // 5. Schedule activity with time range (e.g. "Tomorrow I want to study AI from 9 to 12" or "Schedule gym tomorrow at 5 PM for one hour")
    if (lower.contains(' from ') ||
        lower.contains(' for one hour') ||
        lower.contains(' for 1 hour') ||
        lower.contains(' for 2 hours') ||
        lower.contains(' for 30 min') ||
        lower.startsWith('schedule ')) {
      return VoiceRoutingTarget.activity;
    }

    // 6. Explicit AI prompt
    if (lower.startsWith('ask ai') ||
        lower.startsWith('ai ') ||
        lower.contains('plan my day') ||
        lower.contains('plan my week') ||
        lower.contains('what should i do next') ||
        lower.contains('how should i') ||
        lower.contains('coach me') ||
        lower.contains('suggest')) {
      return VoiceRoutingTarget.aiAssistant;
    }

    // Default to Quick Add Task
    return VoiceRoutingTarget.task;
  }

  /// Processes spoken text, creates/modifies activities, tasks, or queries Timora state
  Future<VoiceInputResult> processVoiceInput(
    String transcript, {
    VoiceRoutingTarget target = VoiceRoutingTarget.auto,
  }) async {
    _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.processing;

    try {
      final actualTarget = (target == VoiceRoutingTarget.auto)
          ? determineTarget(transcript)
          : target;

      switch (actualTarget) {
        case VoiceRoutingTarget.queryWhatShouldIDoNow:
          return await _handleQueryWhatShouldIDoNow(transcript);

        case VoiceRoutingTarget.querySchedule:
          return await _handleQuerySchedule(transcript);

        case VoiceRoutingTarget.activity:
          return await _handleCreateActivity(transcript);

        case VoiceRoutingTarget.reschedule:
          return await _handleReschedule(transcript);

        case VoiceRoutingTarget.cancel:
          return await _handleCancel(transcript);

        case VoiceRoutingTarget.task:
          return await _handleCreateTask(transcript);

        case VoiceRoutingTarget.aiAssistant:
        default:
          return await _handleAIAssistant(transcript);
      }
    } catch (e) {
      _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.error;
      return VoiceInputResult(
        transcript: transcript,
        target: target,
        errorMessage: e.toString(),
      );
    }
  }

  Future<VoiceInputResult> _handleQueryWhatShouldIDoNow(String transcript) async {
    final rec = _ref.read(whatShouldIDoNowProvider).valueOrNull;
    String feedback = 'No activity is scheduled right now.';
    if (rec != null) {
      feedback = 'Recommended next: ${rec.title}. ${rec.reason}';
    }

    try {
      _ref.read(voiceAnnouncementServiceProvider).speakNotification(
            title: 'What Should I Do Now',
            body: feedback,
          );
    } catch (_) {}

    _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.success;
    return VoiceInputResult(
      transcript: transcript,
      target: VoiceRoutingTarget.queryWhatShouldIDoNow,
      spokenFeedback: feedback,
    );
  }

  Future<VoiceInputResult> _handleQuerySchedule(String transcript) async {
    final lower = transcript.toLowerCase();
    final isTomorrow = lower.contains('tomorrow');
    final targetDate = isTomorrow
        ? DateTime.now().add(const Duration(days: 1))
        : DateTime.now();

    final repo = _ref.read(scheduleRepositoryProvider);
    final activities = await repo.getActivitiesForDate(targetDate);

    String feedback;
    if (activities.isEmpty) {
      feedback = isTomorrow
          ? 'You have no scheduled activities for tomorrow.'
          : 'You have no scheduled activities remaining today.';
    } else {
      final active = activities
          .where((a) =>
              a.status != ActivityStatus.skipped &&
              a.status != ActivityStatus.replaced)
          .take(4)
          .map((a) => a.title)
          .join(', ');
      feedback = isTomorrow
          ? 'Tomorrow you have: $active.'
          : 'Today you have: $active.';
    }

    try {
      _ref.read(voiceAnnouncementServiceProvider).speakNotification(
            title: 'Schedule',
            body: feedback,
          );
    } catch (_) {}

    _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.success;
    return VoiceInputResult(
      transcript: transcript,
      target: VoiceRoutingTarget.querySchedule,
      spokenFeedback: feedback,
    );
  }

  Future<VoiceInputResult> _handleCreateActivity(String transcript) async {
    final lower = transcript.toLowerCase();
    final now = DateTime.now();

    // Determine target date
    DateTime targetDate = DateTime(now.year, now.month, now.day);
    if (lower.contains('tomorrow')) {
      targetDate = targetDate.add(const Duration(days: 1));
    }

    // Parse "from X to Y" (e.g. "from 9 AM to 11 AM" or "from 9 to 11")
    final fromToRegex = RegExp(r'from\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+to\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?');
    final fromToMatch = fromToRegex.firstMatch(lower);

    // Parse "at X [am|pm]"
    final atRegex = RegExp(r'at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?');
    final atMatch = atRegex.firstMatch(lower);

    // Missing time check! Per prompt: If user says "Schedule study tomorrow", do not invent a time.
    if (fromToMatch == null && atMatch == null) {
      String activityName = transcript
          .replaceAll(RegExp(r'^(schedule|tomorrow i want to|tomorrow|i want to|plan)\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*(tomorrow|today)', caseSensitive: false), '')
          .trim();
      if (activityName.isEmpty) activityName = 'this activity';
      activityName = activityName.toLowerCase();
      final prompt = 'What time would you like to $activityName ${lower.contains("tomorrow") ? "tomorrow" : "today"}?';

      try {
        _ref.read(voiceAnnouncementServiceProvider).speakNotification(
              title: 'Time Needed',
              body: prompt,
            );
      } catch (_) {}

      _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.idle;
      return VoiceInputResult(
        transcript: transcript,
        target: VoiceRoutingTarget.activity,
        isAmbiguous: true,
        clarificationPrompt: prompt,
        spokenFeedback: prompt,
      );
    }

    int startHour = 9;
    int startMinute = 0;
    int endHour = 10;
    int endMinute = 0;

    if (fromToMatch != null) {
      startHour = int.parse(fromToMatch.group(1)!);
      startMinute = fromToMatch.group(2) != null ? int.parse(fromToMatch.group(2)!) : 0;
      final startPeriod = fromToMatch.group(3);
      final endPeriod = fromToMatch.group(6);

      endHour = int.parse(fromToMatch.group(4)!);
      endMinute = fromToMatch.group(5) != null ? int.parse(fromToMatch.group(5)!) : 0;

      if (startPeriod == 'pm' && startHour < 12) startHour += 12;
      if (startPeriod == 'am' && startHour == 12) startHour = 0;

      if (endPeriod == 'pm' && endHour < 12) endHour += 12;
      if (endPeriod == 'am' && endHour == 12) endHour = 0;

      if (startPeriod == null && endPeriod == 'pm' && endHour > 12 && startHour < 12 && startHour >= endHour - 12) {
        startHour += 12;
      }
      if (endHour < startHour && endHour < 12) {
        endHour += 12;
      }
    } else if (atMatch != null) {
      startHour = int.parse(atMatch.group(1)!);
      startMinute = atMatch.group(2) != null ? int.parse(atMatch.group(2)!) : 0;
      final period = atMatch.group(3);
      if (period == 'pm' && startHour < 12) startHour += 12;
      if (period == 'am' && startHour == 12) startHour = 0;

      int durationMins = 60;
      if (lower.contains('for 30 min') || lower.contains('for half an hour')) durationMins = 30;
      if (lower.contains('for 2 hours') || lower.contains('for two hours')) durationMins = 120;
      if (lower.contains('for 3 hours') || lower.contains('for three hours')) durationMins = 180;

      final startDt = DateTime(targetDate.year, targetDate.month, targetDate.day, startHour, startMinute);
      final endDt = startDt.add(Duration(minutes: durationMins));
      endHour = endDt.hour;
      endMinute = endDt.minute;
    }

    // Extract title
    String title = transcript
        .replaceAll(RegExp(r'^(schedule|tomorrow i want to|tomorrow|i want to|plan)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(from\s+\d+.*|at\s+\d+.*)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(tomorrow|today)', caseSensitive: false), '')
        .trim();

    if (title.isEmpty) title = 'Planned Session';
    title = title[0].toUpperCase() + title.substring(1);

    final startTime = DateTime(targetDate.year, targetDate.month, targetDate.day, startHour, startMinute);
    final endTime = DateTime(targetDate.year, targetDate.month, targetDate.day, endHour, endMinute);

    final activity = ScheduleActivity(
      id: const Uuid().v4(),
      title: title,
      date: targetDate,
      startTime: startTime,
      endTime: endTime,
      category: 'Productivity',
      icon: '📌',
      status: ActivityStatus.upcoming,
      isOverridden: true,
      createdAt: DateTime.now(),
    );

    await _ref.read(scheduleNotifierProvider).addActivity(activity);

    final feedback = 'Scheduled "$title" for ${_formatDate(targetDate)} from ${_formatTime(startTime)} to ${_formatTime(endTime)}.';
    try {
      _ref.read(voiceAnnouncementServiceProvider).speakNotification(
            title: 'Schedule Created',
            body: feedback,
          );
    } catch (_) {}

    _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.success;
    return VoiceInputResult(
      transcript: transcript,
      target: VoiceRoutingTarget.activity,
      parsedActivity: activity,
      spokenFeedback: feedback,
    );
  }

  Future<VoiceInputResult> _handleReschedule(String transcript) async {
    final lower = transcript.toLowerCase();
    final repo = _ref.read(scheduleRepositoryProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todayActivities = await repo.getActivitiesForDate(today);
    final tomorrowActivities = await repo.getActivitiesForDate(tomorrow);
    final allActivities = [...todayActivities, ...tomorrowActivities];

    // Find target activity matching keyword in transcript
    ScheduleActivity? match;
    for (final a in allActivities) {
      final aLower = a.title.toLowerCase();
      if (lower.contains(aLower) ||
          (aLower.contains('research') && lower.contains('research')) ||
          (aLower.contains('study') && lower.contains('study')) ||
          (aLower.contains('gym') && lower.contains('gym'))) {
        match = a;
        break;
      }
    }

    match ??= allActivities.firstOrNull;
    if (match == null) {
      return VoiceInputResult(
        transcript: transcript,
        target: VoiceRoutingTarget.reschedule,
        errorMessage: 'No matching scheduled activity found to reschedule.',
      );
    }

    // Parse target time (e.g. "to 9 PM")
    final atRegex = RegExp(r'(to|at)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?');
    final atMatch = atRegex.firstMatch(lower);
    int newHour = 21;
    int newMinute = 0;
    if (atMatch != null) {
      newHour = int.parse(atMatch.group(2)!);
      newMinute = atMatch.group(3) != null ? int.parse(atMatch.group(3)!) : 0;
      final period = atMatch.group(4);
      if (period == 'pm' && newHour < 12) newHour += 12;
      if (period == 'am' && newHour == 12) newHour = 0;
    }

    final duration = match.endTime.difference(match.startTime);
    final actDate = match.date;
    final newStart = DateTime(actDate.year, actDate.month, actDate.day, newHour, newMinute);
    final newEnd = newStart.add(duration);

    final updated = match.copyWith(
      startTime: newStart,
      endTime: newEnd,
      status: ActivityStatus.upcoming,
      isOverridden: true,
      updatedAt: DateTime.now(),
    );

    await _ref.read(scheduleNotifierProvider).updateActivity(updated);

    final feedback = 'Rescheduled "${match.title}" to ${_formatTime(newStart)}.';
    try {
      _ref.read(voiceAnnouncementServiceProvider).speakNotification(
            title: 'Schedule Updated',
            body: feedback,
          );
    } catch (_) {}

    _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.success;
    return VoiceInputResult(
      transcript: transcript,
      target: VoiceRoutingTarget.reschedule,
      parsedActivity: updated,
      spokenFeedback: feedback,
    );
  }

  Future<VoiceInputResult> _handleCancel(String transcript) async {
    final lower = transcript.toLowerCase();
    final repo = _ref.read(scheduleRepositoryProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final isTomorrow = lower.contains('tomorrow');
    final targetDate = isTomorrow ? tomorrow : today;
    final activities = await repo.getActivitiesForDate(targetDate);

    // Filter candidate matches
    final matches = activities.where((a) {
      final aLower = a.title.toLowerCase();
      final clean = lower
          .replaceAll(RegExp(r"[^\w\s]"), ' ')
          .replaceAll(RegExp(r'\b(cancel|today|todays|tomorrow|tomorrows|delete|activity|remove|session|my|the|a)\b'), ' ')
          .trim();
      final words = clean.split(RegExp(r'\s+')).where((w) => w.length >= 2);
      for (final w in words) {
        if (aLower.contains(w)) return true;
      }
      return false;
    }).toList();

    // Check for ambiguous cancellation when multiple sessions exist
    if (matches.length > 1) {
      final titles = matches.map((m) => '${m.title} at ${_formatTime(m.startTime)}').join(' or ');
      final prompt = 'You have multiple sessions: $titles. Which research session would you like to cancel?';
      try {
        _ref.read(voiceAnnouncementServiceProvider).speakNotification(
              title: 'Clarification Needed',
              body: prompt,
            );
      } catch (_) {}

      return VoiceInputResult(
        transcript: transcript,
        target: VoiceRoutingTarget.cancel,
        requiresConfirmation: true,
        isAmbiguous: true,
        clarificationPrompt: prompt,
        spokenFeedback: prompt,
      );
    }

    if (matches.length == 1) {
      final match = matches.first;
      await _ref.read(scheduleNotifierProvider).markSkipped(match);
      final feedback = 'Cancelled "${match.title}".';
      try {
        _ref.read(voiceAnnouncementServiceProvider).speakNotification(
              title: 'Activity Cancelled',
              body: feedback,
            );
      } catch (_) {}

      _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.success;
      return VoiceInputResult(
        transcript: transcript,
        target: VoiceRoutingTarget.cancel,
        parsedActivity: match,
        spokenFeedback: feedback,
      );
    }

    return VoiceInputResult(
      transcript: transcript,
      target: VoiceRoutingTarget.cancel,
      errorMessage: 'Could not find the activity to cancel.',
    );
  }

  Future<VoiceInputResult> _handleCreateTask(String transcript) async {
    final parsed = QuickAddParser.parse(transcript);
    final task = parsed.toTaskModel();
    await _ref.read(taskNotifierProvider).createTask(task);

    _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.success;
    return VoiceInputResult(
      transcript: transcript,
      target: VoiceRoutingTarget.task,
      parsedTask: task,
      spokenFeedback: 'Created task "${task.title}".',
    );
  }

  Future<VoiceInputResult> _handleAIAssistant(String transcript) async {
    final cleanPrompt = transcript
        .replaceFirst(RegExp(r'^(ask ai|ai)\s*', caseSensitive: false), '')
        .trim();

    await _ref.read(aiMessagesProvider.notifier).sendMessage(cleanPrompt.isNotEmpty ? cleanPrompt : transcript);

    _ref.read(voiceInputStateProvider.notifier).state = VoiceInputState.success;
    return VoiceInputResult(
      transcript: transcript,
      target: VoiceRoutingTarget.aiAssistant,
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Today';
    }
    final tom = now.add(const Duration(days: 1));
    if (dt.day == tom.day && dt.month == tom.month && dt.year == tom.year) {
      return 'Tomorrow';
    }
    return '${dt.month}/${dt.day}';
  }

  /// Processes natural language voice note into Diary reflections and Actionable Tasks.
  Future<VoiceNoteExtractionResult> processVoiceNote(
    String transcript, {
    DateTime? referenceDate,
  }) async {
    final aiService = _ref.read(voiceNoteAIServiceProvider);
    return await aiService.processVoiceNote(
      transcript,
      referenceDate: referenceDate,
    );
  }

  /// Finds the earliest conflict-free slot on the given [date] for the specified [duration].
  Future<DateTimeRange?> findConflictFreeSlot({
    required DateTime date,
    required Duration duration,
    DateTime? preferredStart,
    int startHour = 9,
    int endHour = 22,
  }) async {
    final repo = _ref.read(scheduleRepositoryProvider);
    final targetDate = DateTime(date.year, date.month, date.day);
    final allActivities = await repo.getActivitiesForDate(targetDate);
    final active = allActivities
        .where((a) =>
            a.status != ActivityStatus.completed &&
            a.status != ActivityStatus.skipped &&
            a.status != ActivityStatus.replaced)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // 1. If preferredStart is given, check if that exact slot is free
    if (preferredStart != null) {
      final candidateEnd = preferredStart.add(duration);
      bool overlaps = false;
      for (final act in active) {
        if (preferredStart.isBefore(act.endTime) && candidateEnd.isAfter(act.startTime)) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) {
        return DateTimeRange(start: preferredStart, end: candidateEnd);
      }
    }

    // 2. Otherwise search for an open slot within daytime hours
    DateTime candidate = preferredStart ?? DateTime(targetDate.year, targetDate.month, targetDate.day, startHour, 0);
    final endLimit = DateTime(targetDate.year, targetDate.month, targetDate.day, endHour, 0);

    final now = DateTime.now();
    if (targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day) {
      if (candidate.isBefore(now)) {
        final remainder = now.minute % 5;
        final minutesToAdd = (remainder == 0 ? 5 : (5 - remainder)) + 5;
        candidate = now
            .add(Duration(minutes: minutesToAdd))
            .subtract(Duration(seconds: now.second, milliseconds: now.millisecond));
      }
    }

    while (candidate.add(duration).isBefore(endLimit) || candidate.add(duration).isAtSameMomentAs(endLimit)) {
      final candidateEnd = candidate.add(duration);
      bool hasOverlap = false;

      for (final act in active) {
        if (candidate.isBefore(act.endTime) && candidateEnd.isAfter(act.startTime)) {
          hasOverlap = true;
          candidate = act.endTime.add(const Duration(minutes: 5));
          break;
        }
      }

      if (!hasOverlap) {
        return DateTimeRange(start: candidate, end: candidateEnd);
      }
    }

    return null;
  }

  /// Executes user-confirmed actions from a voice note:
  /// creates Diary entry (if enabled), creates Tasks, and optionally schedules them.
  Future<VoiceNoteExecutionSummary> executeVoiceNoteActions({
    required VoiceNoteExtractionResult result,
    bool saveDiary = true,
    bool shouldSchedule = false,
    List<ExtractedVoiceTask>? selectedTasks,
  }) async {
    final aiService = _ref.read(voiceNoteAIServiceProvider);

    // Guard against duplicate processing
    if (aiService.isAlreadyProcessed(result.signature)) {
      return VoiceNoteExecutionSummary(
        message: 'This voice note was already processed.',
        isDuplicate: true,
      );
    }

    DiaryEntryModel? createdDiary;
    final createdTasks = <TaskModel>[];
    final createdActivities = <ScheduleActivity>[];
    final now = DateTime.now();

    // 1. Create Diary Entry if requested and available
    if (saveDiary && result.hasDiary) {
      final diaryRepo = _ref.read(diaryRepositoryProvider);
      final todayNormalized = DateTime(now.year, now.month, now.day);
      final existingEntries = await diaryRepo.getEntriesForDate(todayNormalized);
      final existingExact = existingEntries.where(
        (e) => e.content.trim() == result.diaryContent!.trim(),
      ).firstOrNull;

      if (existingExact != null) {
        createdDiary = existingExact;
      } else {
        final diaryId = const Uuid().v4();
        createdDiary = DiaryEntryModel(
          id: diaryId,
          date: todayNormalized,
          title: result.diaryTitle ?? 'Voice Reflection',
          content: result.diaryContent!,
          moodKey: result.diaryMoodKey,
          mood: (result.diaryMoodKey == 'happy' || result.diaryMoodKey == 'excited') ? 4 : 3,
          tags: const ['voice-note'],
          createdAt: now,
        );

        await _ref.read(diaryNotifierProvider.notifier).saveEntry(createdDiary);
      }
    }

    // 2. Process tasks
    final tasksToCreate = selectedTasks ?? result.tasks.where((t) => t.isSelected).toList();
    final taskRepo = _ref.read(taskRepositoryProvider);
    final existingTasks = await taskRepo.getTasks();

    for (final extracted in tasksToCreate) {
      final isTaskDuplicate = existingTasks.any((t) =>
        t.status != TaskStatus.completed &&
        t.status != TaskStatus.cancelled &&
        t.title.trim().toLowerCase() == extracted.title.trim().toLowerCase() &&
        t.dueDate?.year == extracted.dueDate?.year &&
        t.dueDate?.month == extracted.dueDate?.month &&
        t.dueDate?.day == extracted.dueDate?.day,
      );

      if (isTaskDuplicate) {
        continue;
      }

      String? scheduledActivityId;

      if (shouldSchedule) {
        final targetDate = extracted.dueDate ?? DateTime(now.year, now.month, now.day);
        final duration = Duration(
          minutes: extracted.estimatedDurationMinutes > 0 ? extracted.estimatedDurationMinutes : 30,
        );

        DateTime? preferredStart;
        if (extracted.startTime != null) {
          preferredStart = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            extracted.startTime!.hour,
            extracted.startTime!.minute,
          );
        } else if (extracted.dueTime != null) {
          preferredStart = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            extracted.dueTime!.hour,
            extracted.dueTime!.minute,
          );
        }

        final slot = await findConflictFreeSlot(
          date: targetDate,
          duration: duration,
          preferredStart: preferredStart,
        );

        if (slot != null) {
          final actId = const Uuid().v4();
          final activity = ScheduleActivity(
            id: actId,
            title: extracted.title,
            date: targetDate,
            startTime: slot.start,
            endTime: slot.end,
            category: extracted.category,
            icon: '🎙️',
            status: ActivityStatus.upcoming,
            isOverridden: true,
            createdAt: now,
          );

          try {
            await _ref.read(scheduleNotifierProvider).addActivity(activity);
            createdActivities.add(activity);
            scheduledActivityId = actId;
            extracted.startTime = TimeOfDay(hour: slot.start.hour, minute: slot.start.minute);
            extracted.endTime = TimeOfDay(hour: slot.end.hour, minute: slot.end.minute);
          } catch (e) {
            debugPrint('[QuickVoiceNote] Schedule activity insertion skipped: $e');
          }
        }
      }

      final taskModel = extracted.toTaskModel(scheduleActivityId: scheduledActivityId);
      await _ref.read(taskNotifierProvider).createTask(taskModel);
      createdTasks.add(taskModel);
    }

    // Mark as processed to prevent accidental duplicate clicks
    aiService.markProcessed(result.signature);

    final summaryParts = <String>[];
    if (createdDiary != null) {
      summaryParts.add('Saved Diary entry');
    }
    if (createdTasks.isNotEmpty) {
      summaryParts.add('created ${createdTasks.length} task${createdTasks.length == 1 ? '' : 's'}');
    }
    if (createdActivities.isNotEmpty) {
      summaryParts.add('scheduled ${createdActivities.length} session${createdActivities.length == 1 ? '' : 's'}');
    }

    final message = summaryParts.isNotEmpty
        ? '✨ ${summaryParts.join(' & ')}.'
        : '✨ Voice note processed.';

    return VoiceNoteExecutionSummary(
      createdDiaryEntry: createdDiary,
      createdTasks: createdTasks,
      createdActivities: createdActivities,
      message: message,
    );
  }
}
