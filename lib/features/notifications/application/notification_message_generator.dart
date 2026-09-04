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
/// text notifications and natural spoken announcements.
class NotificationMessageGenerator {
  /// Clean text from Markdown artifacts, bullet glyphs, and multiple whitespaces.
  static String clean(String text) {
    return text
        .replaceAll(RegExp(r'[*#_`~]'), '')
        .replaceAll(RegExp(r'[•►▪■\-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Convert raw activity names into smooth, natural spoken nouns.
  /// Example: 'Workout' -> 'workout'
  ///          'Gym' -> 'workout'
  ///          'Study' -> 'study session'
  ///          'Deep Work' -> 'deep work session'
  ///          'Meeting' -> 'meeting'
  ///          'Lunch' -> 'lunch'
  ///          'Breakfast' -> 'breakfast'
  ///          'Dinner' -> 'dinner'
  ///          'Prayer' -> 'prayer'
  ///          'Meditation' -> 'meditation session'
  ///          'Research' -> 'research session'
  ///          'Rest' -> 'rest break'
  ///          'Sleep' -> 'sleep time'
  static String normalizeActivitySpokenName(String rawName) {
    final c = clean(rawName).toLowerCase();
    if (c.isEmpty) return 'activity';

    // Avoid duplicate "session session" or "time time"
    if (c.endsWith(' session') || c.endsWith(' time') || c.endsWith(' break')) {
      return c;
    }

    switch (c) {
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
        return c;
      default:
        return c;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRE-REMINDERS (10 min & 5 min)
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates a pre-reminder pair (10 minutes or 5 minutes before activity).
  static NotificationMessagePair generatePreReminder({
    required String activityName,
    required int minutesBefore,
  }) {
    final cleanName = clean(activityName);
    final display = cleanName.isEmpty ? 'Activity' : cleanName;
    final spoken = normalizeActivitySpokenName(display);

    final title = '$display in $minutesBefore min';
    final text = '$display starts in $minutesBefore minutes. Get ready.';
    final speech = 'Your $spoken starts in $minutesBefore minutes. Get ready.';

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
  }) {
    final cleanName = clean(activityName);
    final display = cleanName.isEmpty ? 'Activity' : cleanName;
    final spoken = normalizeActivitySpokenName(display);

    final title = "It's time for $display";
    final text = "It's time for $display.";
    final speech = "It's time for your $spoken. Your activity starts now.";

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
  }) {
    final cleanName = clean(taskName);
    final display = cleanName.isEmpty ? 'Task' : cleanName;

    final title = '$display in $minutesBefore min';
    final text = '$display is due in $minutesBefore minutes.';
    final speech = 'Your $display task starts in $minutesBefore minutes. Get ready.';

    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: speech,
    );
  }

  static NotificationMessagePair generateTaskStart({
    required String taskName,
  }) {
    final cleanName = clean(taskName);
    final display = cleanName.isEmpty ? 'Task' : cleanName;

    final title = 'Task: $display';
    final text = "It's time for $display.";
    final speech = 'Your $display task starts now.';

    return NotificationMessagePair(
      title: title,
      notificationBody: text,
      spokenMessage: speech,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVITY END
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates an activity end announcement pair for the final activity.
  static NotificationMessagePair generateEndMessage({
    required String activityName,
  }) {
    final cleanName = clean(activityName);
    final display = cleanName.isEmpty ? 'Activity' : cleanName;
    final spoken = normalizeActivitySpokenName(display);

    final title = '$display Ended';
    final text = 'Your $display has ended.';
    final speech = 'Your $spoken has ended.';

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
    final title = "Tomorrow's Timora Plan";

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
}
