import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/notifications/domain/models/notification_event.dart';
import 'package:timora/features/notifications/application/notification_message_generator.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';

void main() {
  group('NotificationEvent Model & Serialization Tests', () {
    test('NotificationEvent creation and JSON round-trip', () {
      final now = DateTime(2026, 9, 3, 10, 0);
      final event = NotificationEvent.create(
        sourceType: NotificationSourceType.schedule,
        sourceId: 'act_123',
        eventType: NotificationEventType.activityStart,
        title: "It's time for Study",
        notificationBody: "It's time for Study.",
        spokenMessage: "It's time for your study session. Your activity starts now.",
        scheduledTime: now,
      );

      expect(event.sourceType, NotificationSourceType.schedule);
      expect(event.sourceId, 'act_123');
      expect(event.eventType, NotificationEventType.activityStart);
      expect(event.numericId, isPositive);
      expect(event.id, contains('timora_evt_schedule_act_123_activityStart_20260903'));

      final json = event.toJson();
      expect(json['id'], event.id);
      expect(json['numericId'], event.numericId);
      expect(json['eventType'], 'activityStart');
      expect(json['triggerAtMillis'], now.millisecondsSinceEpoch);

      final restored = NotificationEvent.fromJson(json);
      expect(restored.id, event.id);
      expect(restored.numericId, event.numericId);
      expect(restored.title, event.title);
      expect(restored.notificationBody, event.notificationBody);
      expect(restored.spokenMessage, event.spokenMessage);
      expect(restored.eventType, event.eventType);
      expect(restored.sourceType, event.sourceType);
    });

    test('Deterministic event IDs guarantee idempotent deduplication', () {
      final date = DateTime(2026, 9, 3, 14, 0);

      final id1 = NotificationEvent.buildEventId(
        sourceType: NotificationSourceType.schedule,
        sourceId: 'workout_1',
        eventType: NotificationEventType.pre10Minutes,
        date: date,
      );

      final id2 = NotificationEvent.buildEventId(
        sourceType: NotificationSourceType.schedule,
        sourceId: 'workout_1',
        eventType: NotificationEventType.pre10Minutes,
        date: date,
      );

      expect(id1, equals(id2));
      expect(NotificationEvent.generateNumericId(id1),
          equals(NotificationEvent.generateNumericId(id2)));
    });
  });

  group('NotificationMessageGenerator Tests', () {
    test('Activity name normalization produces natural nouns', () {
      expect(NotificationMessageGenerator.normalizeActivitySpokenName('Gym'),
          'workout');
      expect(NotificationMessageGenerator.normalizeActivitySpokenName('Study'),
          'study session');
      expect(NotificationMessageGenerator.normalizeActivitySpokenName('Deep Work'),
          'deep work session');
      expect(NotificationMessageGenerator.normalizeActivitySpokenName('Lunch'),
          'lunch');
      expect(NotificationMessageGenerator.normalizeActivitySpokenName('Research'),
          'research session');
      expect(NotificationMessageGenerator.normalizeActivitySpokenName('Rest'),
          'rest break');
    });

    test('Pre-reminders generate synchronized text and speech (10 min & 5 min)', () {
      final pre10 = NotificationMessageGenerator.generatePreReminder(
        activityName: 'Workout',
        minutesBefore: 10,
      );
      expect(pre10.title, 'Workout in 10 min');
      expect(pre10.notificationBody, 'Workout starts in 10 minutes. Get ready.');
      expect(pre10.spokenMessage, 'Your workout starts in 10 minutes. Get ready.');

      final pre5 = NotificationMessageGenerator.generatePreReminder(
        activityName: 'Deep Work',
        minutesBefore: 5,
      );
      expect(pre5.title, 'Deep Work in 5 min');
      expect(pre5.notificationBody, 'Deep Work starts in 5 minutes. Get ready.');
      expect(pre5.spokenMessage, 'Your deep work session starts in 5 minutes. Get ready.');
    });

    test('Activity start message generates natural announcement', () {
      final start = NotificationMessageGenerator.generateStartMessage(
        activityName: 'Study',
      );
      expect(start.title, "It's time for Study");
      expect(start.notificationBody, "It's time for Study.");
      expect(start.spokenMessage,
          "It's time for your study session. Your activity starts now.");
    });

    test('Activity end message generates natural announcement', () {
      final end = NotificationMessageGenerator.generateEndMessage(
        activityName: 'Study',
      );
      expect(end.title, 'Study Ended');
      expect(end.notificationBody, 'Your Study has ended.');
      expect(end.spokenMessage, 'Your study session has ended.');
    });

    test('Task start & reminder messages', () {
      final taskRemind = NotificationMessageGenerator.generateTaskReminder(
        taskName: 'Submit Report',
        minutesBefore: 10,
      );
      expect(taskRemind.title, 'Submit Report in 10 min');
      expect(taskRemind.spokenMessage,
          'Your Submit Report task starts in 10 minutes. Get ready.');

      final taskStart = NotificationMessageGenerator.generateTaskStart(
        taskName: 'Submit Report',
      );
      expect(taskStart.title, 'Task: Submit Report');
      expect(taskStart.spokenMessage, 'Your Submit Report task starts now.');
    });

    test('10 PM next-day plan message — empty schedule', () {
      final plan = NotificationMessageGenerator.generateNextDayPlan(
        tomorrowActivities: [],
      );
      expect(plan.notificationBody, 'No activities are planned for tomorrow.');
      expect(plan.spokenMessage, "You don't have any activities planned for tomorrow.");
    });

    test('10 PM next-day plan message — moderate schedule', () {
      final tomorrow = DateTime(2026, 9, 4);
      final activities = <ScheduleActivity>[
        ScheduleActivity(
          id: '1',
          title: 'Study',
          date: tomorrow,
          startTime: DateTime(2026, 9, 4, 9, 0),
          endTime: DateTime(2026, 9, 4, 11, 0),
          createdAt: DateTime.now(),
        ),
        ScheduleActivity(
          id: '2',
          title: 'Lunch',
          date: tomorrow,
          startTime: DateTime(2026, 9, 4, 12, 0),
          endTime: DateTime(2026, 9, 4, 13, 0),
          createdAt: DateTime.now(),
        ),
        ScheduleActivity(
          id: '3',
          title: 'Workout',
          date: tomorrow,
          startTime: DateTime(2026, 9, 4, 17, 0),
          endTime: DateTime(2026, 9, 4, 18, 0),
          createdAt: DateTime.now(),
        ),
      ];

      final plan = NotificationMessageGenerator.generateNextDayPlan(
        tomorrowActivities: activities,
      );

      expect(plan.title, "Tomorrow's Timora Plan");
      expect(plan.notificationBody, contains('9:00 AM — Study'));
      expect(plan.notificationBody, contains('12:00 PM — Lunch'));
      expect(plan.notificationBody, contains('5:00 PM — Workout'));
      expect(plan.spokenMessage, contains('Here is your plan for tomorrow. You have 3 activities scheduled.'));
      expect(plan.spokenMessage, contains('Your first activity is Study at 9 AM, followed by Lunch at 12 PM, and Workout at 5 PM.'));
    });

    test('10 PM next-day plan message — large schedule (> 8 activities)', () {
      final tomorrow = DateTime(2026, 9, 4);
      final activities = List<ScheduleActivity>.generate(
        10,
        (i) => ScheduleActivity(
          id: '$i',
          title: 'Activity $i',
          date: tomorrow,
          startTime: DateTime(2026, 9, 4, 8 + i, 0),
          endTime: DateTime(2026, 9, 4, 9 + i, 0),
          createdAt: DateTime.now(),
        ),
      );

      final plan = NotificationMessageGenerator.generateNextDayPlan(
        tomorrowActivities: activities,
      );

      expect(plan.notificationBody,
          'Tomorrow you have 10 activities planned. Open Timora to view the complete plan.');
      expect(plan.spokenMessage,
          'Here is your plan for tomorrow. You have 10 activities planned. Open Timora to view your complete plan.');
    });

    test('Test notification generates canonical phrase', () {
      final testMsg = NotificationMessageGenerator.generateTestNotification();
      expect(testMsg.title, 'Timora Test Notification');
      expect(testMsg.notificationBody,
          'Your voice notification system is active and ready.');
      expect(testMsg.spokenMessage,
          'This is a Timora test notification. Your voice notification system is working.');
    });
  });
}
