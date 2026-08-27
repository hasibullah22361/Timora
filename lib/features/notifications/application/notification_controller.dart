import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'voice_announcement_service.dart';
import '../../settings/data/repositories/notification_settings_repository.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/data/repositories/schedule_repository.dart';

final notificationControllerProvider = Provider<NotificationController>((ref) {
  return NotificationController(
    ref.watch(notificationServiceProvider),
    ref.watch(notificationSettingsRepositoryProvider),
    ref.watch(scheduleRepositoryProvider),
    ref.watch(voiceAnnouncementServiceProvider),
  );
});

class NotificationController {
  final NotificationService _service;
  final NotificationSettingsRepository _settings;
  final ScheduleRepository _scheduleRepo;
  final VoiceAnnouncementService _voiceService;

  NotificationController(
    this._service,
    this._settings,
    this._scheduleRepo,
    this._voiceService,
  ) {
    _service.onNotificationResponse = _handleNotificationResponse;
  }

  void _handleNotificationResponse(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final activityId = data['activityId'] as String?;
      final title = data['title'] as String?;
      final startTimeStr = data['startTime'] as String?;
      final startTime = startTimeStr != null ? DateTime.tryParse(startTimeStr) : null;

      if (activityId != null && title != null) {
        _voiceService.announceActivityStart(
          activityId: activityId,
          activityName: title,
          scheduledTime: startTime,
        );
      }
    } catch (_) {}
  }

  /// Deterministic ID generator to ensure updating an activity overwrites existing notifications instead of duplicating.
  int _generateId(String stringId, String type) {
    return (stringId + type).hashCode.abs();
  }

  bool _isQuietHours(DateTime time) {
    if (!_settings.quietHoursEnabled) return false;
    
    final start = _settings.quietHoursStart;
    final end = _settings.quietHoursEnd;
    
    int timeMins = time.hour * 60 + time.minute;
    int startMins = start.hour * 60 + start.minute;
    int endMins = end.hour * 60 + end.minute;

    if (startMins <= endMins) {
      return timeMins >= startMins && timeMins <= endMins;
    } else {
      // Wraps around midnight
      return timeMins >= startMins || timeMins <= endMins;
    }
  }

  Future<void> cancelAllForActivity(String activityId) async {
    await _service.cancelNotification(_generateId(activityId, 'start_remind'));
    await _service.cancelNotification(_generateId(activityId, 'start'));
    await _service.cancelNotification(_generateId(activityId, 'end_remind'));
    await _service.cancelNotification(_generateId(activityId, 'next'));
  }

  Future<void> syncScheduleNotifications(DateTime date) async {
    if (!_settings.notificationsEnabled) {
      await _service.cancelAllNotifications();
      return;
    }

    final activities = await _scheduleRepo.getActivitiesForDate(date);
    final timeFormat = DateFormat('h:mm a');
    final playSound = _settings.soundEnabled;
    final enableVibration = _settings.vibrationEnabled;
    
    for (int i = 0; i < activities.length; i++) {
      final act = activities[i];
      final nextAct = (i + 1 < activities.length) ? activities[i + 1] : null;
      
      // 1. Delete all possible notifications for this activity ID unconditionally to reset state
      await _service.cancelNotification(_generateId(act.id, 'start_remind'));
      await _service.cancelNotification(_generateId(act.id, 'start'));
      await _service.cancelNotification(_generateId(act.id, 'end_remind'));
      await _service.cancelNotification(_generateId(act.id, 'next'));

      // 2. If deleted or skipped/completed, do not reschedule future notifications.
      if (act.status == ActivityStatus.skipped || act.status == ActivityStatus.completed) {
        continue;
      }

      final payloadJson = jsonEncode({
        'activityId': act.id,
        'title': act.title,
        'startTime': act.startTime.toIso8601String(),
      });

      // 3. Activity Starting Reminder
      if (_settings.activityStartingEnabled) {
        final reminderTime = act.startTime.subtract(Duration(minutes: _settings.defaultReminderMinutes));
        if (!_isQuietHours(reminderTime) && reminderTime.isAfter(DateTime.now())) {
          await _service.scheduleNotification(
            _generateId(act.id, 'start_remind'),
            'Timora • Up Next',
            '${act.title} starts in ${_settings.defaultReminderMinutes} minutes.',
            reminderTime,
            payload: payloadJson,
            playSound: playSound,
            enableVibration: enableVibration,
          );
        }
      }

      // 4. Activity Started Notification
      if (_settings.activityStartedEnabled) {
        if (!_isQuietHours(act.startTime) && act.startTime.isAfter(DateTime.now())) {
          await _service.scheduleNotification(
            _generateId(act.id, 'start'),
            'Timora • Focus Time',
            '${act.title} time. Let\'s get started.',
            act.startTime,
            payload: payloadJson,
            playSound: playSound,
            enableVibration: enableVibration,
          );
        }
      }

      // 5. Activity Ending Reminder
      if (_settings.activityEndingEnabled) {
        final endRemindTime = act.endTime.subtract(Duration(minutes: _settings.defaultReminderMinutes));
        if (!_isQuietHours(endRemindTime) && endRemindTime.isAfter(DateTime.now())) {
          await _service.scheduleNotification(
            _generateId(act.id, 'end_remind'),
            'Timora • Wrapping Up',
            '${act.title} ends in ${_settings.defaultReminderMinutes} minutes.',
            endRemindTime,
            payload: payloadJson,
            playSound: playSound,
            enableVibration: enableVibration,
          );
        }
      }
      
      // 6. Up Next Notification (Using end time of current activity)
      if (_settings.nextActivityEnabled && nextAct != null) {
        if (!_isQuietHours(act.endTime) && act.endTime.isAfter(DateTime.now())) {
          await _service.scheduleNotification(
            _generateId(act.id, 'next'),
            'Timora • Up Next',
            'Next: ${nextAct.title} starts at ${timeFormat.format(nextAct.startTime)}.',
            act.endTime,
            payload: payloadJson,
            playSound: playSound,
            enableVibration: enableVibration,
          );
        }
      }
    }
  }
}
