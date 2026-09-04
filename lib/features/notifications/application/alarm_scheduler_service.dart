import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/notification_event.dart';

final alarmSchedulerServiceProvider = Provider<AlarmSchedulerService>((ref) {
  return AlarmSchedulerService();
});

/// AlarmSchedulerService — Dart ↔ Android bridge for persistent speaking alarms and notifications.
///
/// Calls the "timora/alarm" MethodChannel to persist [NotificationEvent] records to
/// Android SharedPreferences and register exact AlarmManager alarms.
/// The alarms are received by [TimoraSpeakingReceiver], which posts a persistent visible
/// notification card and speaks the message via native Android TextToSpeech.
class AlarmSchedulerService {
  static const _channel = MethodChannel('timora/alarm');

  /// Schedule a batch of [NotificationEvent]s on the native Android scheduler.
  Future<void> syncEvents(List<NotificationEvent> events) async {
    if (!Platform.isAndroid || events.isEmpty) return;

    final eventsJson = events.map((e) => e.toJson()).toList();
    try {
      await _channel.invokeMethod('syncEvents', {'events': eventsJson});
      debugPrint(
          '[TimoraAlarm] Synced ${events.length} notification events to native Android scheduler');
    } on PlatformException catch (e) {
      debugPrint('[TimoraAlarm] PlatformException syncing events: ${e.message}');
    } catch (e) {
      debugPrint('[TimoraAlarm] Error syncing events: $e');
    }
  }

  /// Cancel all native alarms and stored events associated with a specific entity source ID.
  Future<void> cancelEventsBySource(String sourceId) async {
    if (!Platform.isAndroid || sourceId.isEmpty) return;
    try {
      await _channel.invokeMethod('cancelEventsBySource', {'sourceId': sourceId});
      debugPrint('[TimoraAlarm] Cancelled events for sourceId: $sourceId');
    } catch (e) {
      debugPrint('[TimoraAlarm] cancelEventsBySource error: $e');
    }
  }

  /// Cancel a specific alarm by its numeric ID.
  Future<void> cancelById(int numericId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelAlarm', {'id': numericId});
      debugPrint('[TimoraAlarm] Cancelled alarm id=$numericId');
    } catch (e) {
      debugPrint('[TimoraAlarm] cancelAlarm error: $e');
    }
  }

  /// Cancel all scheduled alarms and clear persistent store.
  Future<void> cancelAllAlarms() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelAllAlarms');
      debugPrint('[TimoraAlarm] Cancelled all alarms');
    } catch (e) {
      debugPrint('[TimoraAlarm] cancelAllAlarms error: $e');
    }
  }

  /// Immediately synchronize spoken announcements setting to Android native SharedPreferences.
  Future<void> updateSpokenSetting(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateSpokenSetting', {'enabled': enabled});
      debugPrint('[TimoraAlarm] updateSpokenSetting sent to Android: $enabled');
    } catch (e) {
      debugPrint('[TimoraAlarm] updateSpokenSetting error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEGACY COMPATIBILITY HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  int alarmId(String entityId, String eventType) {
    return (entityId + eventType).hashCode.abs() % 0x7FFFFFFF;
  }

  Future<void> scheduleTaskAlarm({
    required String taskId,
    required String taskName,
    required DateTime triggerAt,
  }) async {
    final event = NotificationEvent.create(
      sourceType: NotificationSourceType.task,
      sourceId: taskId,
      eventType: NotificationEventType.activityStart,
      title: 'Task: $taskName',
      notificationBody: "It's time for $taskName.",
      spokenMessage: 'Your $taskName task starts now.',
      scheduledTime: triggerAt,
    );
    await syncEvents([event]);
  }

  Future<void> scheduleActivityStartAlarm({
    required String activityId,
    required String activityName,
    required DateTime triggerAt,
  }) async {
    final event = NotificationEvent.create(
      sourceType: NotificationSourceType.schedule,
      sourceId: activityId,
      eventType: NotificationEventType.activityStart,
      title: "It's time for $activityName",
      notificationBody: "It's time for $activityName.",
      spokenMessage: "It's time for your $activityName. Your activity starts now.",
      scheduledTime: triggerAt,
    );
    await syncEvents([event]);
  }

  Future<void> scheduleActivityReminder({
    required String activityId,
    required String activityName,
    required DateTime triggerAt,
    required int minutesBefore,
    bool isEnd = false,
  }) async {
    final event = NotificationEvent.create(
      sourceType: NotificationSourceType.schedule,
      sourceId: activityId,
      eventType: minutesBefore == 5
          ? NotificationEventType.pre5Minutes
          : NotificationEventType.pre10Minutes,
      title: '$activityName in $minutesBefore min',
      notificationBody: '$activityName starts in $minutesBefore minutes. Get ready.',
      spokenMessage: 'Your $activityName starts in $minutesBefore minutes. Get ready.',
      scheduledTime: triggerAt,
    );
    await syncEvents([event]);
  }

  Future<void> scheduleNextActivityAlarm({
    required String currentActivityId,
    required String nextActivityName,
    required DateTime triggerAt,
    required String nextTimeStr,
  }) async {
    // Preserved for backwards compatibility
    final event = NotificationEvent.create(
      sourceType: NotificationSourceType.schedule,
      sourceId: currentActivityId,
      eventType: NotificationEventType.activityStart,
      title: 'Next: $nextActivityName',
      notificationBody: 'Next activity starts at $nextTimeStr.',
      spokenMessage: 'Next: $nextActivityName at $nextTimeStr.',
      scheduledTime: triggerAt,
    );
    await syncEvents([event]);
  }

  Future<void> scheduleTestAlarm() async {
    final triggerAt = DateTime.now().add(const Duration(seconds: 5));
    final testEvent = NotificationEvent.create(
      sourceType: NotificationSourceType.other,
      sourceId: 'test_event',
      eventType: NotificationEventType.testNotification,
      title: 'Timora Test Notification',
      notificationBody: 'Your voice notification system is active and ready.',
      spokenMessage:
          'This is a Timora test notification. Your voice notification system is working.',
      scheduledTime: triggerAt,
    );
    await syncEvents([testEvent]);
  }

  Future<void> cancelTaskAlarm(String taskId) async {
    await cancelEventsBySource(taskId);
  }

  Future<void> cancelActivityAlarms(String activityId) async {
    await cancelEventsBySource(activityId);
  }

  Future<void> cancelRoutineAlarm(String blockId) async {
    await cancelEventsBySource(blockId);
  }
}
