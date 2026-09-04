import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../tasks/data/models/task_model.dart';

class ParsedQuickAddResult {
  final String rawInput;
  final String title;
  final DateTime? date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final TimeOfDay? dueTime;
  final int estimatedDurationMinutes;
  final TaskPriority priority;
  final String category;
  final String recurrence;
  final List<int> daysOfWeek;

  ParsedQuickAddResult({
    required this.rawInput,
    required this.title,
    this.date,
    this.startTime,
    this.endTime,
    this.dueTime,
    this.estimatedDurationMinutes = 30,
    this.priority = TaskPriority.medium,
    this.category = 'Other',
    this.recurrence = 'none',
    this.daysOfWeek = const [],
  });

  bool get hasTime => startTime != null || dueTime != null;
  bool get isRecurring => recurrence != 'none' && recurrence.isNotEmpty;

  TaskModel toTaskModel() {
    return TaskModel(
      id: const Uuid().v4(),
      title: title.isNotEmpty ? title : 'New Task',
      priority: priority,
      category: category,
      dueDate: date,
      dueTime: dueTime,
      startTime: startTime,
      endTime: endTime,
      estimatedDurationMinutes: estimatedDurationMinutes,
      recurrence: recurrence,
      createdAt: DateTime.now(),
    );
  }
}

class QuickAddParser {
  static ParsedQuickAddResult parse(String input) {
    if (input.trim().isEmpty) {
      return ParsedQuickAddResult(
        rawInput: input,
        title: '',
      );
    }

    String working = input.trim();
    TaskPriority priority = TaskPriority.medium;
    String category = 'Other';
    String recurrence = 'none';
    List<int> daysOfWeek = [];
    DateTime? date;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    TimeOfDay? dueTime;
    int estimatedDurationMinutes = 30;

    final lower = working.toLowerCase();

    // 1. Extract Priority
    if (lower.contains('urgent') || lower.contains('asap') || lower.contains('critical') || lower.contains('emergency')) {
      priority = TaskPriority.urgent;
      working = working.replaceAll(RegExp(r'\b(urgent|asap|critical|emergency):?\b', caseSensitive: false), '').trim();
    } else if (lower.contains('high priority') || lower.contains('important') || lower.contains('high')) {
      priority = TaskPriority.high;
      working = working.replaceAll(RegExp(r'\b(high priority|important)\b', caseSensitive: false), '').trim();
    } else if (lower.contains('low priority') || lower.contains('someday') || lower.contains('trivial')) {
      priority = TaskPriority.low;
      working = working.replaceAll(RegExp(r'\b(low priority|someday|trivial)\b', caseSensitive: false), '').trim();
    }

    // 2. Extract Recurrence & Days
    if (lower.contains('daily') || lower.contains('every day')) {
      recurrence = 'daily';
      daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
      working = working.replaceAll(RegExp(r'\b(daily|every day)\b', caseSensitive: false), '').trim();
    } else if (lower.contains('weekdays') || lower.contains('every weekday')) {
      recurrence = 'weekly';
      daysOfWeek = [1, 2, 3, 4, 5];
      working = working.replaceAll(RegExp(r'\b(every weekday|weekdays)\b', caseSensitive: false), '').trim();
    } else if (lower.contains('every weekend') || lower.contains('weekends')) {
      recurrence = 'weekly';
      daysOfWeek = [6, 7];
      working = working.replaceAll(RegExp(r'\b(every weekend|weekends)\b', caseSensitive: false), '').trim();
    } else if (RegExp(r'\bevery\s+([a-zA-Z\s,]+?)(?=\s+(?:at|from|by|for|tonight|this|in)|\s*$)', caseSensitive: false).hasMatch(working)) {
      final match = RegExp(r'\bevery\s+([a-zA-Z\s,]+?)(?=\s+(?:at|from|by|for|tonight|this|in)|\s*$)', caseSensitive: false).firstMatch(working);
      if (match != null) {
        final daysPart = match.group(1)?.toLowerCase() ?? '';
        final parsedDays = <int>[];
        if (daysPart.contains('mon')) parsedDays.add(1);
        if (daysPart.contains('tue')) parsedDays.add(2);
        if (daysPart.contains('wed')) parsedDays.add(3);
        if (daysPart.contains('thu')) parsedDays.add(4);
        if (daysPart.contains('fri')) parsedDays.add(5);
        if (daysPart.contains('sat')) parsedDays.add(6);
        if (daysPart.contains('sun')) parsedDays.add(7);

        if (parsedDays.isNotEmpty) {
          recurrence = 'weekly';
          daysOfWeek = parsedDays;
          working = working.replaceFirst(match.group(0)!, '').trim();
        }
      }
    }

    // 3. Extract Duration (e.g. "for 2 hours", "for 45 mins", "for 90 minutes", "1.5 hours")
    final durationMatch = RegExp(
      r'\b(?:for\s+)?(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)\b',
      caseSensitive: false,
    ).firstMatch(working);

    if (durationMatch != null) {
      final numVal = double.tryParse(durationMatch.group(1) ?? '') ?? 0.5;
      final unit = durationMatch.group(2)?.toLowerCase() ?? 'min';
      if (unit.startsWith('h')) {
        estimatedDurationMinutes = (numVal * 60).round();
      } else {
        estimatedDurationMinutes = numVal.round();
      }
      working = working.replaceFirst(durationMatch.group(0)!, '').trim();
    }

    // 4. Extract Time Ranges (e.g., "from 9 AM to 11 AM", "9:00 - 11:30", "from 14:00 to 16:00")
    final rangeMatch = RegExp(
      r'\b(?:from\s+)?(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\s*(?:to|-)\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm))\b',
      caseSensitive: false,
    ).firstMatch(working);

    if (rangeMatch != null) {
      final startStr = rangeMatch.group(1) ?? '';
      final endStr = rangeMatch.group(2) ?? '';
      startTime = _parseTimeString(startStr);
      endTime = _parseTimeString(endStr);
      dueTime = endTime ?? startTime;
      if (startTime != null && endTime != null) {
        final startMins = startTime.hour * 60 + startTime.minute;
        final endMins = endTime.hour * 60 + endTime.minute;
        if (endMins > startMins) {
          estimatedDurationMinutes = endMins - startMins;
        }
      }
      working = working.replaceFirst(rangeMatch.group(0)!, '').trim();
    } else {
      // 5. Extract Single Point in Time (e.g., "at 8 PM", "by 5:30 PM", "at 9:00", "tonight", "this morning")
      final singleTimeMatch = RegExp(
        r'\b(?:at|by)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\b',
        caseSensitive: false,
      ).firstMatch(working);

      if (singleTimeMatch != null) {
        final timeStr = singleTimeMatch.group(1) ?? '';
        startTime = _parseTimeString(timeStr);
        dueTime = startTime;
        if (startTime != null) {
          endTime = TimeOfDay(
            hour: (startTime.hour + (estimatedDurationMinutes ~/ 60)) % 24,
            minute: (startTime.minute + (estimatedDurationMinutes % 60)) % 60,
          );
        }
        working = working.replaceFirst(singleTimeMatch.group(0)!, '').trim();
      } else if (lower.contains('tonight')) {
        startTime = const TimeOfDay(hour: 20, minute: 0);
        dueTime = startTime;
        working = working.replaceAll(RegExp(r'\btonight\b', caseSensitive: false), '').trim();
      } else if (lower.contains('this morning')) {
        startTime = const TimeOfDay(hour: 9, minute: 0);
        dueTime = startTime;
        working = working.replaceAll(RegExp(r'\bthis morning\b', caseSensitive: false), '').trim();
      } else if (lower.contains('this afternoon')) {
        startTime = const TimeOfDay(hour: 14, minute: 0);
        dueTime = startTime;
        working = working.replaceAll(RegExp(r'\bthis afternoon\b', caseSensitive: false), '').trim();
      }
    }

    // 6. Extract Dates (e.g., "today", "tomorrow", "next monday", "on Friday", "Sep 15", "September 20")
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (RegExp(r'\btomorrow\b', caseSensitive: false).hasMatch(working)) {
      date = today.add(const Duration(days: 1));
      working = working.replaceAll(RegExp(r'\btomorrow\b', caseSensitive: false), '').trim();
    } else if (RegExp(r'\btoday\b', caseSensitive: false).hasMatch(working)) {
      date = today;
      working = working.replaceAll(RegExp(r'\btoday\b', caseSensitive: false), '').trim();
    } else if (RegExp(r'\b(?:on\s+)?(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false).hasMatch(working)) {
      final match = RegExp(r'\b(?:on\s+)?(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false).firstMatch(working);
      if (match != null) {
        final dayName = match.group(2)?.toLowerCase() ?? '';
        final targetWeekday = _weekdayFromName(dayName);
        int daysUntil = (targetWeekday - today.weekday) % 7;
        if (daysUntil <= 0 || match.group(1) != null) daysUntil += 7;
        date = today.add(Duration(days: daysUntil));
        working = working.replaceFirst(match.group(0)!, '').trim();
      }
    }

    // If recurring and no specific date set, default to today
    if (recurrence != 'none' && date == null) {
      date = today;
    }

    // 7. Clean up title & redundant prepositions
    String title = working
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^(on|at|from|by|to|for|in)\s+', caseSensitive: false), '')
        .trim();

    if (title.isEmpty) {
      title = input.trim();
    }

    // 8. Infer Category
    final titleLower = title.toLowerCase();
    if (titleLower.contains('study') ||
        titleLower.contains('read') ||
        titleLower.contains('book') ||
        titleLower.contains('course') ||
        titleLower.contains('exam') ||
        titleLower.contains('learn')) {
      category = 'Study';
    } else if (titleLower.contains('gym') ||
        titleLower.contains('workout') ||
        titleLower.contains('run') ||
        titleLower.contains('walk') ||
        titleLower.contains('exercise') ||
        titleLower.contains('yoga') ||
        titleLower.contains('fitness')) {
      category = 'Fitness';
    } else if (titleLower.contains('work') ||
        titleLower.contains('project') ||
        titleLower.contains('client') ||
        titleLower.contains('meeting') ||
        titleLower.contains('email') ||
        titleLower.contains('code') ||
        titleLower.contains('pr') ||
        titleLower.contains('report') ||
        titleLower.contains('presentation') ||
        titleLower.contains('research')) {
      category = 'Work';
    } else if (titleLower.contains('meditate') ||
        titleLower.contains('sleep') ||
        titleLower.contains('hydrate') ||
        titleLower.contains('health')) {
      category = 'Health';
    }

    return ParsedQuickAddResult(
      rawInput: input,
      title: title,
      date: date,
      startTime: startTime,
      endTime: endTime,
      dueTime: dueTime,
      estimatedDurationMinutes: estimatedDurationMinutes,
      priority: priority,
      category: category,
      recurrence: recurrence,
      daysOfWeek: daysOfWeek,
    );
  }

  static TimeOfDay? _parseTimeString(String str) {
    str = str.trim().toLowerCase();
    bool isPm = str.contains('pm');
    bool isAm = str.contains('am');
    str = str.replaceAll('am', '').replaceAll('pm', '').trim();

    int hour = 0;
    int minute = 0;

    if (str.contains(':')) {
      final parts = str.split(':');
      hour = int.tryParse(parts[0]) ?? 0;
      minute = int.tryParse(parts[1]) ?? 0;
    } else {
      hour = int.tryParse(str) ?? 0;
    }

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  static int _weekdayFromName(String name) {
    switch (name) {
      case 'monday': return 1;
      case 'tuesday': return 2;
      case 'wednesday': return 3;
      case 'thursday': return 4;
      case 'friday': return 5;
      case 'saturday': return 6;
      case 'sunday': return 7;
      default: return 1;
    }
  }
}
