import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/shared_prefs_provider.dart';

final notificationSettingsRepositoryProvider = Provider<NotificationSettingsRepository>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return NotificationSettingsRepository(prefs);
  } catch (_) {
    throw UnimplementedError('NotificationSettingsRepository not initialized');
  }
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

  double get speakingVolume => _prefs.getDouble('speakingNotificationVolume') ?? 1.0;
  Future<void> setSpeakingVolume(double value) => _prefs.setDouble('speakingNotificationVolume', value.clamp(0.0, 1.0));

  // ---------------------------------------------------------------------------
  // AI MORNING BRIEF & DAILY DEBRIEF PREFERENCES
  // ---------------------------------------------------------------------------

  bool get morningBriefEnabled => _prefs.getBool('morningBriefEnabled') ?? true;
  Future<void> setMorningBriefEnabled(bool value) => _prefs.setBool('morningBriefEnabled', value);

  TimeOfDay get morningBriefTime {
    final mins = _prefs.getInt('morningBriefTimeMins') ?? 480; // 8:00 AM
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }
  Future<void> setMorningBriefTime(TimeOfDay value) =>
      _prefs.setInt('morningBriefTimeMins', value.hour * 60 + value.minute);

  String get morningBriefVoiceGender => _prefs.getString('morningBriefVoiceGender') ?? voiceGender;
  Future<void> setMorningBriefVoiceGender(String value) =>
      _prefs.setString('morningBriefVoiceGender', value);

  String get morningBriefDuration => _prefs.getString('morningBriefDuration') ?? 'normal';
  Future<void> setMorningBriefDuration(String value) =>
      _prefs.setString('morningBriefDuration', value);

  bool get morningBriefAutoPlay => _prefs.getBool('morningBriefAutoPlay') ?? true;
  Future<void> setMorningBriefAutoPlay(bool value) =>
      _prefs.setBool('morningBriefAutoPlay', value);

  bool get dailyDebriefEnabled => _prefs.getBool('dailyDebriefEnabled') ?? true;
  Future<void> setDailyDebriefEnabled(bool value) =>
      _prefs.setBool('dailyDebriefEnabled', value);

  TimeOfDay get dailyDebriefTime {
    final mins = _prefs.getInt('dailyDebriefTimeMins') ?? 1290; // 9:30 PM
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }
  Future<void> setDailyDebriefTime(TimeOfDay value) =>
      _prefs.setInt('dailyDebriefTimeMins', value.hour * 60 + value.minute);

  // ---------------------------------------------------------------------------
  // AI DAILY / WEEKLY / MONTHLY RECAP SCHEDULING PREFERENCES
  // ---------------------------------------------------------------------------

  bool get dailyRecapEnabled => _prefs.getBool('dailyRecapEnabled') ?? dailyReviewEnabled;
  Future<void> setDailyRecapEnabled(bool value) async {
    await _prefs.setBool('dailyRecapEnabled', value);
    await setDailyReviewEnabled(value);
  }

  TimeOfDay get dailyRecapTime => dailyReviewTime;
  Future<void> setDailyRecapTime(TimeOfDay value) => setDailyReviewTime(value);

  bool get weeklyRecapEnabled => _prefs.getBool('weeklyRecapEnabled') ?? true;
  Future<void> setWeeklyRecapEnabled(bool value) => _prefs.setBool('weeklyRecapEnabled', value);

  int get weeklyRecapWeekday => _prefs.getInt('weeklyRecapWeekday') ?? DateTime.sunday;
  Future<void> setWeeklyRecapWeekday(int value) => _prefs.setInt('weeklyRecapWeekday', value);

  TimeOfDay get weeklyRecapTime {
    final mins = _prefs.getInt('weeklyRecapTimeMins') ?? 1380; // 11:00 PM
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }
  Future<void> setWeeklyRecapTime(TimeOfDay value) =>
      _prefs.setInt('weeklyRecapTimeMins', value.hour * 60 + value.minute);

  bool get monthlyRecapEnabled => _prefs.getBool('monthlyRecapEnabled') ?? true;
  Future<void> setMonthlyRecapEnabled(bool value) => _prefs.setBool('monthlyRecapEnabled', value);

  TimeOfDay get monthlyRecapTime {
    final mins = _prefs.getInt('monthlyRecapTimeMins') ?? 1380; // 11:00 PM
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }
  Future<void> setMonthlyRecapTime(TimeOfDay value) =>
      _prefs.setInt('monthlyRecapTimeMins', value.hour * 60 + value.minute);
}

