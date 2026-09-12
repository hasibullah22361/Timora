import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/utils/link_handler.dart';
import 'package:timora/features/others/presentation/screens/others_screen.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/data/repositories/schedule_repository.dart';
import 'package:timora/features/schedule/services/smart_rescheduling_service.dart';
import 'package:timora/features/analytics/data/models/report_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Area 1 & 2: Features View Mode & Switcher', () {
    test('FeaturesViewModeNotifier defaults to grid and persists selection', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = FeaturesViewModeNotifier(prefs);
      expect(notifier.state, FeaturesViewMode.grid);

      await notifier.setMode(FeaturesViewMode.list);
      expect(notifier.state, FeaturesViewMode.list);
      expect(prefs.getString('timora_features_view_mode'), 'list');

      // Reopening notifier restores saved preference
      final restoredNotifier = FeaturesViewModeNotifier(prefs);
      expect(restoredNotifier.state, FeaturesViewMode.list);

      await restoredNotifier.setMode(FeaturesViewMode.grid);
      expect(restoredNotifier.state, FeaturesViewMode.grid);
      expect(prefs.getString('timora_features_view_mode'), 'grid');
    });
  });

  group('Area 3: LinkHandler and URL Detection', () {
    test('isExternalUrl correctly validates web links', () {
      expect(LinkHandler.isExternalUrl('https://example.com'), isTrue);
      expect(LinkHandler.isExternalUrl('http://timora.app/updates'), isTrue);
      expect(LinkHandler.isExternalUrl('HTTPS://GOOGLE.COM'), isTrue);

      expect(LinkHandler.isExternalUrl('timora://schedule'), isFalse);
      expect(LinkHandler.isExternalUrl('timora://task/123'), isFalse);
      expect(LinkHandler.isExternalUrl('clock'), isFalse);
      expect(LinkHandler.isExternalUrl(''), isFalse);
      expect(LinkHandler.isExternalUrl(null), isFalse);
    });

    test('extractUrls extracts HTTP and HTTPS URLs from text messages', () {
      const text = 'Check the new features at https://timora.app/v2 or visit http://blog.timora.app today!';
      final urls = LinkHandler.extractUrls(text);
      expect(urls.length, 2);
      expect(urls[0], 'https://timora.app/v2');
      expect(urls[1], 'http://blog.timora.app');
    });

    test('extractUrls returns empty list when no URL present', () {
      const text = 'Your deep focus session has ended. Great job!';
      expect(LinkHandler.extractUrls(text), isEmpty);
    });
  });

  group('Area 4: Schedule Activity Replacement & Integrity', () {
    test('ScheduleActivity serializes and deserializes replacement fields and status', () {
      final now = DateTime(2026, 9, 9, 14, 30);
      final end = now.add(const Duration(hours: 2));

      final original = ScheduleActivity(
        id: 'act-sleep-1',
        title: 'Sleep',
        date: now,
        startTime: now,
        endTime: end,
        category: 'Rest',
        icon: '😴',
        status: ActivityStatus.replaced,
        replacedByActivityId: 'act-project-2',
        replacementActivityTitle: 'Work on Project',
        createdAt: now,
      );

      final json = original.toJson();
      expect(json['status'], 'replaced');
      expect(json['replacedByActivityId'], 'act-project-2');
      expect(json['replacementActivityTitle'], 'Work on Project');

      final deserialized = ScheduleActivity.fromJson(json);
      expect(deserialized.id, 'act-sleep-1');
      expect(deserialized.title, 'Sleep');
      expect(deserialized.status, ActivityStatus.replaced);
      expect(deserialized.replacedByActivityId, 'act-project-2');
      expect(deserialized.replacementActivityTitle, 'Work on Project');
    });

    test('ScheduleRepository.replaceActivity replaces planned activity preserving exact time block and ID', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ScheduleRepository(prefs, userId: 'test-user');

      final today = DateTime(2026, 9, 9);
      final start = DateTime(2026, 9, 9, 13, 0);
      final end = DateTime(2026, 9, 9, 14, 0);

      // 1. Add original activity: Study (1:00 PM - 2:00 PM, 60 min)
      final studyActivity = ScheduleActivity(
        id: 'study-123',
        title: 'Study',
        date: today,
        startTime: start,
        endTime: end,
        category: 'Education',
        icon: '📚',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );
      await repo.addActivity(studyActivity);

      // Verify original is in repository
      var activities = await repo.getActivitiesForDate(today);
      expect(activities.length, 1);
      expect(activities.first.title, 'Study');
      expect(activities.first.status, ActivityStatus.upcoming);

      // 2. Perform replacement with: Project
      // Even if replacement requested a different time (e.g. 2:00 PM - 4:00 PM),
      // the existing time block strictly wins.
      final projectActivity = ScheduleActivity(
        id: 'project-456',
        title: 'Project',
        date: today,
        startTime: DateTime(2026, 9, 9, 14, 0),
        endTime: DateTime(2026, 9, 9, 16, 0),
        category: 'Projects',
        icon: '💻',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );

      await repo.replaceActivity(
        originalActivity: studyActivity,
        replacementActivity: projectActivity,
      );

      // 3. Verify exactly 1 activity exists consuming the same 1-hour block (no duplicates, no extra time)
      activities = await repo.getActivitiesForDate(today);
      expect(activities.length, 1);

      final replacementInDb = activities.first;
      expect(replacementInDb.id, 'study-123'); // Preserves activity ID reference
      expect(replacementInDb.title, 'Project');
      expect(replacementInDb.replacesActivityId, 'study-123');
      expect(replacementInDb.originalActivityTitle, 'Study');
      expect(replacementInDb.startTime, start); // 1:00 PM
      expect(replacementInDb.endTime, end);     // 2:00 PM
      expect(replacementInDb.endTime.difference(replacementInDb.startTime).inMinutes, 60);
    });

    test('Conflict handling: SmartReschedulingService does not shift or duplicate replaced activity', () async {
      final today = DateTime(2026, 9, 9);
      final start = DateTime(2026, 9, 9, 13, 0);
      final end = DateTime(2026, 9, 9, 14, 0);

      final replacedActivity = ScheduleActivity(
        id: 'study-123',
        title: 'Project',
        date: today,
        startTime: start,
        endTime: end,
        category: 'Projects',
        icon: '💻',
        replacesActivityId: 'study-123',
        originalActivityTitle: 'Study',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );

      final nextActivity = ScheduleActivity(
        id: 'exercise-789',
        title: 'Exercise',
        date: today,
        startTime: end, // 2:00 PM
        endTime: end.add(const Duration(hours: 1)), // 3:00 PM
        category: 'Wellness',
        icon: '🏃',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );

      // No conflict between replaced activity and following activity
      final conflicts = SmartReschedulingService.detectConflicts([replacedActivity, nextActivity]);
      expect(conflicts, isEmpty);

      // Resolving conflicts maintains exact 1:00 PM - 2:00 PM block
      final resolved = SmartReschedulingService.resolveConflicts([replacedActivity, nextActivity]);
      expect(resolved.first.startTime, start);
      expect(resolved.first.endTime, end);
    });

    test('addActivity ignores overlaps with replaced activities at the same scheduled time', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ScheduleRepository(prefs, userId: 'test-user-overlap');

      final today = DateTime(2026, 9, 9);
      final start = DateTime(2026, 9, 9, 14, 30);
      final end = DateTime(2026, 9, 9, 16, 30);

      final original = ScheduleActivity(
        id: 'sleep-999',
        title: 'Sleep',
        date: today,
        startTime: start,
        endTime: end,
        category: 'Rest',
        icon: '😴',
        status: ActivityStatus.replaced,
        createdAt: DateTime.now(),
      );
      await repo.addActivities([original]);

      // Adding replacement at same time should succeed because existing is replaced
      final replacement = ScheduleActivity(
        id: 'study-888',
        title: 'Study',
        date: today,
        startTime: start,
        endTime: end,
        category: 'Education',
        icon: '📚',
        replacesActivityId: 'sleep-999',
        status: ActivityStatus.upcoming,
        createdAt: DateTime.now(),
      );

      expect(() => repo.addActivity(replacement), returnsNormally);
    });
  });

  group('Area 4 & 5: Reports Model with Replaced Activities & Inspection Lists', () {
    test('DailyReportModel holds replacedActivities and inspection lists', () {
      final now = DateTime(2026, 9, 9);
      final report = DailyReportModel(
        date: now,
        plannedActivities: 5,
        completedActivities: 3,
        missedActivities: 1,
        recoveredActivities: 1,
        replacedActivities: 1,
        completionPercentage: 60.0,
        focusTimeMinutes: 120,
        routineConsistency: 85.0,
        tasksCompleted: 4,
        tasksRemaining: 2,
        plannedList: [],
        completedList: [],
        missedList: [],
        recoveredList: [],
        replacedList: [
          ScheduleActivity(
            id: 'replaced-1',
            title: 'Sleep',
            date: now,
            startTime: now,
            endTime: now.add(const Duration(hours: 2)),
            status: ActivityStatus.replaced,
            replacementActivityTitle: 'Work on Project',
            createdAt: now,
          ),
        ],
      );

      expect(report.replacedActivities, 1);
      expect(report.replacedList.length, 1);
      expect(report.replacedList.first.replacementActivityTitle, 'Work on Project');
      expect(report.replacedList.first.status, ActivityStatus.replaced);
    });

    test('WeeklyReportModel and MonthlyReportModel hold replacedActivities metrics', () {
      final now = DateTime(2026, 9, 9);
      final weekly = WeeklyReportModel(
        weekStart: now.subtract(const Duration(days: 3)),
        weekEnd: now.add(const Duration(days: 4)),
        totalPlannedHours: 35.0,
        totalCompletedHours: 28.0,
        completionRate: 80.0,
        missedTasks: 2,
        recoveredTasks: 2,
        replacedActivities: 3,
        bestDay: 'Tuesday',
        weakestDay: 'Sunday',
        mostProductiveTime: '9:00 AM – 12:00 PM',
        routineConsistency: 88.0,
        goalProgress: 75.0,
        projectProgress: 65.0,
      );

      expect(weekly.replacedActivities, 3);

      final monthly = MonthlyReportModel(
        monthStart: DateTime(2026, 9, 1),
        monthEnd: DateTime(2026, 9, 30),
        completionTrend: 82.0,
        productivityTrend: 85.0,
        routineConsistencyTrend: 88.0,
        goalProgress: 70.0,
        projectProgress: 60.0,
        strongestProductivityHours: '9:00 AM – 12:00 PM',
        weakestPeriod: 'Friday afternoon',
        improvementSuggestions: ['Keep focus intervals steady.'],
        replacedActivities: 7,
      );

      expect(monthly.replacedActivities, 7);
    });
  });
}
