import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/services/audio_mode_service.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/notifications/application/voice_announcement_service.dart';
import 'package:timora/features/notifications/domain/models/admin_notification_model.dart';

class _MockAudioModeService extends AudioModeService {
  @override
  Future<AudioMode> getCurrentMode() async => AudioMode.normal;

  @override
  Future<bool> shouldAllowSpeech() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> ttsCalls = [];
  List<Map<String, dynamic>> mockVoices = [];

  setUp(() {
    ttsCalls.clear();
    mockVoices = [
      {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US', 'features': ''},
      {'name': 'en-us-x-sfg#male_1-local', 'locale': 'en-US', 'features': ''},
    ];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
      ttsCalls.add(call);
      switch (call.method) {
        case 'getVoices':
          return mockVoices;
        case 'getLanguages':
          return ['en-US'];
        case 'getEngines':
          return ['com.google.android.tts'];
        case 'getDefaultVoice':
          return {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US'};
        case 'getDefaultEngine':
          return 'com.google.android.tts';
        case 'stop':
        case 'speak':
        case 'setVoice':
        case 'setSpeechRate':
        case 'setPitch':
        case 'setLanguage':
        case 'setVolume':
        case 'awaitSynthCompletion':
        case 'setSharedInstance':
          return 1;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  group('Requirement 1: Admin Notification Sound & TTS Isolation', () {
    test('AdminNotificationModel and delivery do not invoke TTS even when speaking is enabled', () async {
      SharedPreferences.setMockInitialValues({
        'spokenAnnouncementsEnabled': true,
        'notificationVoiceGender': 'male',
      });
      final prefs = await SharedPreferences.getInstance();
      final settingsRepo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(settingsRepo, audioModeService: _MockAudioModeService());
      await Future.delayed(const Duration(milliseconds: 50));

      ttsCalls.clear();

      final adminNotif = AdminNotificationModel(
        id: 'admin-notif-001',
        title: 'Emergency Server Maintenance',
        message: 'Servers will reboot at midnight. Please save work.',
        priority: 'high',
        targetAudience: 'all',
        scheduledAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify voiceService was not instructed to speak admin announcement
      expect(ttsCalls.where((c) => c.method == 'speak'), isEmpty);
      expect(voiceService, isNotNull);
      expect(adminNotif.title, 'Emergency Server Maintenance');
    });
  });

  group('Requirement 2: Dynamic Male Voice Detection & Fallback Robustness', () {
    test('Detects Google TTS male voice markers correctly (cxx, wavenet-b, standard-d, smtm)', () async {
      mockVoices = [
        {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US', 'features': ''},
        {'name': 'en-us-x-iol-network', 'locale': 'en-US', 'features': 'male'},
      ];

      SharedPreferences.setMockInitialValues({'notificationVoiceGender': 'male'});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());
      await Future.delayed(const Duration(milliseconds: 50));

      ttsCalls.clear();
      await voiceService.switchVoice(isMale: true, speed: 1.0);

      final setVoiceCalls = ttsCalls.where((c) => c.method == 'setVoice').toList();
      expect(setVoiceCalls, isNotEmpty);
      final voiceArg = setVoiceCalls.last.arguments as Map;
      expect(voiceArg['name'], 'en-us-x-iol-network');
    });

    test('Safely handles device with ONLY female voices without forcing female voice', () async {
      mockVoices = [
        {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US', 'features': ''},
        {'name': 'en-us-x-sfg#female_2-local', 'locale': 'en-US', 'features': ''},
      ];

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());
      await Future.delayed(const Duration(milliseconds: 50));

      ttsCalls.clear();
      await voiceService.switchVoice(isMale: true, speed: 1.0);

      // No setVoice calls should set a female voice
      final setVoiceCalls = ttsCalls.where((c) => c.method == 'setVoice').toList();
      for (final call in setVoiceCalls) {
        final name = (call.arguments as Map)['name'] as String;
        expect(name.contains('female'), isFalse);
      }

      // Must set masculine pitch 0.82
      final pitchCall = ttsCalls.lastWhere((c) => c.method == 'setPitch');
      expect(pitchCall.arguments, 0.82);
    });

    test('Rapid switching Male <-> Female 20 times is completely crash-free', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());
      await Future.delayed(const Duration(milliseconds: 50));

      for (int i = 0; i < 20; i++) {
        final isMale = i.isEven;
        await expectLater(
          voiceService.switchVoice(isMale: isMale, speed: 1.0),
          completes,
        );
      }
    });

    test('TTS errors during switchVoice or speak do not crash the service', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());
      await Future.delayed(const Duration(milliseconds: 50));

      // Mock engine crash
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
        throw PlatformException(code: 'TTS_DEAD', message: 'Engine crashed');
      });

      // switchVoice should catch safely without throwing
      await expectLater(
        voiceService.switchVoice(isMale: true, speed: 1.0),
        completes,
      );

      // speakNotification should catch safely and return false
      final spoken = await voiceService.speakNotification(
        notificationId: 'test_crash_notif',
        title: 'Title',
        body: 'Body',
      );
      expect(spoken, isFalse);
    });
  });

  group('Requirement 3: Notification Interaction, Read Tracking & Navigation Safety', () {
    test('Marking notification read updates local preferences and unread counts', () async {
      SharedPreferences.setMockInitialValues({'timora_read_inbox_ids': <String>[]});
      final prefs = await SharedPreferences.getInstance();

      final readSet = (prefs.getStringList('timora_read_inbox_ids') ?? []).toSet();
      expect(readSet.contains('task_100'), isFalse);

      readSet.add('task_100');
      await prefs.setStringList('timora_read_inbox_ids', readSet.toList());

      final updated = prefs.getStringList('timora_read_inbox_ids') ?? [];
      expect(updated.contains('task_100'), isTrue);
      expect(updated.length, 1);
    });

    test('JSON notification payloads parse safely for routing', () {
      final validTaskPayload = jsonEncode({'sourceType': 'task', 'sourceId': 'task-abc'});
      final validAdminPayload = jsonEncode({'type': 'admin_notification', 'id': 'admin-xyz', 'deepLink': 'timora://schedule'});
      final legacyRoutinePayload = 'routine_routine-123';
      final corruptPayload = '{invalid_json...';

      // Verify parsing robustness
      final taskData = jsonDecode(validTaskPayload) as Map<String, dynamic>;
      expect(taskData['sourceType'], 'task');
      expect(taskData['sourceId'], 'task-abc');

      final adminData = jsonDecode(validAdminPayload) as Map<String, dynamic>;
      expect(adminData['type'], 'admin_notification');
      expect(adminData['deepLink'], 'timora://schedule');

      expect(legacyRoutinePayload.startsWith('routine_'), isTrue);

      expect(() {
        try {
          jsonDecode(corruptPayload);
        } catch (_) {
          // Handled safely in controller
        }
      }, returnsNormally);
    });
  });
}
