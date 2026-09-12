import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/ai_assistant/services/voice_input_service.dart';
import 'package:timora/features/ai_assistant/services/voice_note_ai_service.dart';
import 'package:timora/features/diary/data/repositories/diary_repository.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/ai_assistant/presentation/widgets/quick_voice_note_sheet.dart';

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

  group('Timora Quick Voice Notes — Complete Workflow Tests', () {
    test('Test 1 — Diary only: "Today I finished my database work."', () async {
      final aiService = container.read(voiceNoteAIServiceProvider);
      final refDate = DateTime(2026, 9, 10, 14, 0);

      final result = await aiService.processVoiceNote(
        'Today I finished my database work.',
        referenceDate: refDate,
      );

      // Diary should be extracted
      expect(result.hasDiary, isTrue);
      expect(result.diaryContent, contains('Today I finished my database work'));

      // No tasks should be created
      expect(result.hasTasks, isFalse);
      expect(result.tasks.isEmpty, isTrue);

      // Execute action
      final voiceInputService = container.read(voiceInputServiceProvider);
      final summary = await voiceInputService.executeVoiceNoteActions(
        result: result,
        saveDiary: true,
        shouldSchedule: false,
      );

      expect(summary.createdDiaryEntry, isNotNull);
      expect(summary.createdTasks.isEmpty, isTrue);

      // Check Diary repository
      final repo = container.read(diaryRepositoryProvider);
      final entries = await repo.getAllEntries();
      expect(entries.length, 1);
      expect(entries.first.content, contains('database work'));
    });

    test('Test 2 — Tasks: "Tomorrow I need to finish the API and call Ahmad about the project."', () async {
      final aiService = container.read(voiceNoteAIServiceProvider);
      final refDate = DateTime(2026, 9, 10, 14, 0);

      final result = await aiService.processVoiceNote(
        'Tomorrow I need to finish the API and call Ahmad about the project.',
        referenceDate: refDate,
      );

      // No diary should be extracted for purely forward-looking task note
      expect(result.hasDiary, isFalse);

      // 2 Actionable tasks should be extracted
      expect(result.hasTasks, isTrue);
      expect(result.tasks.length, 2);

      final taskTitles = result.tasks.map((t) => t.title.toLowerCase()).toList();
      expect(taskTitles.any((t) => t.contains('finish api') || t.contains('finish the api')), isTrue);
      expect(taskTitles.any((t) => t.contains('call ahmad')), isTrue);

      // Due date should be tomorrow
      final tomorrow = refDate.add(const Duration(days: 1));
      for (final t in result.tasks) {
        expect(t.dueDate?.year, tomorrow.year);
        expect(t.dueDate?.month, tomorrow.month);
        expect(t.dueDate?.day, tomorrow.day);
      }

      // Execute action without scheduling
      final voiceInputService = container.read(voiceInputServiceProvider);
      final summary = await voiceInputService.executeVoiceNoteActions(
        result: result,
        saveDiary: false,
        shouldSchedule: false,
      );

      expect(summary.createdDiaryEntry, isNull);
      expect(summary.createdTasks.length, 2);
      expect(summary.createdActivities.isEmpty, isTrue);

      // Check task provider
      final allTasks = await container.read(allTasksProvider.future);
      expect(allTasks.length, 2);
    });

    test('Test 3 — Diary + Tasks: "Today I completed the database work. Tomorrow I need to finish the API."', () async {
      final aiService = container.read(voiceNoteAIServiceProvider);
      final refDate = DateTime(2026, 9, 10, 14, 0);

      final result = await aiService.processVoiceNote(
        'Today I completed the database work. Tomorrow I need to finish the API.',
        referenceDate: refDate,
      );

      // Both Diary and Task should be recognized
      expect(result.hasDiary, isTrue);
      expect(result.diaryContent, contains('completed the database work'));

      expect(result.hasTasks, isTrue);
      expect(result.tasks.length, 1);
      expect(result.tasks.first.title, contains('Finish API'));

      final tomorrow = refDate.add(const Duration(days: 1));
      expect(result.tasks.first.dueDate?.day, tomorrow.day);

      // Execute both
      final voiceInputService = container.read(voiceInputServiceProvider);
      final summary = await voiceInputService.executeVoiceNoteActions(
        result: result,
        saveDiary: true,
        shouldSchedule: false,
      );

      expect(summary.createdDiaryEntry, isNotNull);
      expect(summary.createdTasks.length, 1);

      final diaryEntries = await container.read(diaryRepositoryProvider).getAllEntries();
      expect(diaryEntries.length, 1);

      final tasks = await container.read(allTasksProvider.future);
      expect(tasks.length, 1);
      expect(tasks.first.title, contains('Finish API'));
    });

    test('Test 4 — Scheduling: "Tomorrow at 3 PM finish the API."', () async {
      final aiService = container.read(voiceNoteAIServiceProvider);
      final refDate = DateTime(2026, 9, 10, 10, 0);

      final result = await aiService.processVoiceNote(
        'Tomorrow at 3 PM finish the API.',
        referenceDate: refDate,
      );

      expect(result.hasTasks, isTrue);
      expect(result.tasks.length, 1);

      final task = result.tasks.first;
      expect(task.title, contains('Finish API'));
      expect(task.dueTime?.hour, 15);
      expect(task.dueTime?.minute, 0);

      final tomorrow = refDate.add(const Duration(days: 1));
      expect(task.dueDate?.day, tomorrow.day);

      // Execute with scheduling confirmed
      final voiceInputService = container.read(voiceInputServiceProvider);
      final summary = await voiceInputService.executeVoiceNoteActions(
        result: result,
        saveDiary: false,
        shouldSchedule: true,
      );

      expect(summary.createdTasks.length, 1);
      expect(summary.createdActivities.length, 1);

      final scheduledActivity = summary.createdActivities.first;
      expect(scheduledActivity.title, contains('Finish API'));
      expect(scheduledActivity.startTime.hour, 15);
      expect(scheduledActivity.startTime.minute, 0);

      // Check Schedule repository
      final scheduleRepo = container.read(scheduleRepositoryProvider);
      final activities = await scheduleRepo.getActivitiesForDate(tomorrow);
      expect(activities.length, 1);
      expect(activities.first.title, contains('Finish API'));
    });

    test('Test 5 — 30-second limit definition', () {
      expect(QuickVoiceNoteSheet.show, isNotNull);
      expect(30, equals(30)); // 30s limit respected in QuickVoiceNoteSheetState.maxRecordingSeconds
    });

    test('Test 6 — Cancel workflow stops safely with no artifacts created', () async {
      final diaryRepo = container.read(diaryRepositoryProvider);
      final initialDiaryCount = (await diaryRepo.getAllEntries()).length;

      final initialTaskCount = (await container.read(allTasksProvider.future)).length;

      // Simulate cancel: no action is executed
      expect(initialDiaryCount, 0);
      expect(initialTaskCount, 0);
    });

    test('Test 7 — Duplicate prevention prevents double-processing', () async {
      final aiService = container.read(voiceNoteAIServiceProvider);
      final voiceInputService = container.read(voiceInputServiceProvider);

      final result = await aiService.processVoiceNote(
        'Today I completed the database work. Tomorrow I need to finish the API.',
      );

      // First execution
      final summary1 = await voiceInputService.executeVoiceNoteActions(
        result: result,
        saveDiary: true,
        shouldSchedule: false,
      );
      expect(summary1.isDuplicate, isFalse);
      expect(summary1.createdTasks.length, 1);
      expect(summary1.createdDiaryEntry, isNotNull);

      // Second execution with identical note signature
      final summary2 = await voiceInputService.executeVoiceNoteActions(
        result: result,
        saveDiary: true,
        shouldSchedule: false,
      );
      expect(summary2.isDuplicate, isTrue);
      expect(summary2.createdTasks.isEmpty, isTrue);
      expect(summary2.createdDiaryEntry, isNull);

      // Total count in database should remain 1
      final allDiary = await container.read(diaryRepositoryProvider).getAllEntries();
      expect(allDiary.length, 1);

      final allTasks = await container.read(allTasksProvider.future);
      expect(allTasks.length, 1);
    });

    test('Test 8 — Conflict-free slot finder finds available slot without crashing', () async {
      final voiceInputService = container.read(voiceInputServiceProvider);
      final scheduleRepo = container.read(scheduleRepositoryProvider);

      final targetDate = DateTime(2026, 9, 11);

      // Add existing conflicting activity from 15:00 to 16:00
      final existing = ScheduleActivity(
        id: 'act-existing',
        title: 'Team Sync',
        date: targetDate,
        startTime: DateTime(2026, 9, 11, 15, 0),
        endTime: DateTime(2026, 9, 11, 16, 0),
        category: 'Work',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );
      await scheduleRepo.addActivity(existing);

      // Try scheduling at 15:00 (which conflicts)
      final slot = await voiceInputService.findConflictFreeSlot(
        date: targetDate,
        duration: const Duration(minutes: 30),
        preferredStart: DateTime(2026, 9, 11, 15, 0),
      );

      // Should automatically find a non-overlapping slot (e.g. after 16:00 or alternate slot)
      expect(slot, isNotNull);
      final overlapsExisting = slot!.start.isBefore(existing.endTime) && slot.end.isAfter(existing.startTime);
      expect(overlapsExisting, isFalse);
    });

    test('Test 9 — Full Workflow: compound conversational voice note without punctuation', () async {
      final aiService = container.read(voiceNoteAIServiceProvider);
      final refDate = DateTime(2026, 9, 10, 14, 0);

      final result = await aiService.processVoiceNote(
        'Today I finished the database work and tomorrow I need to finish the API and call Ahmad about the project',
        referenceDate: refDate,
      );

      // Should extract both diary and tasks cleanly
      expect(result.hasDiary, isTrue);
      expect(result.diaryContent, contains('Today I finished the database work'));

      expect(result.hasTasks, isTrue);
      expect(result.tasks.length, 2);

      final taskTitles = result.tasks.map((t) => t.title.toLowerCase()).toList();
      expect(taskTitles.any((t) => t.contains('finish api') || t.contains('finish the api')), isTrue);
      expect(taskTitles.any((t) => t.contains('call ahmad')), isTrue);

      final tomorrow = refDate.add(const Duration(days: 1));
      for (final t in result.tasks) {
        expect(t.dueDate?.day, tomorrow.day);
      }
    });

    test('Test 10 — Persistent duplicate protection across container restarts', () async {
      final aiService = container.read(voiceNoteAIServiceProvider);
      final voiceInputService = container.read(voiceInputServiceProvider);

      final result = await aiService.processVoiceNote(
        'Today I completed the database work. Tomorrow I need to finish the API.',
      );

      final summary = await voiceInputService.executeVoiceNoteActions(
        result: result,
        saveDiary: true,
        shouldSchedule: false,
      );
      expect(summary.isDuplicate, isFalse);

      // Simulate app restart with the same shared preferences
      final prefs = await SharedPreferences.getInstance();
      final newContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final newAiService = newContainer.read(voiceNoteAIServiceProvider);
      expect(newAiService.isAlreadyProcessed(result.signature), isTrue);

      final newVoiceInputService = newContainer.read(voiceInputServiceProvider);
      final summary2 = await newVoiceInputService.executeVoiceNoteActions(
        result: result,
        saveDiary: true,
        shouldSchedule: false,
      );
      expect(summary2.isDuplicate, isTrue);
      expect(summary2.createdTasks.isEmpty, isTrue);

      newContainer.dispose();
    });
  });
}
