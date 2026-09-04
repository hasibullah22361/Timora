import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/services/calendar_sync_service.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';

void main() {
  group('Phase 10 — Calendar & Schedule Integration Tests', () {
    test('ICS-1: CalendarSyncService generates valid RFC 5545 iCalendar stream', () {
      final now = DateTime(2026, 8, 28, 9, 0);
      final activity = ScheduleActivity(
        id: 'act_101',
        title: 'Deep Architecture Sprint',
        date: DateTime(2026, 8, 28),
        startTime: now,
        endTime: now.add(const Duration(hours: 2)),
        category: 'Deep Work',
        description: 'Focus on Timora upgrade',
        createdAt: now,
      );

      final ics = CalendarSyncService.exportActivitiesToIcs(
        activities: [activity],
        calendarName: 'Timora Calendar',
      );

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('X-WR-CALNAME:Timora Calendar'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('UID:act_101@timora.app'));
      expect(ics, contains('SUMMARY:Deep Architecture Sprint'));
      expect(ics, contains('DESCRIPTION:Focus on Timora upgrade'));
      expect(ics, contains('CATEGORIES:Deep Work'));
      expect(ics, contains('END:VEVENT'));
      expect(ics, contains('END:VCALENDAR'));
    });

    test('ICS-2: CalendarSyncService exports timed tasks as calendar events', () {
      final dueDate = DateTime(2026, 8, 28);
      final task = TaskModel(
        id: 'task_202',
        title: 'Review System Metrics',
        description: 'Check daily scores',
        priority: TaskPriority.urgent,
        category: 'Analytics',
        dueDate: dueDate,
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
        createdAt: DateTime.now(),
      );

      final ics = CalendarSyncService.exportActivitiesToIcs(
        activities: [],
        tasks: [task],
      );

      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('UID:task_202@timora.app'));
      expect(ics, contains('SUMMARY:Review System Metrics'));
      expect(ics, contains('PRIORITY:1')); // Urgent -> 1
      expect(ics, contains('DESCRIPTION:Check daily scores'));
      expect(ics, contains('END:VEVENT'));
    });
  });
}
