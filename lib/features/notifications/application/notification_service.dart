import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidInitialize =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettings = InitializationSettings(
      android: androidInitialize,
    );

    await _plugin.initialize(
      settings: initializationSettings,
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
      importance: Importance.high,
    );

    const dailyChannel = AndroidNotificationChannel(
      'timora_daily',
      'Timora Daily',
      description: 'Daily planning and review reminders',
      importance: Importance.defaultImportance,
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

    // Required if Timora uses exact scheduled alarms.
    await androidImplementation.requestExactAlarmsPermission();

    return granted ?? false;
  }

  Future<bool> getNotificationPermissionStatus() async {
    if (!Platform.isAndroid) return false;

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidImplementation?.areNotificationsEnabled();

    return granted ?? false;
  }

  NotificationDetails _notificationDetails(String channelId) {
    final isRoutine = channelId == 'timora_routine';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        isRoutine ? 'Timora Routine' : 'Timora Daily',
        channelDescription: isRoutine
            ? 'Notifications for activity start and end times'
            : 'Daily planning and review reminders',
        importance: isRoutine ? Importance.high : Importance.defaultImportance,
        priority: isRoutine ? Priority.high : Priority.defaultPriority,
      ),
    );
  }

  Future<void> showImmediateNotification(
    int id,
    String title,
    String body, {
    String channelId = 'timora_daily',
  }) async {
    final details = _notificationDetails(channelId);

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate, {
    String channelId = 'timora_routine',
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    final details = _notificationDetails(channelId);

    final scheduledTime = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}
