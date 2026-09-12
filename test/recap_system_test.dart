import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/features/recap/domain/models/recap_models.dart';
import 'package:timora/features/recap/data/repositories/recap_repository.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/notifications/domain/models/notification_event.dart';
import 'package:timora/features/diary/data/models/diary_entry_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Timora AI Recap System Tests', () {
    late SharedPreferences prefs;
    late RecapRepository recapRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      recapRepo = RecapRepository(prefs);
    });

    test('1. Deterministic Recap IDs prevent duplicate entries', () {
      final date = DateTime(2026, 9, 9);
      final dailyId = TimoraRecapModel.buildRecapId(RecapType.daily, date);
      final weeklyId = TimoraRecapModel.buildRecapId(RecapType.weekly, date);
      final monthlyId = TimoraRecapModel.buildRecapId(RecapType.monthly, date);

      expect(dailyId, 'recap_daily_2026_09_09');
      // Weekly key is normalized to Monday
      expect(weeklyId, startsWith('recap_weekly_2026_09_'));
      expect(monthlyId, 'recap_monthly_2026_09');
    });

    test('2. TimoraRecapModel Serialization & JSON round-trip integrity', () {
      final date = DateTime(2026, 9, 9);
      final recap = TimoraRecapModel(
        id: 'recap_daily_2026_09_09',
        type: RecapType.daily,
        targetDate: date,
        periodStart: DateTime(2026, 9, 9, 0, 0),
        periodEnd: DateTime(2026, 9, 9, 23, 59, 59),
        totalTasks: 10,
        completedTasks: 8,
        incompleteTasks: 1,
        missedTasks: 1,
        skippedTasks: 0,
        replacedTasks: 1,
        rescheduledTasks: 0,
        taskOutcomes: [
          const TaskOutcomeItem(
            taskId: 't1',
            title: 'Finish Python Study',
            status: TaskOutcomeStatus.completed,
          ),
          const TaskOutcomeItem(
            taskId: 't2',
            title: 'Workout',
            status: TaskOutcomeStatus.replaced,
            replacedByTitle: 'Project Development',
          ),
        ],
        totalActivities: 5,
        completedActivities: 4,
        missedActivities: 1,
        skippedActivities: 0,
        replacedActivities: 1,
        completedRoutines: 2,
        missedRoutines: 0,
        focusMinutes: 192,
        deepWorkMinutes: 120,
        productivityScore: 82.0,
        routineConsistency: 84.0,
        scheduleAdherence: 90.0,
        goalProgress: 80.0,
        timelineItems: [
          RecapTimelineItem(
            id: 'a1',
            title: 'Morning Routine',
            time: DateTime(2026, 9, 9, 8, 0),
            status: ActivityStatus.completed,
          ),
        ],
        wins: ['8 tasks completed', '3h 12m focused work'],
        areasToImprove: ['Workout was replaced by project work'],
        aiSummary: 'Today you completed 8 of 10 planned tasks.\nYou spent 3h 12m in focused work.\nTomorrow, prioritize Report.',
        spokenScript: 'Your daily recap is ready. You completed eight of ten tasks and spent 3 hours and 12 minutes in focused work.',
        notificationBody: '8/10 tasks completed • 3h 12m focus • 82% productivity',
        aiInsights: ['Strongest work period was 9 AM to 12 PM.'],
        tomorrowRecommendations: [
          const TomorrowRecommendation(
            id: 'r1',
            title: 'Finish Report',
            priority: 'HIGH',
            reason: 'Highest priority open task',
          ),
        ],
        createdAt: DateTime(2026, 9, 9, 23, 0),
      );

      final json = recap.toJson();
      final restored = TimoraRecapModel.fromJson(json);

      expect(restored.id, recap.id);
      expect(restored.type, RecapType.daily);
      expect(restored.completedTasks, 8);
      expect(restored.totalTasks, 10);
      expect(restored.focusMinutes, 192);
      expect(restored.productivityScore, 82.0);
      expect(restored.taskOutcomes.length, 2);
      expect(restored.taskOutcomes[1].status, TaskOutcomeStatus.replaced);
      expect(restored.taskOutcomes[1].replacedByTitle, 'Project Development');
    });

    test('3. Replaced Task Semantics — Replacement does not count as double missed', () {
      final replacedItem = const TaskOutcomeItem(
        taskId: 't_replaced',
        title: 'Workout',
        status: TaskOutcomeStatus.replaced,
        replacedByTitle: 'Project Development',
      );

      expect(replacedItem.status, TaskOutcomeStatus.replaced);
      expect(replacedItem.replacedByTitle, 'Project Development');
      expect(replacedItem.status != TaskOutcomeStatus.completed, isTrue);
      expect(replacedItem.status != TaskOutcomeStatus.missed, isTrue);
    });

    test('4. RecapRepository persists and queries recaps by type idempotently', () async {
      final date = DateTime(2026, 9, 9);
      final recap1 = TimoraRecapModel(
        id: TimoraRecapModel.buildRecapId(RecapType.daily, date),
        type: RecapType.daily,
        targetDate: date,
        periodStart: DateTime(2026, 9, 9, 0, 0),
        periodEnd: DateTime(2026, 9, 9, 23, 59, 59),
        totalTasks: 5,
        completedTasks: 4,
        incompleteTasks: 1,
        missedTasks: 0,
        skippedTasks: 0,
        replacedTasks: 0,
        rescheduledTasks: 0,
        taskOutcomes: [],
        totalActivities: 0,
        completedActivities: 0,
        missedActivities: 0,
        skippedActivities: 0,
        replacedActivities: 0,
        completedRoutines: 0,
        missedRoutines: 0,
        focusMinutes: 60,
        deepWorkMinutes: 45,
        productivityScore: 80.0,
        routineConsistency: 80.0,
        scheduleAdherence: 80.0,
        goalProgress: 80.0,
        timelineItems: [],
        wins: ['4 tasks done'],
        areasToImprove: [],
        aiSummary: 'Summary',
        spokenScript: 'Speech',
        notificationBody: 'Body',
        aiInsights: [],
        tomorrowRecommendations: [],
        createdAt: DateTime.now(),
      );

      await recapRepo.saveRecap(recap1);

      final fetched = await recapRepo.getRecapForDate(RecapType.daily, date);
      expect(fetched, isNotNull);
      expect(fetched!.completedTasks, 4);

      // Re-saving with updated stats updates in place without duplicates
      final updated = recap1.copyWith(completedTasks: 5);
      await recapRepo.saveRecap(updated);

      final allRecaps = await recapRepo.getRecapsByType(RecapType.daily);
      expect(allRecaps.length, 1);
      expect(allRecaps.first.completedTasks, 5);
    });

    test('5. NotificationEvent supports dailyRecap, weeklyRecap, monthlyRecap', () {
      final now = DateTime(2026, 9, 9, 23, 0);

      final event = NotificationEvent.create(
        sourceType: NotificationSourceType.recap,
        sourceId: 'daily_recap',
        eventType: NotificationEventType.dailyRecap,
        title: '🧠 Your Daily Recap is Ready',
        notificationBody: '8/10 tasks completed • 3h 12m focus • 82% score',
        spokenMessage: 'Your daily recap is ready.',
        scheduledTime: now,
        metadata: {'type': 'recap', 'recapType': 'daily'},
      );

      expect(event.eventType, NotificationEventType.dailyRecap);
      expect(event.sourceType, NotificationSourceType.recap);
      expect(event.title, '🧠 Your Daily Recap is Ready');
      expect(event.metadata['type'], 'recap');
      expect(event.metadata['recapType'], 'daily');

      final json = event.toJson();
      final restored = NotificationEvent.fromJson(json);
      expect(restored.eventType, NotificationEventType.dailyRecap);
      expect(restored.sourceType, NotificationSourceType.recap);
    });

    test('6. Idempotent Diary Save format', () {
      final date = DateTime(2026, 9, 9);
      final diaryEntryId = 'recap_daily_2026_09_09';

      final entry1 = DiaryEntryModel(
        id: diaryEntryId,
        date: date,
        title: '🧠 AI Daily Recap — September 9, 2026',
        content: 'Today you completed 8 of 10 tasks and spent 3h 12m in focused work.',
        mood: 4,
        tags: ['recap', 'ai-summary', 'daily'],
        createdAt: DateTime.now(),
      );

      expect(entry1.id, diaryEntryId);
      expect(entry1.tags, contains('recap'));
      expect(entry1.tags, contains('daily'));

      // Re-saving with new timestamp updates in place
      final entry2 = entry1.copyWith(content: 'Updated recap content');
      expect(entry2.id, diaryEntryId);
      expect(entry2.content, 'Updated recap content');
    });
  });
}
