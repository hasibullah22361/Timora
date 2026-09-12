import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import 'voice_announcement_service.dart';
import 'alarm_scheduler_service.dart';
import 'notification_event_engine.dart';
import '../../widget/services/widget_navigation_service.dart';
import '../../ai_assistant/presentation/screens/morning_brief_screen.dart';
import '../../ai_assistant/presentation/widgets/daily_debrief_sheet.dart';
import '../../clock/features/alarm/presentation/screens/alarm_screen.dart';
import '../../clock/features/alarm/presentation/screens/alarm_ringing_screen.dart';
import '../../clock/features/alarm/data/models/alarm_model.dart';
import '../../clock/features/alarm/services/alarm_service.dart';
import '../../clock/features/timer/presentation/screens/timer_screen.dart';
import '../../recap/presentation/screens/recap_screen.dart';
import '../../recap/domain/models/recap_models.dart';

final notificationControllerProvider = Provider<NotificationController>((ref) {
  return NotificationController(
    ref.watch(notificationServiceProvider),
    ref.watch(voiceAnnouncementServiceProvider),
    ref.watch(alarmSchedulerServiceProvider),
    ref.watch(notificationEventEngineProvider),
    ref.watch(alarmServiceProvider),
  );
});

class NotificationController {
  final NotificationService _service;
  final VoiceAnnouncementService _voiceService;
  final AlarmSchedulerService _alarmScheduler;
  final NotificationEventEngine _engine;
  final AlarmService? _alarmService;

  NotificationController(
    this._service,
    this._voiceService,
    this._alarmScheduler,
    this._engine, [
    this._alarmService,
  ]) {
    // Notification tap — speak the activity name (foreground only path)
    _service.onNotificationResponse = handleNotificationResponse;
  }

  void handleNotificationResponse(String? payload, {String? actionId}) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('[TimoraAlarm] Notification tapped with payload: $payload, actionId: $actionId');

    final context = WidgetNavigationService.navigatorKey.currentContext;

    if (payload == 'morning_brief') {
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MorningBriefScreen()),
        );
      }
      return;
    }

    if (payload == 'daily_debrief') {
      if (context != null) {
        DailyDebriefSheet.show(context);
      }
      return;
    }

    // Recap payload / action routing
    if (payload.contains('"type":"recap"') ||
        payload.contains('recap') ||
        payload.startsWith('recap')) {
      if (context != null) {
        RecapType type = RecapType.daily;
        if (payload.contains('weekly')) {
          type = RecapType.weekly;
        } else if (payload.contains('monthly')) {
          type = RecapType.monthly;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecapScreen(recapType: type)),
        );
      }
      return;
    }

    // Alarm payload / action routing
    if (payload.contains('"type":"alarm"') || payload.startsWith('alarm')) {
      if (actionId == 'dismiss_alarm' || actionId == 'stop') {
        _alarmService?.stopAlarmSound();
        _alarmScheduler.cancelAllAlarms();
        return;
      }

      if (actionId == 'snooze_alarm' || actionId == 'snooze') {
        try {
          final data = jsonDecode(payload);
          final alarmId = data['alarmId']?.toString() ?? '';
          final label = data['label']?.toString() ?? 'Alarm';
          final snoozeMins = (data['snoozeMinutes'] as num?)?.toInt() ?? 5;
          final tempAlarm = AlarmModel(
            id: alarmId,
            hour: DateTime.now().hour,
            minute: DateTime.now().minute,
            label: label,
            snoozeDurationMinutes: snoozeMins,
          );
          _alarmService?.snoozeAlarm(tempAlarm, snoozeMinutes: snoozeMins);
        } catch (_) {}
        return;
      }

      if (context != null) {
        try {
          final data = jsonDecode(payload);
          final alarmId = data['alarmId']?.toString() ?? '';
          final label = data['label']?.toString() ?? 'Alarm';
          final snoozeMins = (data['snoozeMinutes'] as num?)?.toInt() ?? 5;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AlarmRingingScreen(
                alarmId: alarmId,
                title: label,
                snoozeMinutes: snoozeMins,
              ),
            ),
          );
          return;
        } catch (_) {}

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AlarmScreen()),
        );
      }
      return;
    }

    // Timer payload / action routing
    if (payload.contains('"type":"timer"') || payload.startsWith('timer')) {
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TimerScreen()),
        );
      }
      return;
    }

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
