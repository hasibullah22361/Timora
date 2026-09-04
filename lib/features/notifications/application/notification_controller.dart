import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import 'voice_announcement_service.dart';
import 'alarm_scheduler_service.dart';
import 'notification_event_engine.dart';

final notificationControllerProvider = Provider<NotificationController>((ref) {
  return NotificationController(
    ref.watch(notificationServiceProvider),
    ref.watch(voiceAnnouncementServiceProvider),
    ref.watch(alarmSchedulerServiceProvider),
    ref.watch(notificationEventEngineProvider),
  );
});

class NotificationController {
  final NotificationService _service;
  final VoiceAnnouncementService _voiceService;
  final AlarmSchedulerService _alarmScheduler;
  final NotificationEventEngine _engine;

  NotificationController(
    this._service,
    this._voiceService,
    this._alarmScheduler,
    this._engine,
  ) {
    // Notification tap — speak the activity name (foreground only path)
    _service.onNotificationResponse = _handleNotificationResponse;
  }

  void _handleNotificationResponse(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('[TimoraAlarm] Notification tapped with payload: $payload');
    _voiceService.speakNotification(title: payload, body: null);
  }

  /// Cancel all notifications and native alarms for a specific activity.
  Future<void> cancelAllForActivity(String activityId) async {
    await _alarmScheduler.cancelEventsBySource(activityId);
  }

  /// Synchronize all speaking alarms and notifications for the given date.
  Future<void> syncScheduleNotifications(DateTime date) async {
    await _engine.syncSchedule(date);
  }
}
