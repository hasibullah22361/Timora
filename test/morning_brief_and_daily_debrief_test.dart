import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/settings/data/repositories/notification_settings_repository.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/focus/data/models/focus_session_model.dart';
import 'package:timora/features/focus/presentation/providers/focus_provider.dart';
import 'package:timora/features/diary/data/repositories/diary_repository.dart';
import 'package:timora/features/ai_assistant/services/morning_brief_service.dart';
import 'package:timora/features/ai_assistant/services/daily_debrief_service.dart';
import 'package:timora/features/notifications/domain/models/notification_event.dart';
import 'package:timora/features/notifications/application/notification_event_engine.dart';
import 'package:timora/features/notifications/application/alarm_scheduler_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late NotificationSettingsRepository settingsRepo;
  late TaskRepository taskRepo;
  late ScheduleRepository scheduleRepo;
  late DiaryRepository diaryRepo;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    settingsRepo = NotificationSettingsRepository(prefs);
    taskRepo = TaskRepository(prefs);
    scheduleRepo = ScheduleRepository(prefs);
    diaryRepo = DiaryRepository(prefs);
    await settingsRepo.setQuietHoursEnabled(false);

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationSettingsRepositoryProvider.overrideWithValue(settingsRepo),
        taskRepositoryProvider.overrideWithValue(taskRepo),
        scheduleRepositoryProvider.overrideWithValue(scheduleRepo),
        diaryRepositoryProvider.overrideWithValue(diaryRepo),
        allFocusSessionsProvider.overrideWith((ref) async => <FocusSessionModel>[]),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Timora AI Morning Brief Tests', () {
    test('MB-1: Extracts real tasks and schedule activities for current day', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Add real tasks
      await taskRepo.createTask(TaskModel(
        id: 'task-1',
        title: 'Complete Research Paper',
        priority: TaskPriority.high,
        dueDate: today,
        createdAt: now,
      ));
      await taskRepo.createTask(TaskModel(
        id: 'task-2',
        title: 'Review System Architecture',
        priority: TaskPriority.medium,
        dueDate: today,
        createdAt: now,
      ));

      // Add real schedule activity
      await scheduleRepo.addActivity(ScheduleActivity(
        id: 'act-1',
        title: 'AI Study Session',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 9, 0),
        endTime: DateTime(today.year, today.month, today.day, 10, 30),
        category: 'Study',
        createdAt: now,
      ));

      final service = container.read(morningBriefServiceProvider);
      final brief = await service.generateMorningBrief();

      expect(brief.priorities, contains('Complete Research Paper'));
      expect(brief.totalTasksToday, 2);
      expect(brief.firstActivityTitle, 'AI Study Session');
      expect(brief.scheduledActivitiesCount, 1);
      expect(brief.briefText, contains('Complete Research Paper'));
    });

    test('MB-2: Short duration mode produces concise brief with top priority & first activity', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await taskRepo.createTask(TaskModel(
        id: 'task-short',
        title: 'Database Migration',
        priority: TaskPriority.urgent,
        dueDate: today,
        createdAt: now,
      ));

      await scheduleRepo.addActivity(ScheduleActivity(
        id: 'act-short',
        title: 'Sprint Planning',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 10, 0),
        endTime: DateTime(today.year, today.month, today.day, 11, 0),
        createdAt: now,
      ));

      final service = container.read(morningBriefServiceProvider);
      final brief = await service.generateMorningBrief(durationOverride: 'short');

      expect(brief.duration, 'short');
      expect(brief.briefText, contains('Database Migration'));
      expect(brief.briefText, contains('Sprint Planning'));
    });

    test('MB-3: Empty schedule produces encouraging greeting without fake tasks', () async {
      final service = container.read(morningBriefServiceProvider);
      final brief = await service.generateMorningBrief();

      expect(brief.priorities, isEmpty);
      expect(brief.firstActivityTitle, isNull);
      expect(brief.briefText, contains('Good morning'));
      expect(brief.briefText, isNot(contains('Research Paper')));
    });

    test('MB-4: Settings preferences correctly persist voice, duration, and auto-play', () async {
      expect(settingsRepo.morningBriefEnabled, isTrue);
      expect(settingsRepo.morningBriefDuration, 'normal');
      expect(settingsRepo.morningBriefAutoPlay, isTrue);

      await settingsRepo.setMorningBriefDuration('detailed');
      await settingsRepo.setMorningBriefVoiceGender('male');
      await settingsRepo.setMorningBriefAutoPlay(false);

      expect(settingsRepo.morningBriefDuration, 'detailed');
      expect(settingsRepo.morningBriefVoiceGender, 'male');
      expect(settingsRepo.morningBriefAutoPlay, isFalse);
    });
  });

  group('Timora AI Daily Debrief Tests', () {
    test('DD-1: Synthesizes 3-part reflection from Q1 and Q2 answers and real metrics', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Add a completed task for today
      await taskRepo.createTask(TaskModel(
        id: 'task-done',
        title: 'Finish API endpoints',
        status: TaskStatus.completed,
        completedAt: today.add(const Duration(hours: 14)),
        createdAt: now,
      ));

      final service = container.read(dailyDebriefServiceProvider);
      final result = await service.processAndSaveDebrief(
        whatWentWell: 'I completed all my API endpoints.',
        whatToImprove: 'I got distracted by social media in the afternoon.',
      );

      expect(result.whatWentWell, 'I completed all my API endpoints.');
      expect(result.whatToImprove, 'I got distracted by social media in the afternoon.');
      expect(result.reflection, isNotEmpty);
      expect(result.reflection, contains('API endpoints'));
      expect(result.tasksCompletedToday, 1);
    });

    test('DD-2: Automatically saves reflection into Timora existing Diary repository', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final service = container.read(dailyDebriefServiceProvider);
      final result = await service.processAndSaveDebrief(
        whatWentWell: 'Closed 3 major user stories.',
        whatToImprove: 'Start deep work block earlier.',
      );

      final savedEntry = await diaryRepo.getEntryById(result.diaryEntryId);
      expect(savedEntry, isNotNull);
      expect(savedEntry!.date.year, today.year);
      expect(savedEntry.date.month, today.month);
      expect(savedEntry.date.day, today.day);
      expect(savedEntry.highlights, contains('Closed 3 major user stories.'));
      expect(savedEntry.gratitudeList, contains('Start deep work block earlier.'));
      expect(savedEntry.aiReflection, isNotNull);
      expect(savedEntry.content, contains('### 🌙 Daily Debrief'));
      expect(savedEntry.content, contains('Closed 3 major user stories.'));
    });

    test('DD-3: Handles empty answers safely with graceful defaults', () async {
      final service = container.read(dailyDebriefServiceProvider);
      final result = await service.processAndSaveDebrief(
        whatWentWell: '',
        whatToImprove: '',
      );

      expect(result.whatWentWell, isNotEmpty);
      expect(result.whatToImprove, isNotEmpty);
      expect(result.reflection, isNotEmpty);
      expect(result.diaryEntryId, isNotEmpty);
    });
  });

  group('Timora Notification & Alarm Integration Tests', () {
    test('NOTIF-1: NotificationEventEngine builds Morning Brief and Daily Debrief events', () async {
      final now = DateTime.now();
      final engine = NotificationEventEngine(
        AlarmSchedulerService(),
        settingsRepo,
        scheduleRepo,
        taskRepo,
      );

      final mbEvent = engine.buildMorningBriefEvent(now);
      expect(mbEvent, isNotNull);
      expect(mbEvent!.eventType, NotificationEventType.morningBrief);
      expect(mbEvent.title, contains('Morning'));
      expect(mbEvent.metadata['payload'], 'morning_brief');

      final ddEvent = engine.buildDailyDebriefEvent(now);
      expect(ddEvent, isNotNull);
      expect(ddEvent!.eventType, NotificationEventType.dailyDebrief);
      expect(ddEvent.title, contains('Daily Debrief'));
      expect(ddEvent.metadata['payload'], 'daily_debrief');
    });

    test('NOTIF-2: Respects disabled toggles for Morning Brief and Daily Debrief', () async {
      await settingsRepo.setMorningBriefEnabled(false);
      await settingsRepo.setDailyDebriefEnabled(false);

      final now = DateTime.now();
      final engine = NotificationEventEngine(
        AlarmSchedulerService(),
        settingsRepo,
        scheduleRepo,
        taskRepo,
      );

      expect(engine.buildMorningBriefEvent(now), isNull);
      expect(engine.buildDailyDebriefEvent(now), isNull);
    });
  });
}
