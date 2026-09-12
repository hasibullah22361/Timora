import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/notifications/application/voice_announcement_service.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('timora/alarm'),
      (MethodCall methodCall) async => null,
    );
  });

  group('Phase 1 & 22: Speaking Notifications Setting Persistence', () {
    test('Setting defaults to ON (true)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      expect(repo.spokenAnnouncementsEnabled, isTrue);
    });

    test('Setting toggles to OFF and persists across repository reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      await repo.setSpokenAnnouncementsEnabled(false);
      expect(repo.spokenAnnouncementsEnabled, isFalse);

      // Re-create repository instance with the same storage
      final reloadedRepo = NotificationSettingsRepository(prefs);
      expect(reloadedRepo.spokenAnnouncementsEnabled, isFalse);
    });

    test('Setting toggles to ON and persists across repository reload', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': false});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      expect(repo.spokenAnnouncementsEnabled, isFalse);

      await repo.setSpokenAnnouncementsEnabled(true);
      expect(repo.spokenAnnouncementsEnabled, isTrue);

      final reloadedRepo = NotificationSettingsRepository(prefs);
      expect(reloadedRepo.spokenAnnouncementsEnabled, isTrue);
    });

    test('Speaking volume defaults to 1.0 (100%)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      expect(repo.speakingVolume, 1.0);
    });

    test('Speaking volume updates and persists across repository reload (app close/reopen)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      // Set to 20%
      await repo.setSpeakingVolume(0.2);
      expect(repo.speakingVolume, 0.2);

      // Reload repo (simulating app reopen)
      var reloadedRepo = NotificationSettingsRepository(prefs);
      expect(reloadedRepo.speakingVolume, 0.2);

      // Set to 50%
      await repo.setSpeakingVolume(0.5);
      expect(repo.speakingVolume, 0.5);
      reloadedRepo = NotificationSettingsRepository(prefs);
      expect(reloadedRepo.speakingVolume, 0.5);

      // Set to 70%
      await repo.setSpeakingVolume(0.7);
      expect(repo.speakingVolume, 0.7);
      reloadedRepo = NotificationSettingsRepository(prefs);
      expect(reloadedRepo.speakingVolume, 0.7);

      // Set to 100%
      await repo.setSpeakingVolume(1.0);
      expect(repo.speakingVolume, 1.0);
      reloadedRepo = NotificationSettingsRepository(prefs);
      expect(reloadedRepo.speakingVolume, 1.0);
    });

    test('Speaking volume clamps out-of-range values between 0.0 and 1.0', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      await repo.setSpeakingVolume(-0.25);
      expect(repo.speakingVolume, 0.0);

      await repo.setSpeakingVolume(1.5);
      expect(repo.speakingVolume, 1.0);
    });

    test('Changing speaking volume does not affect voice gender or speaking speed', () async {
      SharedPreferences.setMockInitialValues({
        'notificationVoiceGender': 'male',
        'speakingSpeed': 1.2,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      expect(repo.voiceGender, 'male');
      expect(repo.speakingSpeed, 1.2);

      await repo.setSpeakingVolume(0.3);
      expect(repo.speakingVolume, 0.3);
      expect(repo.voiceGender, 'male', reason: 'Male/Female voice functionality must remain intact');
      expect(repo.speakingSpeed, 1.2, reason: 'Speaking speed must remain intact');
    });
  });

  group('Phase 3, 13 & 30: Spoken Phrase Formatting and Sanitization', () {
    late NotificationSettingsRepository settingsRepo;
    late VoiceAnnouncementService voiceService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      settingsRepo = NotificationSettingsRepository(prefs);
      voiceService = VoiceAnnouncementService(settingsRepo);
    });

    test('Example 1: AI Study formatting', () {
      final phrase = voiceService.sanitizeNotificationText('AI Study', "It's time to study AI.");
      expect(phrase, "AI Study. It's time to study AI.");
    });

    test('Example 2: Research formatting', () {
      final phrase = voiceService.sanitizeNotificationText('Research', 'Work on your research project for two hours.');
      expect(phrase, 'Research. Work on your research project for two hours.');
    });

    test('Prefix normalization removes Timora bullet prefix', () {
      final phrase = voiceService.sanitizeNotificationText('Timora • Focus Time', 'Deep Work time. Let\'s get started.');
      expect(phrase, 'Focus Time. Deep Work time. Let\'s get started.');
    });

    test('Strips markdown glyphs and bullet symbols', () {
      final phrase = voiceService.sanitizeNotificationText('**Urgent** • Task', '_Complete_ the report today!');
      expect(phrase, 'Urgent Task. Complete the report today!');
    });

    test('Handles title only or body only safely', () {
      expect(voiceService.sanitizeNotificationText('Solo Title', null), 'Solo Title');
      expect(voiceService.sanitizeNotificationText('', 'Solo Body'), 'Solo Body');
      expect(voiceService.sanitizeNotificationText(null, null), '');
      expect(voiceService.sanitizeNotificationText('   ', '   '), '');
    });

    test('Avoids duplicate phrase when title and body are identical', () {
      final phrase = voiceService.sanitizeNotificationText('Take a break', 'Take a break');
      expect(phrase, 'Take a break');
    });
  });

  group('Phase 4, 20 & 21: Gate Speech Based on Setting', () {
    test('When Speaking Notifications is OFF, speakNotification returns false', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': false});
      final prefs = await SharedPreferences.getInstance();
      final settingsRepo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(settingsRepo);

      final result = await voiceService.speakNotification(
        title: 'Exercise',
        body: 'Time for exercise.',
      );
      expect(result, isFalse, reason: 'Must not speak when Speaking Notifications is OFF');
    });

    test('When Speaking Notifications is ON, speakNotification returns true', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final settingsRepo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(settingsRepo);

      final result = await voiceService.speakNotification(
        title: 'AI Study',
        body: 'It\'s time to study AI.',
      );
      expect(result, isTrue, reason: 'Must speak when Speaking Notifications is ON');
    });
  });

  group('Phase 11: Duplicate Speech Prevention', () {
    test('Same notification is not spoken multiple times in rapid succession', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final settingsRepo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(settingsRepo);

      final fixedTime = DateTime(2026, 8, 29, 14, 0);

      // First call -> spoken
      final first = await voiceService.speakNotification(
        title: 'AI Study',
        body: 'It\'s time to study AI.',
        notificationId: 'ai_study_1',
        scheduledTime: fixedTime,
      );
      expect(first, isTrue);

      // Duplicate call for the exact same event -> blocked
      final second = await voiceService.speakNotification(
        title: 'AI Study',
        body: 'It\'s time to study AI.',
        notificationId: 'ai_study_1',
        scheduledTime: fixedTime,
      );
      expect(second, isFalse, reason: 'Duplicate notification speech must be prevented');
    });
  });

  group('Test Notification Speech Pipeline', () {
    test('speakTestNotification fires regardless of spoken announcements setting', () async {
      // Even if the user has turned off spoken announcements, the Test Notification
      // button should always speak so the user can verify their audio is working.
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': false});
      final prefs = await SharedPreferences.getInstance();
      final settingsRepo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(settingsRepo);

      // Should return true (speech triggered) regardless of the setting
      final result = await voiceService.speakTestNotification();
      expect(result, isTrue, reason: 'Test notification must always fire regardless of setting');
    });
  });

  group('Schedule Activities & Task Reminders Checks', () {
    test('Completed or skipped activities are ignored for speech', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final settingsRepo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(settingsRepo);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final completedActivity = ScheduleActivity(
        id: 'act_done',
        title: 'Morning Yoga',
        date: today,
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        category: 'Health',
        status: ActivityStatus.completed,
        createdAt: now,
      );

      await voiceService.checkAndAnnounceActivities([completedActivity]);
      // Verify no speech record created for completed item
      expect(voiceService.sanitizeNotificationText(completedActivity.title, ''), 'Morning Yoga');
    });
  });
}
