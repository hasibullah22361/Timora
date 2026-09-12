import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/notification_event.dart';
import 'notification_message_generator.dart';
import 'alarm_scheduler_service.dart';
import '../../settings/data/repositories/notification_settings_repository.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/data/repositories/schedule_repository.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';

import 'engine/notification_engine.dart';
import 'engine/platform_notification_factory.dart';

final notificationEventEngineProvider =
    Provider<NotificationEventEngine>((ref) {
  return NotificationEventEngine(
    ref.watch(notificationEngineProvider),
    ref.watch(notificationSettingsRepositoryProvider),
    ref.watch(scheduleRepositoryProvider),
    ref.watch(taskRepositoryProvider),
  );
});

/// NotificationEventEngine — The single source of truth for scheduling, updating,
/// and cancelling all Timora notifications and spoken announcements.
class NotificationEventEngine {
  final NotificationEngine? _engine;
  final AlarmSchedulerService? _alarmScheduler;
  final NotificationSettingsRepository _settings;
  final ScheduleRepository _scheduleRepo;
  final TaskRepository _taskRepo;

  NotificationEventEngine(
    dynamic schedulerOrEngine,
    this._settings,
    this._scheduleRepo,
    this._taskRepo,
  )   : _engine = schedulerOrEngine is NotificationEngine ? schedulerOrEngine : null,
        _alarmScheduler = schedulerOrEngine is AlarmSchedulerService ? schedulerOrEngine : null;

  Future<void> _syncEvents(List<NotificationEvent> events) async {
    if (_engine != null) {
      await _engine?.syncEvents(events);
    } else if (_alarmScheduler != null) {
      await _alarmScheduler?.syncEvents(events);
    }
  }

  Future<void> _cancelEventsBySource(String sourceId) async {
    if (_engine != null) {
      await _engine?.cancelEventsBySource(sourceId);
    } else if (_alarmScheduler != null) {
      await _alarmScheduler?.cancelEventsBySource(sourceId);
    }
  }

  Future<void> _cancelAll() async {
    if (_engine != null) {
      await _engine?.cancelAll();
    } else if (_alarmScheduler != null) {
      await _alarmScheduler?.cancelAllAlarms();
    }
  }

  bool _isQuietHours(DateTime time) {
    if (!_settings.quietHoursEnabled) return false;

    final start = _settings.quietHoursStart;
    final end = _settings.quietHoursEnd;

    final timeMins = time.hour * 60 + time.minute;
    final startMins = start.hour * 60 + start.minute;
    final endMins = end.hour * 60 + end.minute;

    if (startMins <= endMins) {
      return timeMins >= startMins && timeMins < endMins;
    } else {
      // Wraps around midnight
      return timeMins >= startMins || timeMins < endMins;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FULL SCHEDULE SYNCHRONIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Synchronize all notifications for the given date (today) and schedule
  /// tomorrow's 10:00 PM plan.
  Future<void> syncSchedule(DateTime date) async {
    if (!_settings.notificationsEnabled) {
      debugPrint('[NotificationEngine] Notifications disabled globally — cancelling all');
      await _cancelAll();
      return;
    }

    final activities = await _scheduleRepo.getActivitiesForDate(date);
    final now = DateTime.now();
    final eventsToSchedule = <NotificationEvent>[];

    // Sort activities by start time
    final sorted = List<ScheduleActivity>.from(activities)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (int i = 0; i < sorted.length; i++) {
      final act = sorted[i];

      // Skip completed or skipped activities
      if (act.status == ActivityStatus.skipped ||
          act.status == ActivityStatus.completed) {
        // Ensure old alarms for this activity are cancelled
        await _cancelEventsBySource(act.id);
        continue;
      }

      // ── 1. PRE-10-MINUTES REMINDER ──
      if (_settings.activityStartingEnabled) {
        final pre10Time = act.startTime.subtract(const Duration(minutes: 10));
        if (pre10Time.isAfter(now) && !_isQuietHours(pre10Time)) {
          final pair = NotificationMessageGenerator.generatePreReminder(
            activityName: act.title,
            minutesBefore: 10,
          );
          eventsToSchedule.add(NotificationEvent.create(
            sourceType: NotificationSourceType.schedule,
            sourceId: act.id,
            eventType: NotificationEventType.pre10Minutes,
            title: pair.title,
            notificationBody: pair.notificationBody,
            spokenMessage: pair.spokenMessage,
            scheduledTime: pre10Time,
          ));
        }

        // ── 2. PRE-5-MINUTES REMINDER ──
        final pre5Time = act.startTime.subtract(const Duration(minutes: 5));
        if (pre5Time.isAfter(now) && !_isQuietHours(pre5Time)) {
          final pair = NotificationMessageGenerator.generatePreReminder(
            activityName: act.title,
            minutesBefore: 5,
          );
          eventsToSchedule.add(NotificationEvent.create(
            sourceType: NotificationSourceType.schedule,
            sourceId: act.id,
            eventType: NotificationEventType.pre5Minutes,
            title: pair.title,
            notificationBody: pair.notificationBody,
            spokenMessage: pair.spokenMessage,
            scheduledTime: pre5Time,
          ));
        }
      }

      // ── 3. ACTIVITY START (exact start time) ──
      if (_settings.activityStartedEnabled) {
        if (act.startTime.isAfter(now) && !_isQuietHours(act.startTime)) {
          final pair = NotificationMessageGenerator.generateStartMessage(
            activityName: act.title,
          );
          eventsToSchedule.add(NotificationEvent.create(
            sourceType: NotificationSourceType.schedule,
            sourceId: act.id,
            eventType: NotificationEventType.activityStart,
            title: pair.title,
            notificationBody: pair.notificationBody,
            spokenMessage: pair.spokenMessage,
            scheduledTime: act.startTime,
          ));
        }
      }

      // ── 4. INTELLIGENT ACTIVITY END ──
      // Check whether another activity follows immediately (within 2 minutes)
      final hasImmediateNext = (i + 1 < sorted.length) &&
          sorted[i + 1].startTime.difference(act.endTime).inMinutes.abs() <= 2;

      if (!hasImmediateNext && _settings.activityEndingEnabled) {
        // Only announce activity end if NO activity immediately follows
        if (act.endTime.isAfter(now) && !_isQuietHours(act.endTime)) {
          final pair = NotificationMessageGenerator.generateEndMessage(
            activityName: act.title,
          );
          eventsToSchedule.add(NotificationEvent.create(
            sourceType: NotificationSourceType.schedule,
            sourceId: act.id,
            eventType: NotificationEventType.activityEnd,
            title: pair.title,
            notificationBody: pair.notificationBody,
            spokenMessage: pair.spokenMessage,
            scheduledTime: act.endTime,
          ));
        }
      }
    }

    // ── 5. 10:00 PM NEXT-DAY PLAN NOTIFICATION ──
    final nextDayPlanEvent = await build10PmNextDayPlanEvent(now);
    if (nextDayPlanEvent != null) {
      eventsToSchedule.add(nextDayPlanEvent);
    }

    // ── 6. MORNING BRIEF NOTIFICATION ──
    final morningBriefEvent = buildMorningBriefEvent(now);
    if (morningBriefEvent != null) {
      eventsToSchedule.add(morningBriefEvent);
    }

    // ── 7. DAILY DEBRIEF NOTIFICATION ──
    final dailyDebriefEvent = buildDailyDebriefEvent(now);
    if (dailyDebriefEvent != null) {
      eventsToSchedule.add(dailyDebriefEvent);
    }

    debugPrint(
        '[NotificationEngine] Syncing ${eventsToSchedule.length} schedule events for $date');
    await _syncEvents(eventsToSchedule);
  }

  /// Builds the 10:00 PM next-day planning notification event for tonight.
  Future<NotificationEvent?> build10PmNextDayPlanEvent(DateTime now) async {
    final tonight10Pm = DateTime(now.year, now.month, now.day, 22, 0);

    // If 10:00 PM today has already passed, schedule for tomorrow night
    final triggerTime = tonight10Pm.isAfter(now)
        ? tonight10Pm
        : tonight10Pm.add(const Duration(days: 1));

    if (_isQuietHours(triggerTime)) return null;

    final tomorrow = DateTime(triggerTime.year, triggerTime.month, triggerTime.day)
        .add(const Duration(days: 1));
    final tomorrowActivities = await _scheduleRepo.getActivitiesForDate(tomorrow);

    final pair = NotificationMessageGenerator.generateNextDayPlan(
      tomorrowActivities: tomorrowActivities,
    );

    return NotificationEvent.create(
      sourceType: NotificationSourceType.other,
      sourceId: 'next_day_plan',
      eventType: NotificationEventType.nextDayPlan,
      title: pair.title,
      notificationBody: pair.notificationBody,
      spokenMessage: pair.spokenMessage,
      scheduledTime: triggerTime,
    );
  }

  /// Builds the morning briefing notification event.
  NotificationEvent? buildMorningBriefEvent(DateTime now) {
    if (!_settings.morningBriefEnabled) return null;

    final briefTime = _settings.morningBriefTime;
    final scheduled = DateTime(now.year, now.month, now.day, briefTime.hour, briefTime.minute);
    final triggerTime = scheduled.isAfter(now) ? scheduled : scheduled.add(const Duration(days: 1));

    if (_isQuietHours(triggerTime)) return null;

    return NotificationEvent.create(
      sourceType: NotificationSourceType.other,
      sourceId: 'morning_brief',
      eventType: NotificationEventType.morningBrief,
      title: '🌅 Good Morning — Your Daily Briefing',
      notificationBody: 'Tap to view your priorities and daily plan.',
      spokenMessage: _settings.morningBriefAutoPlay ? 'Good morning. Your daily brief is ready.' : '',
      scheduledTime: triggerTime,
      metadata: {'payload': 'morning_brief'},
    );
  }

  /// Builds the 🌙 Daily Debrief notification event.
  NotificationEvent? buildDailyDebriefEvent(DateTime now) {
    if (!_settings.dailyDebriefEnabled) return null;

    final debriefTime = _settings.dailyDebriefTime;
    final scheduled = DateTime(now.year, now.month, now.day, debriefTime.hour, debriefTime.minute);
    final triggerTime = scheduled.isAfter(now) ? scheduled : scheduled.add(const Duration(days: 1));

    if (_isQuietHours(triggerTime)) return null;

    return NotificationEvent.create(
      sourceType: NotificationSourceType.other,
      sourceId: 'daily_debrief',
      eventType: NotificationEventType.dailyDebrief,
      title: '🌙 Time for your Daily Debrief',
      notificationBody: 'Take 1 minute to reflect: What went well today?',
      spokenMessage: '',
      scheduledTime: triggerTime,
      metadata: {'payload': 'daily_debrief'},
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SINGLE TASK SYNCHRONIZATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> syncTask(TaskModel task) async {
    // Always cancel old events for this task first
    await _cancelEventsBySource(task.id);

    if (task.isDeleted ||
        task.status != TaskStatus.pending ||
        task.dueDate == null ||
        task.dueTime == null) {
      return;
    }

    final now = DateTime.now();
    final taskStartTime = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
      task.dueTime!.hour,
      task.dueTime!.minute,
    );

    final events = <NotificationEvent>[];

    // Task Start Event
    if (taskStartTime.isAfter(now) && !_isQuietHours(taskStartTime)) {
      final pair = NotificationMessageGenerator.generateTaskStart(
        taskName: task.title,
      );
      events.add(NotificationEvent.create(
        sourceType: NotificationSourceType.task,
        sourceId: task.id,
        eventType: NotificationEventType.activityStart,
        title: pair.title,
        notificationBody: pair.notificationBody,
        spokenMessage: pair.spokenMessage,
        scheduledTime: taskStartTime,
      ));
    }

    // Optional Advance Reminder (10 min or custom reminderMinutesBefore)
    if (task.reminderEnabled && task.reminderMinutesBefore > 0) {
      final reminderTime =
          taskStartTime.subtract(Duration(minutes: task.reminderMinutesBefore));
      if (reminderTime.isAfter(now) && !_isQuietHours(reminderTime)) {
        final pair = NotificationMessageGenerator.generateTaskReminder(
          taskName: task.title,
          minutesBefore: task.reminderMinutesBefore,
        );
        events.add(NotificationEvent.create(
          sourceType: NotificationSourceType.task,
          sourceId: task.id,
          eventType: task.reminderMinutesBefore == 5
              ? NotificationEventType.pre5Minutes
              : NotificationEventType.pre10Minutes,
          title: pair.title,
          notificationBody: pair.notificationBody,
          spokenMessage: pair.spokenMessage,
          scheduledTime: reminderTime,
        ));
      }
    }

    if (events.isNotEmpty) {
      await _syncEvents(events);
    }
  }

  /// Synchronize all pending tasks from TaskRepository.
  Future<void> syncAllTasks() async {
    final tasks = await _taskRepo.getTasks();
    for (final task in tasks) {
      if (!task.isDeleted && task.status == TaskStatus.pending) {
        await syncTask(task);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEST NOTIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Triggers a production test notification through the exact same Android
  /// native pipeline used for real events (fires in 5 seconds).
  Future<void> triggerTestNotification() async {
    final pair = NotificationMessageGenerator.generateTestNotification();
    final triggerAt = DateTime.now().add(const Duration(seconds: 5));

    final testEvent = NotificationEvent.create(
      sourceType: NotificationSourceType.other,
      sourceId: 'test_event',
      eventType: NotificationEventType.testNotification,
      title: pair.title,
      notificationBody: pair.notificationBody,
      spokenMessage: pair.spokenMessage,
      scheduledTime: triggerAt,
    );

    debugPrint('[NotificationEngine] Triggering test notification in 5 seconds');
    await _syncEvents([testEvent]);
  }
}
