import 'package:intl/intl.dart';
import '../../schedule/data/models/schedule_activity.dart';

class NotificationMessagePair {
  final String title;
  final String notificationBody;
  final String spokenMessage;

  const NotificationMessagePair({
    required this.title,
    required this.notificationBody,
    required this.spokenMessage,
  });
}

/// NotificationMessageGenerator — Centralized generator for synchronized visible
/// text notifications and natural human-like spoken announcements.
class NotificationMessageGenerator {
  /// Clean text from Markdown artifacts, bullet glyphs, and multiple whitespaces.
  static String clean(String text) {
    return text
        .replaceAll(RegExp(r'[*#_`~]'), '')
        .replaceAll(RegExp(r'[•►▪■\-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Convert raw task names into clean, natural spoken nouns.
  /// Example: 'Task: Complete Python Course' -> 'Python course'
  ///          'Complete Python Course' -> 'Python course'
  static String normalizeTaskSpokenName(String rawName) {
    String c = clean(rawName);
    c = c.replaceFirst(RegExp(r'^task\s*[:\-•]\s*', caseSensitive: false), '');
    final lower = c.toLowerCase();
    if (lower.startsWith('complete ')) {
      c = c.substring(9).trim();
    } else if (lower.startsWith('finish ')) {
      c = c.substring(7).trim();
    }
    if (c.toLowerCase().endsWith(' course')) {
      final base = c.substring(0, c.length - 7);
      return '$base course';
    }
    return c;
  }

  /// Convert raw activity names into smooth, natural spoken nouns.
  /// Example: 'Workout' -> 'workout'
  ///          'Gym' -> 'workout'
  ///          'AI and Data Science study' -> 'AI and Data Science study session'
  ///          'Deep Work' -> 'deep work session'
  static String normalizeActivitySpokenName(String rawName) {
    final original = clean(rawName);
    if (original.isEmpty) return 'activity';

    final lower = original.toLowerCase();

    // Avoid duplicate "session session" or "time time"
    if (lower.endsWith(' session') || lower.endsWith(' time') || lower.endsWith(' break')) {
      return original;
    }

    if (lower.endsWith(' study')) {
      return '$original session';
    }

    switch (lower) {
      case 'gym':
        return 'workout';
      case 'study':
        return 'study session';
      case 'deep work':
        return 'deep work session';
      case 'focus':
        return 'focus session';
      case 'research':
        return 'research session';
      case 'reading':
        return 'reading session';
      case 'meditation':
        return 'meditation session';
      case 'rest':
        return 'rest break';
      case 'nap':
        return 'nap break';
      case 'break':
        return 'break';
      case 'lunch':
      case 'breakfast':
      case 'dinner':
      case 'snack':
      case 'prayer':
      case 'meeting':
      case 'walk':
      case 'workout':
      case 'exercise':
      case 'run':
      case 'yoga':
        return lower;
      default:
        return original;
    }
  }


  // ─────────────────────────────────────────────────────────────────────────
  // PRE-REMINDERS (10 min & 5 min)
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates a pre-reminder pair (10 minutes or 5 minutes before activity).
  static NotificationMessagePair generatePreReminder({
    required String activityName,
    required int minutesBefore,
    int? variationIndex,
  }) {
    final cleanName = clean(activityName);
    final display = cleanName.isEmpty ? 'Activity' : cleanName;
    final spoken = normalizeActivitySpokenName(display);

    final title = '$display in $minutesBefore min';
    final text = '$display starts in $minutesBefore minutes. Get ready.';

    final variations = <String>[
      'Your $spoken starts in $minutesBefore minutes. Get ready.',
      'Hey, your $spoken starts in $minutesBefore minutes. Get ready.',
      'Heads up, your $spoken starts in $minutesBefore minutes.',
      'Your $spoken is coming up in $minutesBefore minutes.',
    ];

    final index = (variationIndex ?? 0) % variations.length;
    final speech = variations[index];

    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: speech,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVITY START
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates an activity start announcement pair.
  static NotificationMessagePair generateStartMessage({
    required String activityName,
    DateTime? startTime,
    int? variationIndex,
  }) {
    final cleanName = clean(activityName);
    final display = cleanName.isEmpty ? 'Activity' : cleanName;
    final spoken = normalizeActivitySpokenName(display);
    final timeStr = startTime != null ? formatSpeechTime(startTime) : null;

    final title = "It's time for $display";
    final text = "It's time for $display.";

    final variations = <String>[
      if (timeStr != null)
        'Hey, your $spoken starts at $timeStr.'
      else
        "It's time for your $spoken. Your activity starts now.",
      "It's time for your $spoken.",
      'Hey, your $spoken is starting now.',
      'Ready? Your $spoken starts now.',
      'Your scheduled $spoken is starting now.',
    ];

    final index = (variationIndex ?? 0) % variations.length;
    final speech = variations[index];

    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: speech,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TASK START & REMINDER
  // ─────────────────────────────────────────────────────────────────────────

  static NotificationMessagePair generateTaskReminder({
    required String taskName,
    required int minutesBefore,
    int? variationIndex,
  }) {
    final cleanName = clean(taskName);
    final display = cleanName.isEmpty ? 'Task' : cleanName;
    final spokenTask = normalizeTaskSpokenName(display);

    final title = '$display in $minutesBefore min';
    final text = '$display is due in $minutesBefore minutes.';

    final variations = <String>[
      'Your $display task starts in $minutesBefore minutes. Get ready.',
      'Hey, your $spokenTask task starts in $minutesBefore minutes.',
      'Heads up, $spokenTask is due in $minutesBefore minutes.',
    ];

    final index = (variationIndex ?? 0) % variations.length;
    final speech = variations[index];

    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: speech,
    );
  }

  static NotificationMessagePair generateTaskStart({
    required String taskName,
    DateTime? scheduledTime,
    int? variationIndex,
  }) {
    final cleanName = clean(taskName);
    final display = cleanName.isEmpty ? 'Task' : cleanName;
    final spokenTask = normalizeTaskSpokenName(display);
    final isActionVerb = display.toLowerCase().startsWith('complete ') ||
        display.toLowerCase().startsWith('finish ') ||
        cleanName.toLowerCase().startsWith('task: complete') ||
        cleanName.toLowerCase().startsWith('task: finish');

    final title = 'Task: $display';
    final text = "It's time for $display.";

    final variations = isActionVerb
        ? <String>[
            "It's time to work on your $spokenTask.",
            "Ready? It's time to start your $spokenTask task.",
            "Your scheduled task, $spokenTask, is starting now.",
            "Your $display task starts now.",
          ]
        : <String>[
            "Your $display task starts now.",
            "It's time to work on your $spokenTask.",
            "Ready? It's time to start your $spokenTask task.",
            "Your scheduled task, $spokenTask, is starting now.",
          ];

    final index = (variationIndex ?? 0) % variations.length;
    final speech = variations[index];

    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: speech,
    );
  }


  // ─────────────────────────────────────────────────────────────────────────
  // FOCUS SESSION START
  // ─────────────────────────────────────────────────────────────────────────

  static NotificationMessagePair generateFocusSessionStart({
    required int durationMinutes,
    String? sessionTitle,
    int? variationIndex,
  }) {
    final cleanTitle = sessionTitle != null ? clean(sessionTitle) : null;
    final title = cleanTitle != null && cleanTitle.isNotEmpty
        ? 'Focus: $cleanTitle'
        : '$durationMinutes-Minute Focus Session';
    final text = 'Your $durationMinutes-minute focus session is starting.';

    final variations = <String>[
      "Your $durationMinutes-minute focus session is starting now. Let's get started.",
      "Ready for deep focus? Your $durationMinutes-minute session starts now.",
      "It's time for your $durationMinutes-minute focus session. Let's get started.",
      "Your focus session is starting now. Let's make time work for you.",
    ];

    final index = (variationIndex ?? 0) % variations.length;
    final speech = variations[index];

    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: speech,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TASK MISSED / RECOVERY
  // ─────────────────────────────────────────────────────────────────────────

  static NotificationMessagePair generateTaskMissed({
    required String taskName,
    int? variationIndex,
  }) {
    final cleanName = clean(taskName);
    final display = cleanName.isEmpty ? 'task' : cleanName;
    final spokenTask = normalizeTaskSpokenName(display);

    final title = 'Missed: $display';
    final text = 'You missed your scheduled $display. Tap to reschedule.';

    final variations = <String>[
      "You missed your $spokenTask session. Don't worry — Timora can help you reschedule it.",
      "You missed your scheduled $spokenTask. Timora can help you find a new time.",
      "Looks like you missed $spokenTask. Let's reschedule it and stay on track.",
    ];

    final index = (variationIndex ?? 0) % variations.length;
    final speech = variations[index];

    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: speech,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REPORTS (DAILY, WEEKLY, MONTHLY)
  // ─────────────────────────────────────────────────────────────────────────

  static NotificationMessagePair generateReportReady({
    required String reportType,
    int? variationIndex,
  }) {
    final type = reportType.toLowerCase().trim();
    String title;
    String text;
    List<String> variations;

    if (type.contains('week')) {
      title = 'Weekly Report Ready';
      text = 'Your Timora weekly productivity report is ready.';
      variations = [
        'Your Timora weekly report is ready. You can check how your week went.',
        'Your weekly productivity report is ready. Tap to view your insights.',
      ];
    } else if (type.contains('month')) {
      title = 'Monthly Review Ready';
      text = 'Your Timora monthly summary is ready.';
      variations = [
        'Your Timora monthly report is ready to review.',
        'Your monthly productivity review is now available.',
      ];
    } else {
      title = 'Daily Report Ready';
      text = 'Your Timora daily summary is ready.';
      variations = [
        'Your Timora daily report is ready. You can check how your day went.',
        'Your daily summary is ready. Tap to see how your day went.',
        'Here is your daily wrap-up. You can check your progress for today.',
      ];
    }

    final index = (variationIndex ?? 0) % variations.length;
    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: variations[index],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVITY END
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates an activity end announcement pair for the final activity.
  static NotificationMessagePair generateEndMessage({
    required String activityName,
    int? variationIndex,
  }) {
    final cleanName = clean(activityName);
    final display = cleanName.isEmpty ? 'Activity' : cleanName;
    final spoken = normalizeActivitySpokenName(display);

    final title = '$display Ended';
    final text = 'Your $display has ended.';

    final variations = <String>[
      'Your $spoken has ended.',
      'Your $spoken has ended. Great work.',
      'Your $spoken is now complete.',
    ];

    final index = (variationIndex ?? 0) % variations.length;
    final speech = variations[index];

    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: speech,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 10:00 PM NEXT-DAY PLAN
  // ─────────────────────────────────────────────────────────────────────────

  /// Formats time in speech friendly format: "9 AM", "12 PM", "1:30 PM"
  static String formatSpeechTime(DateTime dt) {
    if (dt.minute == 0) {
      final hourFormat = DateFormat('h a');
      return hourFormat.format(dt);
    } else {
      final timeFormat = DateFormat('h:mm a');
      return timeFormat.format(dt);
    }
  }

  /// Generates the 10:00 PM next-day planning notification & speech.
  static NotificationMessagePair generateNextDayPlan({
    required List<ScheduleActivity> tomorrowActivities,
  }) {
    const title = "Tomorrow's Timora Plan";

    if (tomorrowActivities.isEmpty) {
      return const NotificationMessagePair(
        title: "Tomorrow's Timora Plan",
        notificationBody: 'No activities are planned for tomorrow.',
        spokenMessage: "You don't have any activities planned for tomorrow.",
      );
    }

    final count = tomorrowActivities.length;
    final timeFormat = DateFormat('h:mm a');

    // Case 1: Large schedule (> 8 activities) — keep speech concise
    if (count > 8) {
      final text =
          'Tomorrow you have $count activities planned. Open Timora to view the complete plan.';
      final speech =
          'Here is your plan for tomorrow. You have $count activities planned. Open Timora to view your complete plan.';
      return NotificationMessagePair(
        title: title,
        notificationBody: text,
        spokenMessage: speech,
      );
    }

    // Case 2: Moderate schedule (1 to 8 activities) — detailed text and natural speech
    final textBuffer = StringBuffer();
    textBuffer.writeln('You have $count activities scheduled.');
    textBuffer.writeln();

    for (int i = 0; i < count; i++) {
      final act = tomorrowActivities[i];
      final timeStr = timeFormat.format(act.startTime);
      textBuffer.writeln('$timeStr — ${act.title}');
    }

    // Natural speech synthesis
    final speechBuffer = StringBuffer();
    speechBuffer.write('Here is your plan for tomorrow. You have $count activities scheduled. ');

    final first = tomorrowActivities.first;
    speechBuffer.write(
        'Your first activity is ${first.title} at ${formatSpeechTime(first.startTime)}');

    if (count > 1) {
      speechBuffer.write(', followed by ');
      final following = <String>[];
      for (int i = 1; i < count; i++) {
        final act = tomorrowActivities[i];
        following.add('${act.title} at ${formatSpeechTime(act.startTime)}');
      }
      if (following.length == 1) {
        speechBuffer.write(following.first);
      } else {
        speechBuffer.write(following.sublist(0, following.length - 1).join(', '));
        speechBuffer.write(', and ${following.last}');
      }
    }
    speechBuffer.write('.');

    return NotificationMessagePair(
      title: title,
      notificationBody: textBuffer.toString().trim(),
      spokenMessage: speechBuffer.toString().trim(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEST NOTIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  static NotificationMessagePair generateTestNotification() {
    return const NotificationMessagePair(
      title: 'Timora Test Notification',
      notificationBody: 'Your voice notification system is active and ready.',
      spokenMessage:
          'This is a Timora test notification. Your voice notification system is working.',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTEXT-AWARE INTELLIGENT DISPATCH (Gemini-ready)
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates a natural spoken message using context parameters,
  /// with offline fallback and support for asynchronous AI generation if desired.
  static String generateContextualSpokenMessage({
    required String eventType,
    required Map<String, dynamic> context,
  }) {
    final name = (context['name'] ?? context['title'] ?? context['activityName'] ?? context['taskName'] ?? '').toString();
    final duration = context['durationMinutes'] as int?;
    final reportType = context['reportType'] as String?;
    final progress = context['progressPercentage'] as int?;
    final goalName = context['goalName'] as String?;

    switch (eventType) {
      case 'focusSession':
        return generateFocusSessionStart(durationMinutes: duration ?? 25, sessionTitle: name).spokenMessage;
      case 'taskMissed':
        return generateTaskMissed(taskName: name).spokenMessage;
      case 'reportReady':
        return generateReportReady(reportType: reportType ?? 'daily').spokenMessage;
      case 'goalProgress':
        if (progress != null && goalName != null && goalName.isNotEmpty) {
          return "Great job! You are now $progress percent towards your $goalName goal.";
        }
        return "Keep up the momentum on your goals today.";
      case 'taskStart':
        return generateTaskStart(taskName: name).spokenMessage;
      default:
        return generateStartMessage(activityName: name).spokenMessage;
    }
  }
}
