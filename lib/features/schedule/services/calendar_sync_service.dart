import 'package:intl/intl.dart';
import '../data/models/schedule_activity.dart';
import '../../tasks/data/models/task_model.dart';

class CalendarSyncService {
  /// Generates a standard RFC 5545 iCalendar (.ics) string for importing into
  /// Google Calendar, Apple Calendar, or Outlook.
  static String exportActivitiesToIcs({
    required List<ScheduleActivity> activities,
    List<TaskModel> tasks = const [],
    String calendarName = 'Timora Schedule',
  }) {
    final buffer = StringBuffer();
    final utcFormat = DateFormat("yyyyMMdd'T'HHmmss'Z'");

    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Timora Productivity//Timora App//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-CALNAME:$calendarName');

    // 1. Export Schedule Activities
    for (final act in activities) {
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${act.id}@timora.app');
      buffer.writeln('DTSTAMP:${utcFormat.format(DateTime.now().toUtc())}');
      buffer.writeln('DTSTART:${utcFormat.format(act.startTime.toUtc())}');
      buffer.writeln('DTEND:${utcFormat.format(act.endTime.toUtc())}');
      buffer.writeln('SUMMARY:${_escapeIcs(act.title)}');
      if (act.description.isNotEmpty) {
        buffer.writeln('DESCRIPTION:${_escapeIcs(act.description)}');
      }
      buffer.writeln('CATEGORIES:${_escapeIcs(act.category)}');
      buffer.writeln('STATUS:CONFIRMED');
      buffer.writeln('END:VEVENT');
    }

    // 2. Export Tasks with Due Dates as Calendar Events
    for (final task in tasks) {
      if (task.dueDate != null) {
        final start = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
          task.startTime?.hour ?? 9,
          task.startTime?.minute ?? 0,
        );
        final end = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
          task.endTime?.hour ?? (start.hour + 1),
          task.endTime?.minute ?? start.minute,
        );

        buffer.writeln('BEGIN:VEVENT');
        buffer.writeln('UID:${task.id}@timora.app');
        buffer.writeln('DTSTAMP:${utcFormat.format(DateTime.now().toUtc())}');
        buffer.writeln('DTSTART:${utcFormat.format(start.toUtc())}');
        buffer.writeln('DTEND:${utcFormat.format(end.toUtc())}');
        buffer.writeln('SUMMARY:${_escapeIcs(task.title)}');
        if (task.description.isNotEmpty) {
          buffer.writeln('DESCRIPTION:${_escapeIcs(task.description)}');
        }
        buffer.writeln('CATEGORIES:${_escapeIcs(task.category)}');
        buffer.writeln('PRIORITY:${_mapPriorityToIcs(task.priority)}');
        buffer.writeln('STATUS:${task.isCompleted ? 'COMPLETED' : 'CONFIRMED'}');
        buffer.writeln('END:VEVENT');
      }
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static String _escapeIcs(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  static int _mapPriorityToIcs(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return 1;
      case TaskPriority.high:
        return 3;
      case TaskPriority.medium:
        return 5;
      case TaskPriority.low:
        return 9;
      case TaskPriority.none:
        return 0;
    }
  }
}
