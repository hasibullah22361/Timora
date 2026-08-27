import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

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

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          onNotificationResponse?.call(response.payload);
        }
      },
    );

    await _createChannels();

    _isInitialized = true;
  }

  Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;

    const routineChannel = AndroidNotificationChannel(
      'timora_routine',
      'Timora Routine',
      description: 'Notifications for activity start and end times',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const dailyChannel = AndroidNotificationChannel(
      'timora_daily',
      'Timora Daily',
      description: 'Daily planning and review reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(
      routineChannel,
    );

    await androidImplementation?.createNotificationChannel(
      dailyChannel,
    );
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation == null) {
      return false;
    }

    final granted =
        await androidImplementation.requestNotificationsPermission();

    // Required if Timora uses exact scheduled alarms on Android 12+.
    try {
      await androidImplementation.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Exact alarms permission notice: $e');
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
    final isRoutine = channelId == 'timora_routine';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        isRoutine ? 'Timora Routine' : 'Timora Daily',
        channelDescription: isRoutine
            ? 'Notifications for activity start and end times'
            : 'Daily planning and review reminders',
        importance: isRoutine ? Importance.max : Importance.high,
        priority: isRoutine ? Priority.high : Priority.defaultPriority,
        playSound: playSound,
        enableVibration: enableVibration,
      ),
    );
  }

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

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
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
    if (scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    final details = _notificationDetails(
      channelId,
      playSound: playSound,
      enableVibration: enableVibration,
    );

    final scheduledTime = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

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
