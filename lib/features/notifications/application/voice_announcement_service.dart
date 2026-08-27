import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';

final voiceAnnouncementServiceProvider = Provider<VoiceAnnouncementService>((ref) {
  final repo = ref.watch(notificationSettingsRepositoryProvider);
  return VoiceAnnouncementService(repo);
});

class VoiceAnnouncementService {
  final NotificationSettingsRepository _settingsRepo;
  final FlutterTts _flutterTts = FlutterTts();
  final Set<String> _announcedOccurrences = {};
  bool _isInitialized = false;
  Timer? _activeMonitorTimer;

  VoiceAnnouncementService(this._settingsRepo) {
    _initTts();
  }

  Future<void> _initTts() async {
    if (_isInitialized) return;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _flutterTts.setSpeechRate(0.5);
        await _flutterTts.setVolume(1.0);
        await _flutterTts.setPitch(1.0);
        await _flutterTts.setLanguage('en-US');
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS Initialization notice: $e');
    }
  }

  /// Formats the spoken announcement dynamically from the activity name.
  /// Examples:
  /// - Study -> "Your study time starts now."
  /// - Breakfast -> "Your breakfast time starts now."
  /// - Gym -> "Your gym time starts now."
  /// - Work -> "Your work time starts now."
  /// - Prayer -> "Your prayer time starts now."
  /// - Meeting -> "Your meeting time starts now."
  String buildAnnouncementPhrase(String activityName) {
    final clean = activityName.trim();
    if (clean.isEmpty) {
      return 'Your scheduled activity starts now.';
    }
    
    final lower = clean.toLowerCase();
    if (lower.endsWith('time')) {
      return 'Your $lower starts now.';
    }
    return 'Your $lower time starts now.';
  }

  /// Speaks the dynamic activity announcement if voice announcements are enabled.
  Future<bool> announceActivityStart({
    required String activityId,
    required String activityName,
    DateTime? scheduledTime,
  }) async {
    if (!_settingsRepo.spokenAnnouncementsEnabled) {
      return false;
    }

    final targetTime = scheduledTime ?? DateTime.now();
    final dateKey = '${targetTime.year}-${targetTime.month.toString().padLeft(2, '0')}-${targetTime.day.toString().padLeft(2, '0')}_${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
    final uniqueKey = '${activityId}_$dateKey';

    // Prevent duplicate announcement for the exact same activity occurrence
    if (_announcedOccurrences.contains(uniqueKey)) {
      return false;
    }

    _announcedOccurrences.add(uniqueKey);

    final phrase = buildAnnouncementPhrase(activityName);
    
    try {
      await _initTts();
      await _flutterTts.stop();
      await _flutterTts.speak(phrase);
      debugPrint('Spoken Activity Announcement: "$phrase"');
      return true;
    } catch (e) {
      debugPrint('Voice announcement error: $e');
      return false;
    }
  }

  /// Check a list of scheduled activities for current minute matches and announce.
  Future<void> checkAndAnnounceActivities(List<ScheduleActivity> activities) async {
    if (!_settingsRepo.spokenAnnouncementsEnabled) return;

    final now = DateTime.now();
    for (final act in activities) {
      if (act.status == ActivityStatus.completed || act.status == ActivityStatus.skipped) {
        continue;
      }

      // Check if current time is within [startTime - 10s, startTime + 50s]
      final diff = now.difference(act.startTime);
      if (diff.inSeconds >= -10 && diff.inSeconds <= 55) {
        await announceActivityStart(
          activityId: act.id,
          activityName: act.title,
          scheduledTime: act.startTime,
        );
      }
    }
  }

  /// Start periodic background timer to monitor active schedule in foreground
  void startScheduleMonitoring(Future<List<ScheduleActivity>> Function() getTodayActivities) {
    _activeMonitorTimer?.cancel();
    _activeMonitorTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final activities = await getTodayActivities();
        await checkAndAnnounceActivities(activities);
      } catch (_) {}
    });
  }

  void stopScheduleMonitoring() {
    _activeMonitorTimer?.cancel();
    _activeMonitorTimer = null;
  }

  /// Manually speak a test phrase
  Future<void> speakSampleAnnouncement(String activityName) async {
    final phrase = buildAnnouncementPhrase(activityName);
    await _initTts();
    await _flutterTts.stop();
    await _flutterTts.speak(phrase);
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
