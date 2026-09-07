import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:timora/features/notifications/domain/models/notification_event.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'notification_engine.dart';
import 'web_bridge.dart';

/// WebNotificationEngine — Browser-native implementation using the HTML5 Notification API
/// and Web SpeechSynthesis API.
///
/// Handles in-tab scheduling, active reminders (10m, 5m, start, end, 10 PM plan),
/// and respects browser permissions & audio policies.
class WebNotificationEngine implements NotificationEngine {
  final NotificationSettingsRepository? _settingsRepo;

  final List<NotificationEvent> _scheduledEvents = [];
  final Set<String> _firedEventKeys = {};
  Timer? _schedulerTimer;
  Timer? _monitorTimer;
  bool _initialized = false;

  WebNotificationEngine({NotificationSettingsRepository? settingsRepo})
      : _settingsRepo = settingsRepo;

  bool get _notificationsEnabled =>
      _settingsRepo?.notificationsEnabled ?? true;
  bool get _spokenEnabled =>
      _settingsRepo?.spokenAnnouncementsEnabled ?? true;
  double get _speakingSpeed =>
      _settingsRepo?.speakingSpeed ?? 1.0;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _startSchedulerLoop();
    debugPrint('[TimoraWebNotif] WebNotificationEngine initialized');
  }

  @override
  Future<bool> requestPermission() async {
    if (!WebBridge.isNotificationSupported()) {
      debugPrint('[TimoraWebNotif] Notifications not supported in this browser');
      return false;
    }
    try {
      final status = await WebBridge.requestNotificationPermission();
      debugPrint('[TimoraWebNotif] Permission requested, status: $status');
      return status == 'granted';
    } catch (e) {
      debugPrint('[TimoraWebNotif] Error requesting permission: $e');
      return false;
    }
  }

  @override
  Future<bool> getPermissionStatus() async {
    if (!WebBridge.isNotificationSupported()) return false;
    return WebBridge.getNotificationPermission() == 'granted';
  }

  @override
  Future<void> syncEvents(List<NotificationEvent> events) async {
    final now = DateTime.now();
    // Filter out past events
    _scheduledEvents.removeWhere((e) => e.scheduledTime.isBefore(now));

    // Update with new events, deduplicating by ID
    for (final newEvent in events) {
      if (newEvent.scheduledTime.isAfter(now)) {
        _scheduledEvents.removeWhere((e) => e.id == newEvent.id);
        _scheduledEvents.add(newEvent);
      }
    }
    debugPrint('[TimoraWebNotif] Synced ${_scheduledEvents.length} events to web scheduler');
  }

  @override
  Future<void> cancelEventsBySource(String sourceId) async {
    _scheduledEvents.removeWhere((e) => e.sourceId == sourceId);
  }

  @override
  Future<void> cancelById(int numericId) async {
    _scheduledEvents.removeWhere((e) => e.numericId == numericId);
  }

  @override
  Future<void> cancelAll() async {
    _scheduledEvents.clear();
    _firedEventKeys.clear();
  }

  @override
  Future<void> showImmediateNotification(
    int id,
    String title,
    String body, {
    String? payload,
    bool playSound = true,
  }) async {
    if (!_notificationsEnabled) return;
    WebBridge.showNotification(
      title,
      body,
      tag: 'timora_$id',
    );
  }

  @override
  Future<bool> speak(
    String phrase, {
    String? dedupeKey,
    double rate = 1.0,
  }) async {
    if (!_spokenEnabled) return false;
    if (phrase.trim().isEmpty) return false;

    final isMale = _settingsRepo?.isMaleVoice ?? false;
    final pitch = isMale ? 0.90 : 1.05;
    final effectiveRate = (_speakingSpeed * rate).clamp(0.5, 2.0);
    return WebBridge.speak(phrase, rate: effectiveRate, pitch: pitch);
  }

  @override
  Future<void> stopSpeech() async {
    WebBridge.stopSpeech();
  }

  void _startSchedulerLoop() {
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAndTriggerEvents();
    });
  }

  void _checkAndTriggerEvents() {
    if (!_notificationsEnabled && !_spokenEnabled) return;

    final now = DateTime.now();
    // Clean up fired events older than 10 minutes
    if (_firedEventKeys.length > 200) {
      _firedEventKeys.clear();
    }

    for (final event in List<NotificationEvent>.from(_scheduledEvents)) {
      final diff = now.difference(event.scheduledTime);
      // Trigger if within -5s to +45s window
      if (diff.inSeconds >= -5 && diff.inSeconds <= 45) {
        final key = '${event.id}_${event.scheduledTime.minute}';
        if (!_firedEventKeys.contains(key)) {
          _firedEventKeys.add(key);
          _executeEvent(event);
        }
      }
    }
  }

  void _executeEvent(NotificationEvent event) {
    debugPrint('[TimoraWebNotif] Triggering event: ${event.title}');
    
    // 1. Show visible browser notification
    if (_notificationsEnabled) {
      WebBridge.showNotification(
        event.title,
        event.notificationBody,
        tag: 'timora_${event.numericId}',
      );
    }

    // 2. Speak announcement if enabled
    if (_spokenEnabled && event.spokenMessage.isNotEmpty) {
      speak(event.spokenMessage);
    }
  }

  @override
  void startScheduleMonitoring(
    Future<List<ScheduleActivity>> Function() getTodayActivities, {
    Future<List<dynamic>> Function()? getTasks,
  }) {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final activities = await getTodayActivities();
        final now = DateTime.now();

        for (final act in activities) {
          if (act.status == ActivityStatus.completed ||
              act.status == ActivityStatus.skipped) {
            continue;
          }

          final diff = now.difference(act.startTime);
          if (diff.inSeconds >= -5 && diff.inSeconds <= 45) {
            final key = 'act_start_${act.id}_${act.startTime.minute}';
            if (!_firedEventKeys.contains(key)) {
              _firedEventKeys.add(key);
              final phrase = 'Your ${act.title} starts now.';
              if (_notificationsEnabled) {
                WebBridge.showNotification("It's time for ${act.title}", phrase);
              }
              if (_spokenEnabled) {
                speak(phrase);
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  @override
  void stopScheduleMonitoring() {
    _schedulerTimer?.cancel();
    _monitorTimer?.cancel();
    _schedulerTimer = null;
    _monitorTimer = null;
  }
}
