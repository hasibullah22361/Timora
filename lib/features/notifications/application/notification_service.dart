import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Background isolate notification action handler — safe, no UI calls
}

typedef NotificationResponseCallback = void Function(String? payload);

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  NotificationResponseCallback? onNotificationResponse;

  Future<void> initialize({NotificationResponseCallback? onResponse}) async {
    if (_isInitialized) return;
    onNotificationResponse = onResponse;

    const androidInitialize =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettings = InitializationSettings(
      android: androidInitialize,
    );

    try {
      await _plugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            onNotificationResponse?.call(response.payload);
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await _createChannels();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization skipped or failed: $e');
    }
  }

  Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;

    // Channel for routine/schedule reminders that should play a sound
    const routineChannel = AndroidNotificationChannel(
      'timora_routine',
      'Timora Routine',
      description: 'Notifications for activity start and end times',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Channel for daily planning reminders
    const dailyChannel = AndroidNotificationChannel(
      'timora_daily',
      'Timora Daily',
      description: 'Daily planning and review reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Silent channel — used when TTS will speak instead of the notification sound.
    // No sound, no vibration; only a visual notification bar entry.
    const voiceChannel = AndroidNotificationChannel(
      'timora_voice',
      'Timora Voice Alerts',
      description: 'Silent visual notification accompanying spoken alerts',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(routineChannel);
    await androidImplementation?.createNotificationChannel(dailyChannel);
    await androidImplementation?.createNotificationChannel(voiceChannel);
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation == null) return false;

    final granted =
        await androidImplementation.requestNotificationsPermission();

    // Required if Timora uses exact scheduled alarms on Android 12+.
    try {
      await androidImplementation.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[TimoraNotif] Exact alarms permission notice: $e');
    }

    return granted ?? false;
  }

  Future<bool> getNotificationPermissionStatus() async {
    if (!Platform.isAndroid) return false;

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidImplementation?.areNotificationsEnabled();
    return granted ?? false;
  }

  NotificationDetails _notificationDetails(
    String channelId, {
    bool playSound = true,
    bool enableVibration = true,
  }) {
    String channelName;
    String channelDescription;
    Importance importance;
    Priority priority;

    switch (channelId) {
      case 'timora_routine':
        channelName = 'Timora Routine';
        channelDescription = 'Notifications for activity start and end times';
        importance = Importance.max;
        priority = Priority.high;
        break;
      case 'timora_voice':
        channelName = 'Timora Voice Alerts';
        channelDescription = 'Silent visual notification accompanying spoken alerts';
        importance = Importance.low;
        priority = Priority.low;
        playSound = false;
        enableVibration = false;
        break;
      default: // timora_daily
        channelName = 'Timora Daily';
        channelDescription = 'Daily planning and review reminders';
        importance = Importance.high;
        priority = Priority.defaultPriority;
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: priority,
        playSound: playSound,
        enableVibration: enableVibration,
      ),
    );
  }

  /// Show an immediate notification with sound (for standard reminders).
  Future<void> showImmediateNotification(
    int id,
    String title,
    String body, {
    String channelId = 'timora_daily',
    String? payload,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    final details = _notificationDetails(
      channelId,
      playSound: playSound,
      enableVibration: enableVibration,
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (_) {}
  }

  /// Show a silent visual notification — to be paired with TTS speech.
  /// Does NOT play the default Android notification sound.
  Future<void> showSilentNotification(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    final details = _notificationDetails('timora_voice');

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (_) {}
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate, {
    String channelId = 'timora_routine',
    String? payload,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    final details = _notificationDetails(
      channelId,
      playSound: playSound,
      enableVibration: enableVibration,
    );

    final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {}
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
