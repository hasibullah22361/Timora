import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/career/data/models/career_document_model.dart';
import 'package:timora/features/career/data/models/career_milestone_model.dart';
import 'package:timora/features/career/data/repositories/career_document_repository.dart';
import 'package:timora/features/career/data/repositories/career_roadmap_repository.dart';
import 'package:timora/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:timora/features/ai_assistant/services/voice_input_service.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/schedule/presentation/providers/schedule_provider.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('FEATURE 1: Career Document Vault Tests', () {
    test('Saves document metadata, calculates size from bytes, and refreshes provider', () async {
      final repo = container.read(careerDocumentRepositoryProvider);
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      final doc = CareerDocumentModel(
        id: 'doc_123',
        fileName: 'Senior_AI_Resume.pdf',
        documentType: 'Resume',
        fileUrl: '',
        description: 'Updated resume for AI lead role',
      );

      final saved = await repo.saveDocument(doc, fileBytes: fakeBytes);

      expect(saved.fileSize, equals(8));
      expect(saved.fileName, equals('Senior_AI_Resume.pdf'));
      expect(saved.documentType, equals('Resume'));

      final allDocs = await container.read(allCareerDocumentsProvider.future);
      expect(allDocs.length, equals(1));
      expect(allDocs.first.id, equals('doc_123'));
    });
  });

  group('FEATURE 2: Career Roadmap Tests (No CircularDependencyError)', () {
    test('activeRoadmapProvider resolves cleanly without CircularDependencyError', () async {
      // Must not throw Instance of 'CircularDependencyError'
      final roadmap = await container.read(activeRoadmapProvider.future);

      expect(roadmap, isNotNull);
      expect(roadmap!.id, equals('roadmap_ai_engineer'));
      expect(roadmap.title, contains('AI & Machine Learning'));

      final milestones = await container.read(roadmapMilestonesProvider(roadmap.id).future);
      expect(milestones.isNotEmpty, isTrue);
      expect(milestones.length, equals(6));
    });

    test('Saving and updating milestones recalculates progress smoothly', () async {
      final repo = container.read(careerRoadmapRepositoryProvider);
      final roadmap = await container.read(activeRoadmapProvider.future);
      expect(roadmap, isNotNull);

      final milestones = await container.read(roadmapMilestonesProvider(roadmap!.id).future);
      final first = milestones.first;

      await repo.saveMilestone(
        first.copyWith(progress: 100, status: CareerMilestoneStatus.completed),
      );

      final updatedMilestones = await container.read(roadmapMilestonesProvider(roadmap.id).future);
      expect(updatedMilestones.first.progress, equals(100));
    });
  });

  group('FEATURE 3: Notifications Inbox Tests', () {
    test('notificationsInboxProvider resolves and aggregates timeline items', () async {
      final inbox = await container.read(notificationsInboxProvider.future);
      expect(inbox, isA<List<TimoraInboxItem>>());
    });
  });

  group('FEATURE 4: Natural Voice Planning Tests', () {
    test('Command 1: "Schedule study tomorrow from 9 AM to 11 AM" creates activity with exact times', () async {
      final service = container.read(voiceInputServiceProvider);
      final result = await service.processVoiceInput(
        'Schedule study tomorrow from 9 AM to 11 AM',
        target: VoiceRoutingTarget.activity,
      );

      expect(result.target, VoiceRoutingTarget.activity);
      expect(result.parsedActivity, isNotNull);
      expect(result.parsedActivity!.title, equals('Study'));
      expect(result.parsedActivity!.startTime.hour, equals(9));
      expect(result.parsedActivity!.startTime.minute, equals(0));
      expect(result.parsedActivity!.endTime.hour, equals(11));
      expect(result.parsedActivity!.endTime.minute, equals(0));

      final repo = container.read(scheduleRepositoryProvider);
      final activities = await repo.getActivitiesForDate(DateTime.now().add(const Duration(days: 1)));
      expect(activities.any((a) => a.title == 'Study'), isTrue);
    });

    test('Command 2: "Schedule gym tomorrow at 5 PM for one hour" creates 17:00 - 18:00 activity', () async {
      final service = container.read(voiceInputServiceProvider);
      final result = await service.processVoiceInput(
        'Schedule gym tomorrow at 5 PM for one hour',
        target: VoiceRoutingTarget.activity,
      );

      expect(result.target, VoiceRoutingTarget.activity);
      expect(result.parsedActivity, isNotNull);
      expect(result.parsedActivity!.title, equals('Gym'));
      expect(result.parsedActivity!.startTime.hour, equals(17));
      expect(result.parsedActivity!.endTime.hour, equals(18));
    });

    test('Command 3: "Move my research to 9 PM" reschedules matching activity', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final researchAct = ScheduleActivity(
        id: const Uuid().v4(),
        title: 'Research',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 14, 0),
        endTime: DateTime(today.year, today.month, today.day, 16, 0),
        category: 'Work',
        icon: '🔬',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );

      await container.read(scheduleNotifierProvider).addActivity(researchAct);

      final service = container.read(voiceInputServiceProvider);
      final result = await service.processVoiceInput(
        'Move my research to 9 PM',
        target: VoiceRoutingTarget.reschedule,
      );

      expect(result.target, VoiceRoutingTarget.reschedule);
      expect(result.parsedActivity, isNotNull);
      expect(result.parsedActivity!.startTime.hour, equals(21));
      expect(result.parsedActivity!.startTime.minute, equals(0));
    });

    test('Command 4: "Cancel today\'s gym" marks matching activity skipped', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final gymAct = ScheduleActivity(
        id: const Uuid().v4(),
        title: 'Gym Workout',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 18, 0),
        endTime: DateTime(today.year, today.month, today.day, 19, 0),
        category: 'Health',
        icon: '🏋️',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );

      await container.read(scheduleNotifierProvider).addActivity(gymAct);

      final service = container.read(voiceInputServiceProvider);
      final result = await service.processVoiceInput(
        "Cancel today's gym",
        target: VoiceRoutingTarget.cancel,
      );

      expect(result.target, VoiceRoutingTarget.cancel);
      expect(result.parsedActivity, isNotNull);

      final repo = container.read(scheduleRepositoryProvider);
      final todayActs = await repo.getActivitiesForDate(today);
      final cancelled = todayActs.firstWhere((a) => a.id == gymAct.id);
      expect(cancelled.status, equals(ActivityStatus.skipped));
    });

    test('Command 5 & 6: "What should I do now?" and "What is my schedule tomorrow?" query correctly', () async {
      final service = container.read(voiceInputServiceProvider);

      final resultNow = await service.processVoiceInput(
        'What should I do now?',
        target: VoiceRoutingTarget.queryWhatShouldIDoNow,
      );
      expect(resultNow.target, equals(VoiceRoutingTarget.queryWhatShouldIDoNow));
      expect(resultNow.spokenFeedback, isNotNull);

      final resultTomorrow = await service.processVoiceInput(
        'What is my schedule tomorrow?',
        target: VoiceRoutingTarget.querySchedule,
      );
      expect(resultTomorrow.target, equals(VoiceRoutingTarget.querySchedule));
      expect(resultTomorrow.spokenFeedback, isNotNull);
    });

    test('Ambiguous missing time command asks for clarification instead of inventing time', () async {
      final service = container.read(voiceInputServiceProvider);
      final result = await service.processVoiceInput(
        'Schedule study tomorrow',
        target: VoiceRoutingTarget.activity,
      );

      expect(result.isAmbiguous, isTrue);
      expect(result.clarificationPrompt, contains('What time would you like to study tomorrow?'));
      expect(result.parsedActivity, isNull); // Must NOT invent a random time
    });

    test('Destructive command with multiple matches requires confirmation', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final session1 = ScheduleActivity(
        id: const Uuid().v4(),
        title: 'Research Session A',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 10, 0),
        endTime: DateTime(today.year, today.month, today.day, 11, 0),
        category: 'Work',
        icon: '🔬',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );

      final session2 = ScheduleActivity(
        id: const Uuid().v4(),
        title: 'Research Session B',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 15, 0),
        endTime: DateTime(today.year, today.month, today.day, 16, 0),
        category: 'Work',
        icon: '🔬',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );

      await container.read(scheduleNotifierProvider).addActivity(session1);
      await container.read(scheduleNotifierProvider).addActivity(session2);

      final service = container.read(voiceInputServiceProvider);
      final result = await service.processVoiceInput(
        'Cancel my research',
        target: VoiceRoutingTarget.cancel,
      );

      expect(result.requiresConfirmation, isTrue);
      expect(result.isAmbiguous, isTrue);
      expect(result.clarificationPrompt, contains('Which research session would you like to cancel?'));
    });
  });
}
