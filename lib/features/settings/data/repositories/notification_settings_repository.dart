import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationSettingsRepositoryProvider = Provider<NotificationSettingsRepository>((ref) {
  throw UnimplementedError('NotificationSettingsRepository not initialized');
});

class NotificationSettingsRepository {
  final SharedPreferences _prefs;

  NotificationSettingsRepository(this._prefs);

  bool get notificationsEnabled => _prefs.getBool('notificationsEnabled') ?? true;
  Future<void> setNotificationsEnabled(bool value) => _prefs.setBool('notificationsEnabled', value);

  bool get activityStartingEnabled => _prefs.getBool('activityStartingEnabled') ?? true;
  Future<void> setActivityStartingEnabled(bool value) => _prefs.setBool('activityStartingEnabled', value);

  bool get activityStartedEnabled => _prefs.getBool('activityStartedEnabled') ?? true;
  Future<void> setActivityStartedEnabled(bool value) => _prefs.setBool('activityStartedEnabled', value);

  bool get activityEndingEnabled => _prefs.getBool('activityEndingEnabled') ?? true;
  Future<void> setActivityEndingEnabled(bool value) => _prefs.setBool('activityEndingEnabled', value);

  bool get nextActivityEnabled => _prefs.getBool('nextActivityEnabled') ?? false;
  Future<void> setNextActivityEnabled(bool value) => _prefs.setBool('nextActivityEnabled', value);

  bool get morningReminderEnabled => _prefs.getBool('morningReminderEnabled') ?? true;
  Future<void> setMorningReminderEnabled(bool value) => _prefs.setBool('morningReminderEnabled', value);

  bool get dailyPlanningEnabled => _prefs.getBool('dailyPlanningEnabled') ?? true;
  Future<void> setDailyPlanningEnabled(bool value) => _prefs.setBool('dailyPlanningEnabled', value);

  bool get dailyReviewEnabled => _prefs.getBool('dailyReviewEnabled') ?? true;
  Future<void> setDailyReviewEnabled(bool value) => _prefs.setBool('dailyReviewEnabled', value);

  int get defaultReminderMinutes => _prefs.getInt('defaultReminderMinutes') ?? 10;
  Future<void> setDefaultReminderMinutes(int value) => _prefs.setInt('defaultReminderMinutes', value);

  TimeOfDay get morningReminderTime {
    final mins = _prefs.getInt('morningReminderTimeMins') ?? 480; // 8:00 AM
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }
  Future<void> setMorningReminderTime(TimeOfDay value) => _prefs.setInt('morningReminderTimeMins', value.hour * 60 + value.minute);

  TimeOfDay get dailyPlanningTime {
    final mins = _prefs.getInt('dailyPlanningTimeMins') ?? 1305; // 9:45 PM / 21:45
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }
  Future<void> setDailyPlanningTime(TimeOfDay value) => _prefs.setInt('dailyPlanningTimeMins', value.hour * 60 + value.minute);

  TimeOfDay get dailyReviewTime {
    final mins = _prefs.getInt('dailyReviewTimeMins') ?? 1380; // 11:00 PM
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }
  Future<void> setDailyReviewTime(TimeOfDay value) => _prefs.setInt('dailyReviewTimeMins', value.hour * 60 + value.minute);

  bool get quietHoursEnabled => _prefs.getBool('quietHoursEnabled') ?? true;
  Future<void> setQuietHoursEnabled(bool value) => _prefs.setBool('quietHoursEnabled', value);

  TimeOfDay get quietHoursStart {
    final mins = _prefs.getInt('quietHoursStartMins') ?? 1320; // 10:00 PM
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }
  Future<void> setQuietHoursStart(TimeOfDay value) => _prefs.setInt('quietHoursStartMins', value.hour * 60 + value.minute);

  TimeOfDay get quietHoursEnd {
    final mins = _prefs.getInt('quietHoursEndMins') ?? 480; // 8:00 AM
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }
  Future<void> setQuietHoursEnd(TimeOfDay value) => _prefs.setInt('quietHoursEndMins', value.hour * 60 + value.minute);

  Future<void> setQuietHours(TimeOfDay start, TimeOfDay end) async {
    await setQuietHoursStart(start);
    await setQuietHoursEnd(end);
  }

  bool get soundEnabled => _prefs.getBool('soundEnabled') ?? true;
  Future<void> setSoundEnabled(bool value) => _prefs.setBool('soundEnabled', value);

  bool get vibrationEnabled => _prefs.getBool('vibrationEnabled') ?? true;
  Future<void> setVibrationEnabled(bool value) => _prefs.setBool('vibrationEnabled', value);

  bool get spokenAnnouncementsEnabled => _prefs.getBool('spokenAnnouncementsEnabled') ?? true;
  Future<void> setSpokenAnnouncementsEnabled(bool value) => _prefs.setBool('spokenAnnouncementsEnabled', value);

  double get speakingSpeed => _prefs.getDouble('speakingSpeed') ?? 1.0;
  Future<void> setSpeakingSpeed(double value) => _prefs.setDouble('speakingSpeed', value.clamp(0.1, 2.0));

  String get voiceGender => _prefs.getString('notificationVoiceGender') ?? 'female';
  Future<void> setVoiceGender(String value) => _prefs.setString('notificationVoiceGender', value);
  bool get isMaleVoice => voiceGender == 'male';
}

