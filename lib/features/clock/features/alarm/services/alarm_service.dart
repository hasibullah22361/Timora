import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/notifications/application/notification_service.dart';
import 'package:timora/features/clock/features/alarm/data/models/alarm_model.dart';
import 'package:timora/features/clock/features/alarm/presentation/providers/alarm_provider.dart';
import 'package:timora/features/clock/features/alarm/presentation/screens/alarm_ringing_screen.dart';
import 'package:timora/features/widget/services/widget_navigation_service.dart';

final alarmServiceProvider = Provider<AlarmService>((ref) {
  final notifService = ref.watch(notificationServiceProvider);
  final service = AlarmService(notifService, ref: ref);
  service.initialize();
  return service;
});

class AlarmService {
  final NotificationService _notificationService;
  final Ref? _ref;
  static const MethodChannel _clockChannel = MethodChannel('timora/clock_alarm');
  static bool _handlerInitialized = false;

  static final StreamController<String> _alarmSilencedController =
      StreamController<String>.broadcast();
  static Stream<String> get onAlarmSilencedStream =>
      _alarmSilencedController.stream;

  static final StreamController<Map<String, dynamic>> _alarmDismissedController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get onAlarmDismissedStream =>
      _alarmDismissedController.stream;

  @visibleForTesting
  static void notifySilencedForTesting(String alarmId) {
    _alarmSilencedController.add(alarmId);
  }

  @visibleForTesting
  static void notifyDismissedForTesting(Map<String, dynamic> data) {
    _alarmDismissedController.add(data);
  }

  AlarmService(this._notificationService, {Ref? ref}) : _ref = ref;

  void initialize() {
    if (_handlerInitialized || kIsWeb || !Platform.isAndroid) return;
    _handlerInitialized = true;

    _clockChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmRinging') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          final alarmId = (args['alarmId'] ?? '').toString();
          final title = (args['title'] ?? 'Alarm').toString();
          final timeFormatted = (args['timeFormatted'] ?? '').toString();
          final snoozeMinutes = (args['snoozeMinutes'] as num?)?.toInt() ?? 5;
          _openAlarmRingingScreen(
            alarmId: alarmId,
            title: title,
            timeFormatted: timeFormatted,
            snoozeMinutes: snoozeMinutes,
          );
        }
      } else if (call.method == 'onAlarmSilenced') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        final alarmId = (args?['alarmId'] ?? '').toString();
        debugPrint('[AlarmService] Alarm silenced: $alarmId');
        _alarmSilencedController.add(alarmId);
      } else if (call.method == 'onAlarmDismissed') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        final alarmId = (args?['alarmId'] ?? '').toString();
        final action = (args?['action'] ?? 'stop').toString();
        final snoozeMinutes = (args?['snoozeMinutes'] as num?)?.toInt() ?? 5;
        debugPrint('[AlarmService] Alarm dismissed from native: id=$alarmId, action=$action');
        _handleNativeDismiss(
          alarmId: alarmId,
          action: action,
          snoozeMinutes: snoozeMinutes,
        );
        _alarmDismissedController.add({
          'alarmId': alarmId,
          'action': action,
          'snoozeMinutes': snoozeMinutes,
        });
      }
    });

    // Check if app was opened via full-screen intent
    _checkInitialAlarm();
  }

  void _handleNativeDismiss({
    required String alarmId,
    required String action,
    required int snoozeMinutes,
  }) {
    final ref = _ref;
    if (ref != null) {
      try {
        final alarms = ref.read(alarmsListProvider);
        final current = alarms.where((a) => a.id == alarmId).firstOrNull;
        if (current != null) {
          if (action == 'stop') {
            if (!current.isRepeating) {
              ref.read(alarmsListProvider.notifier).updateAlarm(current.copyWith(isEnabled: false));
            }
          } else if (action == 'snooze') {
            ref.read(alarmsListProvider.notifier).snooze(current, minutes: snoozeMinutes);
          }
        }
      } catch (e) {
        debugPrint('[AlarmService] Notice synchronizing alarm dismiss: $e');
      }
    }
  }

  Future<void> _checkInitialAlarm() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final dynamic result = await _clockChannel.invokeMethod('getInitialAlarm');
      if (result is Map) {
        final alarmId = (result['alarmId'] ?? '').toString();
        final title = (result['title'] ?? 'Alarm').toString();
        final timeFormatted = (result['timeFormatted'] ?? '').toString();
        final snoozeMinutes = (result['snoozeMinutes'] as num?)?.toInt() ?? 5;
        if (alarmId.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _openAlarmRingingScreen(
              alarmId: alarmId,
              title: title,
              timeFormatted: timeFormatted,
              snoozeMinutes: snoozeMinutes,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('[AlarmService] Notice checking initial alarm: $e');
    }
  }

  void _openAlarmRingingScreen({
    required String alarmId,
    required String title,
    required String timeFormatted,
    required int snoozeMinutes,
  }) {
    final context = WidgetNavigationService.navigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openAlarmRingingScreen(
          alarmId: alarmId,
          title: title,
          timeFormatted: timeFormatted,
          snoozeMinutes: snoozeMinutes,
        );
      });
      return;
    }

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => AlarmRingingScreen(
          alarmId: alarmId,
          title: title,
          timeFormatted: timeFormatted,
          snoozeMinutes: snoozeMinutes,
        ),
      ),
    );
  }

  int getNotificationId(String alarmId) {
    return (alarmId.hashCode.abs() % 100000) + 10000;
  }

  Future<void> scheduleAlarm(AlarmModel alarm) async {
    if (!alarm.isEnabled) {
      await cancelAlarm(alarm.id);
      return;
    }

    final now = DateTime.now();
    final triggerTime = alarm.nextTriggerDateTime(now);
    final delay = triggerTime.difference(now);
    final notifId = getNotificationId(alarm.id);

    // Logging detailed scheduling metrics as required
    debugPrint('[AlarmService] ================= SCHEDULING ALARM =================');
    debugPrint('[AlarmService] Alarm ID: ${alarm.id}');
    debugPrint('[AlarmService] Current timestamp: ${now.toIso8601String()}');
    debugPrint('[AlarmService] Target timestamp:  ${triggerTime.toIso8601String()}');
    debugPrint('[AlarmService] Calculated delay:  ${delay.inSeconds}s (${delay.inMilliseconds}ms)');

    // 1. Native exact AlarmManager.setAlarmClock registration
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _clockChannel.invokeMethod<bool>('scheduleClockAlarm', {
          'id': alarm.id,
          'title': alarm.label,
          'timeFormatted': alarm.formatTime(),
          'triggerAtMillis': triggerTime.millisecondsSinceEpoch,
          'snoozeMinutes': alarm.snoozeDurationMinutes,
        });
        debugPrint('[AlarmService] Native AlarmManager scheduling result: $result');
      } catch (e) {
        debugPrint('[AlarmService] Error invoking native scheduleClockAlarm: $e');
      }
    }

    // 2. NotificationService backup schedule
    // On Android, playSound & enableVibration are false on the backup notification
    // to prevent duplicate audio ringing (TimoraClockAlarmService plays audio via USAGE_ALARM).
    final isAndroidDevice = !kIsWeb && Platform.isAndroid;
    final payload = jsonEncode({
      'type': 'alarm',
      'alarmId': alarm.id,
      'label': alarm.label,
      'snoozeMinutes': alarm.snoozeDurationMinutes,
    });

    await _notificationService.scheduleNotification(
      notifId,
      '⏰ Alarm: ${alarm.label}',
      'Scheduled for ${alarm.formatTime()}',
      triggerTime,
      channelId: 'timora_alarm',
      payload: payload,
      playSound: isAndroidDevice ? false : (alarm.sound != 'Silent'),
      enableVibration: isAndroidDevice ? false : alarm.vibration,
    );

    debugPrint('[AlarmService] ===================================================');
  }

  Future<void> cancelAlarm(String alarmId) async {
    final notifId = getNotificationId(alarmId);
    debugPrint('[AlarmService] [DISMISS EVENT] Cancelling alarm $alarmId (notifId: $notifId)');

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _clockChannel.invokeMethod('cancelClockAlarm', {'id': alarmId});
      } catch (e) {
        debugPrint('[AlarmService] Error cancelling native alarm: $e');
      }
    }

    await _notificationService.cancelNotification(notifId);
  }

  Future<void> stopAlarmSound() async {
    debugPrint('[AlarmService] [DISMISS EVENT] Stopping native alarm sound');
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _clockChannel.invokeMethod('stopAlarmSound');
      } catch (e) {
        debugPrint('[AlarmService] Error stopping alarm sound: $e');
      }
    }
  }

  Future<void> silenceAlarmSound() async {
    debugPrint('[AlarmService] [SILENCE EVENT] Silencing native alarm sound');
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _clockChannel.invokeMethod('silenceAlarmSound');
      } catch (e) {
        debugPrint('[AlarmService] Error silencing alarm sound: $e');
      }
    }
  }

  Future<void> snoozeAlarm(AlarmModel alarm, {int? snoozeMinutes}) async {
    final mins = snoozeMinutes ?? alarm.snoozeDurationMinutes;
    final now = DateTime.now();
    final snoozeTime = now.add(Duration(minutes: mins));
    final notifId = getNotificationId(alarm.id);

    debugPrint('[AlarmService] [SNOOZE EVENT] Snoozing alarm "${alarm.label}" (id: ${alarm.id}) for $mins minutes until $snoozeTime');

    // 1. Stop current alarm sound
    await stopAlarmSound();

    // 2. Schedule native exact alarm clock for snooze time
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _clockChannel.invokeMethod('scheduleClockAlarm', {
          'id': alarm.id,
          'title': '${alarm.label} (Snoozed)',
          'timeFormatted': alarm.formatTime(),
          'triggerAtMillis': snoozeTime.millisecondsSinceEpoch,
          'snoozeMinutes': mins,
        });
      } catch (e) {
        debugPrint('[AlarmService] Error scheduling native snooze alarm: $e');
      }
    }

    // 3. NotificationService backup schedule
    final isAndroidDevice = !kIsWeb && Platform.isAndroid;
    final payload = jsonEncode({
      'type': 'alarm',
      'alarmId': alarm.id,
      'label': '${alarm.label} (Snoozed)',
      'snoozeMinutes': mins,
    });

    await _notificationService.scheduleNotification(
      notifId,
      '⏰ Snoozed Alarm: ${alarm.label}',
      'Snoozed for $mins min',
      snoozeTime,
      channelId: 'timora_alarm',
      payload: payload,
      playSound: isAndroidDevice ? false : (alarm.sound != 'Silent'),
      enableVibration: isAndroidDevice ? false : alarm.vibration,
    );
  }

  Future<void> syncAllAlarms(List<AlarmModel> alarms) async {
    for (final alarm in alarms) {
      if (alarm.isEnabled) {
        await scheduleAlarm(alarm);
      } else {
        await cancelAlarm(alarm.id);
      }
    }
  }
}
