import 'package:timora/features/notifications/domain/models/notification_event.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';

/// NotificationEngine — Abstract cross-platform interface for notifications and speech.
///
/// Android implementation: Android AlarmManager, flutter_local_notifications, native TTS.
/// Web implementation: Browser Notification API, SpeechSynthesis API, in-tab reminder loop.
abstract class NotificationEngine {
  /// Initialize the platform-specific notification system.
  Future<void> initialize();

  /// Request notification permission from the user/OS.
  Future<bool> requestPermission();

  /// Check current notification permission status.
  Future<bool> getPermissionStatus();

  /// Synchronize a batch of [NotificationEvent]s with the platform scheduler.
  Future<void> syncEvents(List<NotificationEvent> events);

  /// Cancel all events associated with a source entity ID (e.g. task ID or activity ID).
  Future<void> cancelEventsBySource(String sourceId);

  /// Cancel an individual alarm/notification by its numeric ID.
  Future<void> cancelById(int numericId);

  /// Cancel all scheduled alarms and clear state.
  Future<void> cancelAll();

  /// Immediately show a visible notification card.
  Future<void> showImmediateNotification(
    int id,
    String title,
    String body, {
    String? payload,
    bool playSound = true,
  });

  /// Speak a natural announcement phrase aloud.
  Future<bool> speak(
    String phrase, {
    String? dedupeKey,
    double rate = 1.0,
  });

  /// Stop any currently active speech.
  Future<void> stopSpeech();

  /// Start foreground/in-app monitoring for upcoming schedule and task events.
  void startScheduleMonitoring(
    Future<List<ScheduleActivity>> Function() getTodayActivities, {
    Future<List<dynamic>> Function()? getTasks,
  });

  /// Stop schedule monitoring.
  void stopScheduleMonitoring();
}
