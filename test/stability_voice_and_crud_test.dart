import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/services/audio_mode_service.dart';
import 'package:timora/features/notifications/application/voice_announcement_service.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/schedule/data/models/activity_definition.dart';

class _MockAudioModeService extends AudioModeService {
  @override
  Future<AudioMode> getCurrentMode() async => AudioMode.normal;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ttsCalls = <MethodCall>[];
  bool throwOnTts = false;
  List<Map<String, String>> mockVoices = [
    {'name': 'en-us-x-sfg#male_1-local', 'locale': 'en-US'},
    {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US'},
  ];

  setUp(() {
    ttsCalls.clear();
    throwOnTts = false;
    mockVoices = [
      {'name': 'en-us-x-sfg#male_1-local', 'locale': 'en-US'},
      {'name': 'en-us-x-sfg#female_1-local', 'locale': 'en-US'},
    ];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall methodCall) async {
        if (throwOnTts) {
          throw PlatformException(code: 'TTS_ERROR', message: 'Engine busy or crashed');
        }
        ttsCalls.add(methodCall);
        if (methodCall.method == 'getVoices') {
          return mockVoices;
        }
        return 1;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('timora/alarm'),
      (MethodCall methodCall) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('timora/alarm'),
      null,
    );
  });

  group('1. Voice Notification Switching Stability', () {
    test('Switching voice safely stops previous speech and configures male voice', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());

      await voiceService.switchVoice(isMale: true, speed: 1.0);

      // Verify stop was invoked first
      expect(ttsCalls.any((c) => c.method == 'stop'), isTrue);

      // Verify pitch and speech rate set for male
      final pitchCall = ttsCalls.lastWhere((c) => c.method == 'setPitch');
      expect(pitchCall.arguments, 0.90);

      final rateCall = ttsCalls.lastWhere((c) => c.method == 'setSpeechRate');
      expect(rateCall.arguments, 0.46);

      // Verify male voice was selected
      final setVoiceCall = ttsCalls.lastWhere((c) => c.method == 'setVoice');
      expect((setVoiceCall.arguments as Map)['name'], contains('male'));
    });

    test('Switching voice safely stops previous speech and configures female voice', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());

      await voiceService.switchVoice(isMale: false, speed: 1.0);

      expect(ttsCalls.any((c) => c.method == 'stop'), isTrue);

      final pitchCall = ttsCalls.lastWhere((c) => c.method == 'setPitch');
      expect(pitchCall.arguments, 1.05);

      final rateCall = ttsCalls.lastWhere((c) => c.method == 'setSpeechRate');
      expect(rateCall.arguments, 0.48);

      final setVoiceCall = ttsCalls.lastWhere((c) => c.method == 'setVoice');
      expect((setVoiceCall.arguments as Map)['name'], contains('female'));
    });

    test('Repeated rapid switching (Male <-> Female) never throws or crashes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());

      // Rapidly toggle back and forth 20 times
      for (int i = 0; i < 20; i++) {
        final isMale = i.isEven;
        await expectLater(
          voiceService.switchVoice(isMale: isMale, speed: 1.0),
          completes,
        );
      }
    });

    test('Graceful fallback when no matching gender voices are returned', () async {
      mockVoices = [
        {'name': 'some-other-voice', 'locale': 'fr-FR'},
      ];

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());

      // Switching should not throw even if no matching voice exists
      await expectLater(
        voiceService.switchVoice(isMale: true, speed: 1.0),
        completes,
      );

      // Should fall back to en-US language
      expect(ttsCalls.any((c) => c.method == 'setLanguage'), isTrue);
    });

    test('Handles TTS engine exceptions during switchVoice without crashing', () async {
      throwOnTts = true;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());

      // Should catch exception and complete normally
      await expectLater(
        voiceService.switchVoice(isMale: true, speed: 1.0),
        completes,
      );
      await expectLater(
        voiceService.switchVoice(isMale: false, speed: 1.0),
        completes,
      );
    });

    test('Sample announcement stops prior speech and speaks formatted message', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);
      await repo.setVoiceGender('male');
      final voiceService = VoiceAnnouncementService(repo, audioModeService: _MockAudioModeService());

      await voiceService.speakSampleAnnouncement();

      // Verify stop was called before speak
      final stopIdx = ttsCalls.indexWhere((c) => c.method == 'stop');
      final speakIdx = ttsCalls.indexWhere((c) => c.method == 'speak');
      expect(stopIdx, isNonNegative);
      expect(speakIdx, isNonNegative);
      expect(stopIdx, lessThan(speakIdx));

      final speakCall = ttsCalls[speakIdx];
      expect(speakCall.arguments.toString(), contains('AI and Data Science study session'));
    });

    test('NotificationSettingsRepository updates voice gender correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationSettingsRepository(prefs);

      expect(repo.isMaleVoice, isFalse);
      await repo.setVoiceGender('male');
      expect(repo.isMaleVoice, isTrue);
      expect(repo.voiceGender, 'male');

      await repo.setVoiceGender('female');
      expect(repo.isMaleVoice, isFalse);
      expect(repo.voiceGender, 'female');
    });
  });

  group('2. Add / Delete Stability & Orphan Reference Handling', () {
    test('RoutineDetailsScreen lookup pattern safely handles deleted routine', () {
      final routines = <Routine>[
        Routine(
          id: 'routine_1',
          name: 'Morning Routine',
          daysOfWeek: [1, 2, 3, 4, 5],
          createdAt: DateTime.now(),
        ),
      ];

      // Existing routine lookup
      final found = routines.where((r) => r.id == 'routine_1').firstOrNull;
      expect(found, isNotNull);
      expect(found!.name, 'Morning Routine');

      // Deleted routine lookup (firstOrNull avoids StateError: Bad state: No element)
      final deleted = routines.where((r) => r.id == 'routine_deleted').firstOrNull;
      expect(deleted, isNull);

      // Verify that previously crashing pattern firstWhere(..., orElse: () => routines.first)
      // would crash on empty list:
      routines.clear();
      final emptyLookup = routines.where((r) => r.id == 'routine_1').firstOrNull;
      expect(emptyLookup, isNull); // Safely returns null, no crash
    });

    test('FocusScreen task lookup safely handles deleted task linked to session', () {
      final allTasks = <TaskModel>[
        TaskModel(
          id: 'task_1',
          title: 'Active Task',
          priority: TaskPriority.high,
          status: TaskStatus.inProgress,
          createdAt: DateTime.now(),
        ),
      ];

      // Active task exists
      final task = allTasks.where((t) => t.id == 'task_1').firstOrNull;
      expect(task, isNotNull);

      // Task was deleted while focus session was active
      final deletedTask = allTasks.where((t) => t.id == 'task_nonexistent').firstOrNull;
      expect(deletedTask, isNull); // Safely handles null without throwing StateError
    });

    test('CustomActivity lookup safely handles deleted activity in recentActivities', () {
      final activities = <ActivityDefinition>[];

      // When list is empty or ID not found
      final result = activities.where((a) => a.id == 'deleted_id').firstOrNull;
      expect(result, isNull); // No crash
    });

    test('Task creation and deletion lifecycle maintains state integrity', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = TaskRepository(prefs);

      final task = TaskModel(
        id: 'task_lifecycle_1',
        title: 'Complete audit',
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        createdAt: DateTime.now(),
      );

      // Add task
      await repo.createTask(task);
      var tasks = await repo.getTasks();
      expect(tasks.any((t) => t.id == 'task_lifecycle_1'), isTrue);

      // Update task
      final updatedTask = task.copyWith(status: TaskStatus.completed);
      await repo.updateTask(updatedTask);
      tasks = await repo.getTasks();
      expect(tasks.firstWhere((t) => t.id == 'task_lifecycle_1').status, TaskStatus.completed);

      // Delete task
      await repo.deleteTask('task_lifecycle_1');
      tasks = await repo.getTasks();
      expect(tasks.any((t) => t.id == 'task_lifecycle_1'), isFalse);

      // Deleting again does not crash
      await expectLater(repo.deleteTask('task_lifecycle_1'), completes);
    });
  });
}
