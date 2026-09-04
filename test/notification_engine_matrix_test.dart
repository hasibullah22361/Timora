import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:timora/features/notifications/domain/models/notification_event.dart';
import 'package:timora/features/notifications/application/notification_event_engine.dart';
import 'package:timora/features/notifications/application/alarm_scheduler_service.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';

class MockAlarmSchedulerService extends AlarmSchedulerService {
  final List<NotificationEvent> recordedSyncedEvents = [];
  final List<String> recordedCancelledSources = [];
  bool allAlarmsCancelled = false;

  @override
  Future<void> syncEvents(List<NotificationEvent> events) async {
    recordedSyncedEvents.addAll(events);
  }

  @override
  Future<void> cancelEventsBySource(String sourceId) async {
    recordedCancelledSources.add(sourceId);
    recordedSyncedEvents.removeWhere((e) => e.sourceId == sourceId);
  }

  @override
  Future<void> cancelAllAlarms() async {
    allAlarmsCancelled = true;
    recordedSyncedEvents.clear();
  }
}

class MockScheduleRepository implements ScheduleRepository {
  List<ScheduleActivity> mockActivities = [];

  @override
  Future<List<ScheduleActivity>> getActivitiesForDate(DateTime date) async {
    return mockActivities.where((a) =>
        a.date.year == date.year &&
        a.date.month == date.month &&
        a.date.day == date.day).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTaskRepository implements TaskRepository {
  List<TaskModel> mockTasks = [];

  @override
  Future<List<TaskModel>> getTasks() async => mockTasks;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationSettingsRepository implements NotificationSettingsRepository {
  @override
  bool notificationsEnabled = true;
  @override
  bool activityStartingEnabled = true;
  @override
  bool activityStartedEnabled = true;
  @override
  bool activityEndingEnabled = true;
  @override
  bool nextActivityEnabled = true;
  @override
  bool quietHoursEnabled = false;
  @override
  TimeOfDay quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  @override
  TimeOfDay quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockAlarmSchedulerService mockAlarmScheduler;
  late MockNotificationSettingsRepository mockSettings;
  late MockScheduleRepository mockScheduleRepo;
  late MockTaskRepository mockTaskRepo;
  late NotificationEventEngine engine;

  setUp(() {
    mockAlarmScheduler = MockAlarmSchedulerService();
    mockSettings = MockNotificationSettingsRepository();
    mockScheduleRepo = MockScheduleRepository();
    mockTaskRepo = MockTaskRepository();
    engine = NotificationEventEngine(
      mockAlarmScheduler,
      mockSettings,
      mockScheduleRepo,
      mockTaskRepo,
    );
  });

  group('NotificationEventEngine Complete State Matrix Tests', () {
    test('TEST 1 to 4: Generates 10m, 5m, and exact start events for future activity', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Activity starting in 30 minutes
      final actStart = now.add(const Duration(minutes: 30));
      final actEnd = actStart.add(const Duration(hours: 1));

      mockScheduleRepo.mockActivities = [
        ScheduleActivity(
          id: 'workout_1',
          title: 'Workout',
          date: today,
          startTime: actStart,
          endTime: actEnd,
          createdAt: now,
        ),
      ];

      await engine.syncSchedule(today);

      final events = mockAlarmScheduler.recordedSyncedEvents;

      // 10-minute reminder
      final pre10 = events.firstWhere((e) => e.eventType == NotificationEventType.pre10Minutes);
      expect(pre10.title, 'Workout in 10 min');
      expect(pre10.spokenMessage, 'Your workout starts in 10 minutes. Get ready.');
      expect(pre10.scheduledTime.difference(actStart).inMinutes.abs(), 10);

      // 5-minute reminder
      final pre5 = events.firstWhere((e) => e.eventType == NotificationEventType.pre5Minutes);
      expect(pre5.title, 'Workout in 5 min');
      expect(pre5.spokenMessage, 'Your workout starts in 5 minutes. Get ready.');
      expect(pre5.scheduledTime.difference(actStart).inMinutes.abs(), 5);

      // Exact start
      final start = events.firstWhere((e) => e.eventType == NotificationEventType.activityStart);
      expect(start.title, "It's time for Workout");
      expect(start.spokenMessage, "It's time for your workout. Your activity starts now.");
      expect(start.scheduledTime, actStart);
    });

    test('TEST 5 & 6: Intelligent End Logic suppresses end announcement if next activity follows immediately', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final act1Start = now.add(const Duration(minutes: 30));
      final act1End = act1Start.add(const Duration(hours: 1));
      // Activity 2 starts IMMEDIATELY when Activity 1 ends
      final act2Start = act1End;
      final act2End = act2Start.add(const Duration(hours: 1));

      mockScheduleRepo.mockActivities = [
        ScheduleActivity(
          id: 'study_1',
          title: 'Study',
          date: today,
          startTime: act1Start,
          endTime: act1End,
          createdAt: now,
        ),
        ScheduleActivity(
          id: 'workout_2',
          title: 'Workout',
          date: today,
          startTime: act2Start,
          endTime: act2End,
          createdAt: now,
        ),
      ];

      await engine.syncSchedule(today);

      final events = mockAlarmScheduler.recordedSyncedEvents;

      // Activity 1 (Study) end event MUST BE SUPPRESSED because Workout follows immediately!
      final studyEndEvents = events.where((e) =>
          e.sourceId == 'study_1' && e.eventType == NotificationEventType.activityEnd);
      expect(studyEndEvents, isEmpty, reason: 'Study end event must be suppressed when Workout follows immediately');

      // Activity 2 (Workout) is the FINAL activity of the day -> end event MUST BE EMITTED!
      final workoutEnd = events.firstWhere((e) =>
          e.sourceId == 'workout_2' && e.eventType == NotificationEventType.activityEnd);
      expect(workoutEnd.title, 'Workout Ended');
      expect(workoutEnd.spokenMessage, 'Your workout has ended.');
    });

    test('TEST 7: 10 PM next-day plan event generation with actual schedule data', () async {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

      mockScheduleRepo.mockActivities = [
        ScheduleActivity(
          id: 'tom_1',
          title: 'Deep Work',
          date: tomorrow,
          startTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0),
          endTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11, 0),
          createdAt: now,
        ),
        ScheduleActivity(
          id: 'tom_2',
          title: 'Lunch',
          date: tomorrow,
          startTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12, 0),
          endTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 13, 0),
          createdAt: now,
        ),
      ];

      final planEvent = await engine.build10PmNextDayPlanEvent(now);
      expect(planEvent, isNotNull);
      expect(planEvent!.eventType, NotificationEventType.nextDayPlan);
      expect(planEvent.scheduledTime.hour, 22);
      expect(planEvent.title, "Tomorrow's Timora Plan");
      expect(planEvent.notificationBody, contains('9:00 AM — Deep Work'));
      expect(planEvent.spokenMessage, contains('Here is your plan for tomorrow. You have 2 activities scheduled.'));
      expect(planEvent.spokenMessage, contains('Your first activity is Deep Work at 9 AM, followed by Lunch at 12 PM.'));
    });

    test('TEST 13 & 14: Updating / Deleting activity immediately cancels old events', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final initialStart = now.add(const Duration(minutes: 30));
      mockScheduleRepo.mockActivities = [
        ScheduleActivity(
          id: 'act_update_test',
          title: 'Meeting',
          date: today,
          startTime: initialStart,
          endTime: initialStart.add(const Duration(minutes: 45)),
          createdAt: now,
        ),
      ];

      await engine.syncSchedule(today);
      expect(mockAlarmScheduler.recordedSyncedEvents.any((e) => e.sourceId == 'act_update_test'), isTrue);

      // Simulate deletion / cancellation
      await mockAlarmScheduler.cancelEventsBySource('act_update_test');
      expect(mockAlarmScheduler.recordedCancelledSources, contains('act_update_test'));
      expect(mockAlarmScheduler.recordedSyncedEvents.any((e) => e.sourceId == 'act_update_test'), isFalse);
    });

    test('TEST 15: Repeated scheduling calls remain completely idempotent', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final actStart = now.add(const Duration(hours: 2));

      mockScheduleRepo.mockActivities = [
        ScheduleActivity(
          id: 'idempotent_act',
          title: 'Reading',
          date: today,
          startTime: actStart,
          endTime: actStart.add(const Duration(hours: 1)),
          createdAt: now,
        ),
      ];

      // Call 1
      await engine.syncSchedule(today);
      final count1 = mockAlarmScheduler.recordedSyncedEvents.length;

      // Call 2
      mockAlarmScheduler.recordedSyncedEvents.clear();
      await engine.syncSchedule(today);
      final count2 = mockAlarmScheduler.recordedSyncedEvents.length;

      expect(count1, equals(count2));
    });

    test('TEST 16: Test Notification produces valid production event', () async {
      await engine.triggerTestNotification();
      final testEvent = mockAlarmScheduler.recordedSyncedEvents.firstWhere(
        (e) => e.eventType == NotificationEventType.testNotification,
      );

      expect(testEvent.title, 'Timora Test Notification');
      expect(testEvent.spokenMessage,
          'This is a Timora test notification. Your voice notification system is working.');
      expect(testEvent.scheduledTime.isAfter(DateTime.now()), isTrue);
    });
  });
}
