import 'package:timora/features/notifications/application/alarm_scheduler_service.dart';
import 'package:timora/features/notifications/application/notification_service.dart';
import 'package:timora/features/notifications/application/voice_announcement_service.dart';
import 'package:timora/features/notifications/domain/models/notification_event.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'notification_engine.dart';

/// AndroidNotificationEngine — Preserves 100% of existing Android AlarmManager,
/// native Android TextToSpeech, and flutter_local_notifications implementations.
class AndroidNotificationEngine implements NotificationEngine {
  final NotificationService _notificationService;
  final AlarmSchedulerService _alarmSchedulerService;
  final VoiceAnnouncementService _voiceAnnouncementService;

  AndroidNotificationEngine({
    required NotificationService notificationService,
    required AlarmSchedulerService alarmSchedulerService,
    required VoiceAnnouncementService voiceAnnouncementService,
  })  : _notificationService = notificationService,
        _alarmSchedulerService = alarmSchedulerService,
        _voiceAnnouncementService = voiceAnnouncementService;

  @override
  Future<void> initialize() async {
    await _notificationService.initialize();
  }

  @override
  Future<bool> requestPermission() async {
    return await _notificationService.requestPermission();
  }

  @override
  Future<bool> getPermissionStatus() async {
    return await _notificationService.getNotificationPermissionStatus();
  }

  @override
  Future<void> syncEvents(List<NotificationEvent> events) async {
    await _alarmSchedulerService.syncEvents(events);
  }

  @override
  Future<void> cancelEventsBySource(String sourceId) async {
    await _alarmSchedulerService.cancelEventsBySource(sourceId);
  }

  @override
  Future<void> cancelById(int numericId) async {
    await _alarmSchedulerService.cancelById(numericId);
    await _notificationService.cancelNotification(numericId);
  }

  @override
  Future<void> cancelAll() async {
    await _alarmSchedulerService.cancelAllAlarms();
    await _notificationService.cancelAllNotifications();
  }

  @override
  Future<void> showImmediateNotification(
    int id,
    String title,
    String body, {
    String? payload,
    bool playSound = true,
  }) async {
    await _notificationService.showImmediateNotification(
      id,
      title,
      body,
      payload: payload,
      playSound: playSound,
    );
  }

  @override
  Future<bool> speak(
    String phrase, {
    String? dedupeKey,
    double rate = 1.0,
  }) async {
    return await _voiceAnnouncementService.speakNotification(
      title: 'Timora',
      body: phrase,
      notificationId: dedupeKey,
    );
  }

  @override
  Future<void> stopSpeech() async {
    await _voiceAnnouncementService.stop();
  }

  @override
  void startScheduleMonitoring(
    Future<List<ScheduleActivity>> Function() getTodayActivities, {
    Future<List<dynamic>> Function()? getTasks,
  }) {
    _voiceAnnouncementService.startScheduleMonitoring(
      getTodayActivities,
      getTasks: getTasks,
    );
  }

  @override
  void stopScheduleMonitoring() {
    _voiceAnnouncementService.stopScheduleMonitoring();
  }
}
