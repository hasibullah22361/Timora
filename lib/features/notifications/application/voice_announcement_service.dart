import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:timora/core/services/audio_mode_service.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';

final voiceAnnouncementServiceProvider = Provider<VoiceAnnouncementService>((ref) {
  try {
    final repo = ref.watch(notificationSettingsRepositoryProvider);
    final audioMode = ref.watch(audioModeServiceProvider);
    return VoiceAnnouncementService(repo, audioModeService: audioMode);
  } catch (_) {
    return VoiceAnnouncementService(null);
  }
});

class VoiceAnnouncementService {
  final NotificationSettingsRepository? _settingsRepo;
  final FlutterTts _flutterTts;
  final AudioModeService _audioModeService;
  final Map<String, DateTime> _spokenOccurrences = {};
  bool _isInitialized = false;
  Timer? _activeMonitorTimer;
  Completer<void>? _currentSpeechCompleter;

  VoiceAnnouncementService(
    this._settingsRepo, {
    FlutterTts? flutterTts,
    AudioModeService? audioModeService,
  })  : _flutterTts = flutterTts ?? FlutterTts(),
        _audioModeService = audioModeService ?? AudioModeService() {
    _initTts();
  }

  bool get _spokenEnabled => _settingsRepo?.spokenAnnouncementsEnabled ?? true;

  Future<void> _initTts() async {
    if (_isInitialized) return;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _flutterTts.setSpeechRate(0.5);
        await _flutterTts.setVolume(1.0);
        await _flutterTts.setPitch(1.0);

        try {
          await _flutterTts.setLanguage('en-US');
        } catch (_) {
          // Fallback to default system language if en-US is not available
        }

        if (Platform.isIOS) {
          await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
              IosTextToSpeechAudioCategoryOptions.duckOthers,
            ],
          );
        }

        _flutterTts.setCompletionHandler(() {
          if (_currentSpeechCompleter != null &&
              !_currentSpeechCompleter!.isCompleted) {
            _currentSpeechCompleter!.complete();
          }
        });

        _flutterTts.setErrorHandler((dynamic msg) {
          debugPrint('[TimoraTTS] Error: $msg');
          if (_currentSpeechCompleter != null &&
              !_currentSpeechCompleter!.isCompleted) {
            _currentSpeechCompleter!.complete();
          }
        });
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[TimoraTTS] Initialization error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEXT SANITIZATION
  // ─────────────────────────────────────────────────────────────────────────

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'[*#_`~]'), '') // Strip markdown formatting
        .replaceAll(RegExp(r'[•►▪■]'), '') // Strip bullet glyphs
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse multiple whitespace
        .trim();
  }

  /// Sanitizes notification title and body text into clear, natural spoken text.
  String sanitizeNotificationText(String? title, String? body) {
    String rawTitle = (title ?? '').trim();
    // Strip leading "Timora • " or "Timora - " or "Timora: " prefix
    rawTitle = rawTitle.replaceFirst(
        RegExp(r'^Timora\s*[•►▪■\-:]?\s*', caseSensitive: false), '');

    String cleanTitle = _cleanText(rawTitle);
    String cleanBody = _cleanText(body ?? '');

    if (cleanTitle.isEmpty && cleanBody.isEmpty) return '';
    if (cleanTitle.isEmpty) return cleanBody;
    if (cleanBody.isEmpty) return cleanTitle;

    if (cleanTitle.toLowerCase() == cleanBody.toLowerCase()) return cleanTitle;
    if (cleanBody.toLowerCase().startsWith(cleanTitle.toLowerCase())) {
      return cleanBody;
    }

    if (!cleanTitle.endsWith('.') &&
        !cleanTitle.endsWith('!') &&
        !cleanTitle.endsWith('?')) {
      cleanTitle = '$cleanTitle.';
    }
    return '$cleanTitle $cleanBody';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DYNAMIC PHRASE BUILDERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds the canonical spoken phrase for an activity start.
  /// Converts name to lowercase and appends " time" if not already ending with it.
  /// Example: 'Gym' → 'Your gym time starts now.'
  ///          'Focus Time' → 'Your focus time starts now.'
  String buildAnnouncementPhrase(String activityName) {
    final clean = _cleanText(activityName);
    if (clean.isEmpty) return 'Your scheduled activity starts now.';
    final lower = clean.toLowerCase();
    if (lower.endsWith('time')) {
      return 'Your $lower starts now.';
    }
    return 'Your $lower time starts now.';
  }

  /// Generic activity start phrase — used for schedule and routine.
  String _phraseActivityStart(String name) {
    return buildAnnouncementPhrase(name);
  }

  /// Task start / reminder phrase.
  String _phraseTaskStart(String name) {
    final clean = _cleanText(name);
    if (clean.isEmpty) return 'Your task starts now.';
    return 'Your $clean task starts now.';
  }

  /// Task completed phrase.
  String _phraseTaskCompleted(String name) {
    final clean = _cleanText(name);
    if (clean.isEmpty) return 'Task completed. Well done.';
    return '$clean completed. Well done.';
  }

  /// Schedule / activity completed phrase.
  String _phraseActivityCompleted(String name) {
    final clean = _cleanText(name);
    if (clean.isEmpty) return 'Activity completed.';
    return '$clean completed.';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CORE SPEAK ENGINE
  // ─────────────────────────────────────────────────────────────────────────

  /// Internal low-level speak — respects setting check, dedup, and logging.
  Future<bool> _speak(
    String phrase, {
    required String dedupeKey,
    bool respectSetting = true,
  }) async {
    if (respectSetting && !_spokenEnabled) {
      return false;
    }
    if (phrase.isEmpty) return false;

    // Duplicate speech prevention
    final now = DateTime.now();
    _spokenOccurrences.removeWhere((_, t) => now.difference(t).inMinutes > 5);
    if (_spokenOccurrences.containsKey(dedupeKey)) {
      final last = _spokenOccurrences[dedupeKey]!;
      if (now.difference(last).inSeconds < 60) {
        debugPrint('[TimoraTTS] Skipping duplicate: "$dedupeKey"');
        return false;
      }
    }
    _spokenOccurrences[dedupeKey] = now;

    // Smart Notification Audio (Phase 5): check phone ringer mode
    try {
      final audioMode = await _audioModeService.getCurrentMode();
      if (audioMode == AudioMode.silent) {
        debugPrint('[TimoraTTS] Phone in silent mode — speech muted');
        return false;
      } else if (audioMode == AudioMode.vibrate) {
        debugPrint('[TimoraTTS] Phone in vibrate mode — speech muted');
        return false;
      }
    } catch (e) {
      debugPrint('[TimoraTTS] Audio mode check error: $e');
    }

    try {
      await _initTts();
      // Apply speaking speed setting (Phase 6)
      final speed = _settingsRepo?.speakingSpeed ?? 1.0;
      final rate = (speed * 0.5).clamp(0.05, 1.0);
      await _flutterTts.setSpeechRate(rate);

      await _flutterTts.stop();
      _currentSpeechCompleter = Completer<void>();
      debugPrint('[TimoraTTS] Speaking (speed: ${speed}x, rate: $rate): "$phrase"');
      await _flutterTts.speak(phrase);
      return true;
    } catch (e) {
      debugPrint('[TimoraTTS] Error during speech: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC EVENT API — Centralized Timora Speaking Events
  // ─────────────────────────────────────────────────────────────────────────

  /// Task starts / reminder fires. Dynamic from task name.
  Future<bool> speakTaskStart({
    required String taskId,
    required String taskName,
    DateTime? scheduledTime,
  }) async {
    final phrase = _phraseTaskStart(taskName);
    final timeStamp = scheduledTime != null
        ? '${scheduledTime.hour.toString().padLeft(2, '0')}${scheduledTime.minute.toString().padLeft(2, '0')}'
        : DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('[TimoraTTS] Event type: task_start | Task: $taskName');
    return _speak(phrase, dedupeKey: 'task_start_${taskId}_$timeStamp');
  }

  /// Task completed. Dynamic from task name.
  Future<bool> speakTaskCompleted({required String taskId, required String taskName}) async {
    final phrase = _phraseTaskCompleted(taskName);
    debugPrint('[TimoraTTS] Event type: task_completed | Task: $taskName');
    return _speak(phrase, dedupeKey: 'task_done_$taskId');
  }

  /// Schedule/activity starts. Dynamic from activity name.
  Future<bool> speakScheduleStart({
    required String activityId,
    required String activityName,
    DateTime? scheduledTime,
  }) async {
    final phrase = _phraseActivityStart(activityName);
    final timeStamp = scheduledTime != null
        ? '${scheduledTime.hour.toString().padLeft(2, '0')}${scheduledTime.minute.toString().padLeft(2, '0')}'
        : DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('[TimoraTTS] Event type: schedule_start | Activity: $activityName');
    return _speak(phrase, dedupeKey: 'schedule_start_${activityId}_$timeStamp');
  }

  /// Schedule/activity completed. Dynamic from activity name.
  Future<bool> speakScheduleCompleted({required String activityId, required String activityName}) async {
    final phrase = _phraseActivityCompleted(activityName);
    debugPrint('[TimoraTTS] Event type: schedule_completed | Activity: $activityName');
    return _speak(phrase, dedupeKey: 'schedule_done_$activityId');
  }

  /// Routine block starts. Dynamic from block name.
  Future<bool> speakRoutineStart({
    required String blockId,
    required String blockName,
    DateTime? scheduledTime,
  }) async {
    final phrase = _phraseActivityStart(blockName);
    final timeStamp = scheduledTime != null
        ? '${scheduledTime.hour.toString().padLeft(2, '0')}${scheduledTime.minute.toString().padLeft(2, '0')}'
        : DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('[TimoraTTS] Event type: routine_start | Block: $blockName');
    return _speak(phrase, dedupeKey: 'routine_start_${blockId}_$timeStamp');
  }

  /// Test notification speech — exercises the same pipeline as real spoken events.
  /// Called by "Test Notification" button in settings.
  Future<bool> speakTestNotification() async {
    const phrase = 'This is a Timora notification test.';
    debugPrint('[TimoraTTS] Event type: test_notification');
    // respectSetting = false so this always fires for testing purposes
    return _speak(phrase, dedupeKey: 'test_${DateTime.now().millisecondsSinceEpoch}', respectSetting: false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEGACY / COMPATIBILITY API
  // ─────────────────────────────────────────────────────────────────────────

  /// Legacy method — kept for compatibility with ai_assistant_screen and notification_controller.
  Future<bool> speakNotification({
    required String? title,
    required String? body,
    String? notificationId,
    DateTime? scheduledTime,
  }) async {
    if (!_spokenEnabled) return false;

    final phrase = sanitizeNotificationText(title, body);
    if (phrase.isEmpty) return false;

    final now = DateTime.now();
    final targetTime = scheduledTime ?? now;
    final timeKey =
        '${targetTime.year}${targetTime.month.toString().padLeft(2, '0')}${targetTime.day.toString().padLeft(2, '0')}_${targetTime.hour.toString().padLeft(2, '0')}${targetTime.minute.toString().padLeft(2, '0')}';
    final uniqueKey = '${notificationId ?? phrase.hashCode}_$timeKey';

    debugPrint('[TimoraTTS] speakNotification: "$phrase"');
    return _speak(phrase, dedupeKey: uniqueKey, respectSetting: false);
  }

  /// Legacy — used by notification_controller for activity start announcements.
  Future<bool> announceActivityStart({
    required String activityId,
    required String activityName,
    DateTime? scheduledTime,
  }) async {
    return speakScheduleStart(
      activityId: activityId,
      activityName: activityName,
      scheduledTime: scheduledTime,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IN-APP SCHEDULE MONITORING (foreground / minimized)
  // ─────────────────────────────────────────────────────────────────────────

  /// Check a list of scheduled activities for current minute matches and announce.
  Future<void> checkAndAnnounceActivities(List<ScheduleActivity> activities) async {
    if (!_spokenEnabled) return;

    final now = DateTime.now();
    for (final act in activities) {
      if (act.status == ActivityStatus.completed ||
          act.status == ActivityStatus.skipped) {
        continue;
      }

      // Check if current time is within [startTime - 10s, startTime + 55s]
      final diff = now.difference(act.startTime);
      if (diff.inSeconds >= -10 && diff.inSeconds <= 55) {
        await speakScheduleStart(
          activityId: act.id,
          activityName: act.title,
          scheduledTime: act.startTime,
        );
      }
    }
  }

  /// Check a list of tasks with reminders for current minute matches and announce.
  Future<void> checkAndAnnounceTasks(List<dynamic> tasks) async {
    if (!_spokenEnabled) return;

    final now = DateTime.now();
    for (final task in tasks) {
      try {
        if (task.isCompleted == true || task.isDeleted == true) continue;
        if (task.reminderEnabled != true ||
            task.dueDate == null ||
            task.dueTime == null) {
          continue;
        }

        final dueDate = task.dueDate as DateTime;
        final dueTime = task.dueTime;
        final reminderMinutes = (task.reminderMinutesBefore as int?) ?? 0;

        final dueDateTime = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          dueTime.hour as int,
          dueTime.minute as int,
        );

        final reminderTime =
            dueDateTime.subtract(Duration(minutes: reminderMinutes));
        final diff = now.difference(reminderTime);

        if (diff.inSeconds >= -10 && diff.inSeconds <= 55) {
          debugPrint('[TimoraTTS] Task reminder firing: ${task.title}');
          await speakTaskStart(
            taskId: task.id.toString(),
            taskName: task.title.toString(),
            scheduledTime: reminderTime,
          );
        }
      } catch (_) {}
    }
  }

  /// Start periodic timer to monitor active schedule and task reminders.
  void startScheduleMonitoring(
    Future<List<ScheduleActivity>> Function() getTodayActivities, {
    Future<List<dynamic>> Function()? getTasks,
  }) {
    _activeMonitorTimer?.cancel();
    _activeMonitorTimer =
        Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        debugPrint('[TimoraBackground] Monitor tick');
        final activities = await getTodayActivities();
        await checkAndAnnounceActivities(activities);

        if (getTasks != null) {
          final tasks = await getTasks();
          await checkAndAnnounceTasks(tasks);
        }
      } catch (_) {}
    });
  }

  void stopScheduleMonitoring() {
    _activeMonitorTimer?.cancel();
    _activeMonitorTimer = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAMPLE / TEST (Test Voice button)
  // ─────────────────────────────────────────────────────────────────────────

  /// Manually speak a sample phrase (Test Voice button). Always fires regardless of setting.
  Future<void> speakSampleAnnouncement(String activityName) async {
    final phrase = _phraseActivityStart(activityName);
    try {
      await _initTts();
      final speed = _settingsRepo?.speakingSpeed ?? 1.0;
      final rate = (speed * 0.5).clamp(0.05, 1.0);
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.stop();
      debugPrint('[TimoraTTS] Test Voice (speed: ${speed}x, rate: $rate): "$phrase"');
      await _flutterTts.speak(phrase);
    } catch (e) {
      debugPrint('[TimoraTTS] Test Voice error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTROL
  // ─────────────────────────────────────────────────────────────────────────

  /// Stop any ongoing speech.
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
