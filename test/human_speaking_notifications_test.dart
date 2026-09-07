import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/services/audio_mode_service.dart';
import 'package:timora/features/notifications/application/notification_message_generator.dart';
import 'package:timora/features/notifications/application/voice_announcement_service.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';

class _FakeAudioModeService extends AudioModeService {
  AudioMode fakeMode = AudioMode.normal;

  @override
  Future<AudioMode> getCurrentMode() async => fakeMode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ttsCalls = <MethodCall>[];

  setUp(() {
    ttsCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall methodCall) async {
        ttsCalls.add(methodCall);
        if (methodCall.method == 'getVoices') {
          return [
            {'name': 'en-us-x-sfg#male_1-local', 'locale': 'en-US'},
            {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US'},
          ];
        }
        return 1;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('timora/alarm'),
      (MethodCall methodCall) async => null,
    );
  });

  group('1. Male & Female Voice Selection Settings Persistence', () {
    test('Default voice is female', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      expect(repo.voiceGender, 'female');
      expect(repo.isMaleVoice, isFalse);
    });

    test('Can switch to Male voice and persist across reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      await repo.setVoiceGender('male');
      expect(repo.voiceGender, 'male');
      expect(repo.isMaleVoice, isTrue);

      final reloaded = NotificationSettingsRepository(prefs);
      expect(reloaded.voiceGender, 'male');
      expect(reloaded.isMaleVoice, isTrue);
    });

    test('Can switch back to Female voice and persist across reload', () async {
      SharedPreferences.setMockInitialValues({'notificationVoiceGender': 'male'});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      expect(repo.isMaleVoice, isTrue);

      await repo.setVoiceGender('female');
      expect(repo.voiceGender, 'female');
      expect(repo.isMaleVoice, isFalse);

      final reloaded = NotificationSettingsRepository(prefs);
      expect(reloaded.voiceGender, 'female');
      expect(reloaded.isMaleVoice, isFalse);
    });

    test('Speaking speed can be set between 0.1x and 2.0x', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      await repo.setSpeakingSpeed(0.8);
      expect(repo.speakingSpeed, 0.8);

      await repo.setSpeakingSpeed(1.5);
      expect(repo.speakingSpeed, 1.5);
    });
  });

  group('2. Human-Like Notification Text Generation', () {
    test('Natural delivery example: Hey, your AI and Data Science study session starts at 9 AM.', () {
      final pair = NotificationMessageGenerator.generateStartMessage(
        activityName: 'AI and Data Science study',
        startTime: DateTime(2026, 1, 1, 9, 0),
        variationIndex: 0,
      );
      expect(pair.spokenMessage, 'Hey, your AI and Data Science study session starts at 9 AM.');
    });

    test('Raw Task: Complete Python Course -> Spoken: It\'s time to work on your Python course.', () {
      final pair = NotificationMessageGenerator.generateTaskStart(
        taskName: 'Complete Python Course',
        variationIndex: 0,
      );
      expect(pair.spokenMessage, "It's time to work on your Python course.");
    });

    test('Raw Task with prefix: Task: Complete Python Course -> Spoken: It\'s time to work on your Python course.', () {
      final pair = NotificationMessageGenerator.generateTaskStart(
        taskName: 'Task: Complete Python Course',
        variationIndex: 0,
      );
      expect(pair.spokenMessage, "It's time to work on your Python course.");
    });

    test('Raw Focus Session: 60 minutes -> Spoken: Your 60-minute focus session is starting now. Let\'s get started.', () {
      final pair = NotificationMessageGenerator.generateFocusSessionStart(
        durationMinutes: 60,
        variationIndex: 0,
      );
      expect(pair.spokenMessage, "Your 60-minute focus session is starting now. Let's get started.");
    });

    test('Raw Task missed -> Spoken: You missed your Python study session. Don\'t worry — Timora can help you reschedule it.', () {
      final pair = NotificationMessageGenerator.generateTaskMissed(
        taskName: 'Python study',
        variationIndex: 0,
      );
      expect(pair.spokenMessage, "You missed your Python study session. Don't worry — Timora can help you reschedule it.");
    });

    test('Raw Daily report ready -> Spoken: Your Timora daily report is ready. You can check how your day went.', () {
      final pair = NotificationMessageGenerator.generateReportReady(
        reportType: 'daily',
        variationIndex: 0,
      );
      expect(pair.spokenMessage, "Your Timora daily report is ready. You can check how your day went.");
    });

    test('Weekly report ready -> natural spoken wording', () {
      final pair = NotificationMessageGenerator.generateReportReady(
        reportType: 'weekly',
        variationIndex: 0,
      );
      expect(pair.spokenMessage, "Your Timora weekly report is ready. You can check how your week went.");
    });
  });

  group('3. Controlled Natural Variations', () {
    test('Activity start has varied, friendly phrasings', () {
      final v0 = NotificationMessageGenerator.generateStartMessage(
        activityName: 'Gym',
        variationIndex: 0,
      ).spokenMessage;
      final v1 = NotificationMessageGenerator.generateStartMessage(
        activityName: 'Gym',
        variationIndex: 1,
      ).spokenMessage;
      final v2 = NotificationMessageGenerator.generateStartMessage(
        activityName: 'Gym',
        variationIndex: 2,
      ).spokenMessage;

      expect(v0, isNotEmpty);
      expect(v1, isNotEmpty);
      expect(v2, isNotEmpty);
      expect(v1, isNot(equals(v0)));
    });

    test('Task start has natural variations', () {
      final v0 = NotificationMessageGenerator.generateTaskStart(
        taskName: 'Research Paper',
        variationIndex: 0,
      ).spokenMessage;
      final v1 = NotificationMessageGenerator.generateTaskStart(
        taskName: 'Research Paper',
        variationIndex: 1,
      ).spokenMessage;

      expect(v0, "Your Research Paper task starts now.");
      expect(v1, "It's time to work on your Research Paper.");
    });

    test('Pre-reminder variations', () {
      final v0 = NotificationMessageGenerator.generatePreReminder(
        activityName: 'Deep Work',
        minutesBefore: 10,
        variationIndex: 0,
      ).spokenMessage;
      final v1 = NotificationMessageGenerator.generatePreReminder(
        activityName: 'Deep Work',
        minutesBefore: 10,
        variationIndex: 1,
      ).spokenMessage;

      expect(v0, 'Your deep work session starts in 10 minutes. Get ready.');
      expect(v1, 'Hey, your deep work session starts in 10 minutes. Get ready.');
    });
  });

  group('4. Phone Sound Mode Behavior (Silent, Vibrate, Normal)', () {
    test('In Normal mode, speech is played', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final fakeAudio = _FakeAudioModeService()..fakeMode = AudioMode.normal;
      final service = VoiceAnnouncementService(repo, audioModeService: fakeAudio);

      final result = await service.speakNotification(title: 'Gym', body: 'Gym time');
      expect(result, isTrue);
    });

    test('In Silent mode, speech is muted (returns false)', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final fakeAudio = _FakeAudioModeService()..fakeMode = AudioMode.silent;
      final service = VoiceAnnouncementService(repo, audioModeService: fakeAudio);

      final result = await service.speakNotification(title: 'Gym', body: 'Gym time');
      expect(result, isFalse);
    });

    test('In Vibrate mode, speech is muted (returns false)', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final fakeAudio = _FakeAudioModeService()..fakeMode = AudioMode.vibrate;
      final service = VoiceAnnouncementService(repo, audioModeService: fakeAudio);

      final result = await service.speakNotification(title: 'Gym', body: 'Gym time');
      expect(result, isFalse);
    });
  });

  group('5. Voice Configuration & Context-Aware Speech API', () {
    test('Service speaks focus session start', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final service = VoiceAnnouncementService(repo);

      final result = await service.speakFocusSessionStart(durationMinutes: 60);
      expect(result, isTrue);
    });

    test('Service speaks task missed recovery', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final service = VoiceAnnouncementService(repo);

      final result = await service.speakTaskMissed(taskId: 'task_1', taskName: 'Python study');
      expect(result, isTrue);
    });

    test('Service speaks report ready', () async {
      SharedPreferences.setMockInitialValues({'spokenAnnouncementsEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final service = VoiceAnnouncementService(repo);

      final result = await service.speakReportReady(reportType: 'daily');
      expect(result, isTrue);
    });

    test('Sample announcement speaks human-like test phrase', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final service = VoiceAnnouncementService(repo);

      await service.speakSampleAnnouncement();
      // Should invoke speak with natural phrase
      final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
      expect(speakCalls, isNotEmpty);
      expect(speakCalls.last.arguments, 'Hey, your AI and Data Science study session starts at 9 AM.');
    });
  });
}
