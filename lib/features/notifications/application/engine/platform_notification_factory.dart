import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/notifications/application/alarm_scheduler_service.dart';
import 'package:timora/features/notifications/application/notification_service.dart';
import 'package:timora/features/notifications/application/voice_announcement_service.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'android_notification_engine.dart';
import 'notification_engine.dart';
import 'web_notification_engine.dart';

/// Centralized platform factory for NotificationEngine.
/// Returns WebNotificationEngine on Web and AndroidNotificationEngine on Android/native.
final notificationEngineProvider = Provider<NotificationEngine>((ref) {
  if (kIsWeb) {
    NotificationSettingsRepository? settingsRepo;
    try {
      settingsRepo = ref.watch(notificationSettingsRepositoryProvider);
    } catch (_) {}
    return WebNotificationEngine(settingsRepo: settingsRepo);
  } else {
    return AndroidNotificationEngine(
      notificationService: ref.watch(notificationServiceProvider),
      alarmSchedulerService: ref.watch(alarmSchedulerServiceProvider),
      voiceAnnouncementService: ref.watch(voiceAnnouncementServiceProvider),
    );
  }
});
