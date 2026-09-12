import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/models/recap_models.dart';
import 'recap_generator_service.dart';
import '../../notifications/domain/models/notification_event.dart';
import '../../notifications/application/engine/notification_engine.dart';
import '../../notifications/application/engine/platform_notification_factory.dart';
import '../../settings/data/repositories/notification_settings_repository.dart';

final recapSchedulerServiceProvider = Provider<RecapSchedulerService>((ref) {
  return RecapSchedulerService(
    ref.watch(recapGeneratorServiceProvider),
    ref.watch(notificationEngineProvider),
    ref.watch(notificationSettingsRepositoryProvider),
  );
});

class RecapSchedulerService {
  final RecapGeneratorService _generator;
  final NotificationEngine _engine;
  final NotificationSettingsRepository _settings;

  RecapSchedulerService(
    this._generator,
    this._engine,
    this._settings,
  );

  /// Synchronize all scheduled recap alarms (Daily, Weekly, Monthly)
  Future<void> syncRecapAlarms() async {
    final now = DateTime.now();
    final events = <NotificationEvent>[];

    // 1. Daily Recap Alarm
    if (_settings.dailyRecapEnabled) {
      final dailyEvent = await _buildDailyRecapEvent(now);
      if (dailyEvent != null) {
        events.add(dailyEvent);
      }
    } else {
      await _engine.cancelEventsBySource('daily_recap');
    }

    // 2. Weekly Recap Alarm
    if (_settings.weeklyRecapEnabled) {
      final weeklyEvent = await _buildWeeklyRecapEvent(now);
      if (weeklyEvent != null) {
        events.add(weeklyEvent);
      }
    } else {
      await _engine.cancelEventsBySource('weekly_recap');
    }

    // 3. Monthly Recap Alarm
    if (_settings.monthlyRecapEnabled) {
      final monthlyEvent = await _buildMonthlyRecapEvent(now);
      if (monthlyEvent != null) {
        events.add(monthlyEvent);
      }
    } else {
      await _engine.cancelEventsBySource('monthly_recap');
    }

    if (events.isNotEmpty) {
      await _engine.syncEvents(events);
      debugPrint(
          '[TimoraRecap] Synced ${events.length} recap alarms to native scheduler');
    }
  }

  Future<NotificationEvent?> _buildDailyRecapEvent(DateTime now) async {
    final time = _settings.dailyRecapTime;
    var trigger =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);

    // Target date of recap: today
    var targetDate = DateTime(now.year, now.month, now.day);

    // If configured time today has already passed, schedule for tomorrow
    if (trigger.isBefore(now)) {
      trigger = trigger.add(const Duration(days: 1));
      targetDate = targetDate.add(const Duration(days: 1));
    }

    // Generate preview recap for speech and notification body
    final recap = await _generator.generateDailyRecap(
      targetDate: targetDate,
      saveToDiary: false, // Save happens upon delivery or explicit user open
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final speak =
        _settings.spokenAnnouncementsEnabled ? recap.spokenScript : '';

    return NotificationEvent.create(
      sourceType: NotificationSourceType.recap,
      sourceId: 'daily_recap',
      eventType: NotificationEventType.dailyRecap,
      title: '🧠 Your Daily Recap is Ready',
      notificationBody: recap.notificationBody,
      spokenMessage: speak,
      scheduledTime: trigger,
      metadata: {
        'type': 'recap',
        'recapType': 'daily',
        'date': dateStr,
      },
    );
  }

  Future<NotificationEvent?> _buildWeeklyRecapEvent(DateTime now) async {
    final time = _settings.weeklyRecapTime;
    final targetWeekday = _settings.weeklyRecapWeekday;

    int daysUntil = (targetWeekday - now.weekday) % 7;
    var trigger = DateTime(
        now.year, now.month, now.day + daysUntil, time.hour, time.minute);

    if (trigger.isBefore(now)) {
      trigger = trigger.add(const Duration(days: 7));
    }

    final recap = await _generator.generateWeeklyRecap(
      targetDate: trigger,
      saveToDiary: false,
    );

    final speak =
        _settings.spokenAnnouncementsEnabled ? recap.spokenScript : '';

    return NotificationEvent.create(
      sourceType: NotificationSourceType.recap,
      sourceId: 'weekly_recap',
      eventType: NotificationEventType.weeklyRecap,
      title: '🧠 Your Weekly Recap is Ready',
      notificationBody: recap.notificationBody,
      spokenMessage: speak,
      scheduledTime: trigger,
      metadata: {
        'type': 'recap',
        'recapType': 'weekly',
        'date': DateFormat('yyyy-MM-dd').format(trigger),
      },
    );
  }

  Future<NotificationEvent?> _buildMonthlyRecapEvent(DateTime now) async {
    final time = _settings.monthlyRecapTime;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    var trigger =
        DateTime(now.year, now.month, lastDay, time.hour, time.minute);

    if (trigger.isBefore(now)) {
      final nextMonthLastDay = DateTime(now.year, now.month + 2, 0).day;
      trigger = DateTime(
          now.year, now.month + 1, nextMonthLastDay, time.hour, time.minute);
    }

    final recap = await _generator.generateMonthlyRecap(
      targetDate: trigger,
      saveToDiary: false,
    );

    final speak =
        _settings.spokenAnnouncementsEnabled ? recap.spokenScript : '';

    return NotificationEvent.create(
      sourceType: NotificationSourceType.recap,
      sourceId: 'monthly_recap',
      eventType: NotificationEventType.monthlyRecap,
      title: '🧠 Your Monthly Recap is Ready',
      notificationBody: recap.notificationBody,
      spokenMessage: speak,
      scheduledTime: trigger,
      metadata: {
        'type': 'recap',
        'recapType': 'monthly',
        'date': DateFormat('yyyy-MM-dd').format(trigger),
      },
    );
  }

  /// Triggers an immediate test recap notification with real native TTS speech
  /// firing in 3 seconds.
  Future<void> triggerTestRecapNotification({
    RecapType type = RecapType.daily,
  }) async {
    final now = DateTime.now();
    final triggerAt = now.add(const Duration(seconds: 3));

    TimoraRecapModel recap;
    String title;
    switch (type) {
      case RecapType.daily:
        recap = await _generator.generateDailyRecap(
            targetDate: now, saveToDiary: true);
        title = '🧠 Your Daily Recap is Ready';
        break;
      case RecapType.weekly:
        recap = await _generator.generateWeeklyRecap(
            targetDate: now, saveToDiary: false);
        title = '🧠 Your Weekly Recap is Ready';
        break;
      case RecapType.monthly:
        recap = await _generator.generateMonthlyRecap(
            targetDate: now, saveToDiary: false);
        title = '🧠 Your Monthly Recap is Ready';
        break;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final speak =
        _settings.spokenAnnouncementsEnabled ? recap.spokenScript : '';

    final testEvent = NotificationEvent.create(
      sourceType: NotificationSourceType.recap,
      sourceId: 'test_recap_${type.name}',
      eventType: type == RecapType.daily
          ? NotificationEventType.dailyRecap
          : (type == RecapType.weekly
              ? NotificationEventType.weeklyRecap
              : NotificationEventType.monthlyRecap),
      title: title,
      notificationBody: recap.notificationBody,
      spokenMessage: speak,
      scheduledTime: triggerAt,
      metadata: {
        'type': 'recap',
        'recapType': type.name,
        'date': dateStr,
      },
    );

    debugPrint('[TimoraRecap] Scheduling test recap alarm in 3 seconds');
    await _engine.syncEvents([testEvent]);
  }
}
