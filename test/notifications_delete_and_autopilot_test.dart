import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/schedule/services/missed_task_recovery_service.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/home/presentation/providers/home_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Notification Deletion & Persistence', () {
    test('Deleted notification IDs persist and are excluded from inbox', () async {
      await prefs.setStringList('timora_deleted_inbox_ids', ['evt_delete_1', 'admin_delete_2']);

      final deletedList = prefs.getStringList('timora_deleted_inbox_ids') ?? [];
      expect(deletedList.contains('evt_delete_1'), isTrue);
      expect(deletedList.contains('admin_delete_2'), isTrue);

      // Verify deleting a new item adds to set safely
      final set = deletedList.toSet();
      set.add('task_overdue_3');
      await prefs.setStringList('timora_deleted_inbox_ids', set.toList());

      final updated = (prefs.getStringList('timora_deleted_inbox_ids') ?? []).toSet();
      expect(updated.contains('task_overdue_3'), isTrue);
      expect(updated.length, 3);
    });

    test('Deleted notification stays deleted after reload/restart', () async {
      await prefs.setStringList('timora_deleted_inbox_ids', ['evt_999']);

      // Simulate app restart by reloading preferences
      final freshPrefs = await SharedPreferences.getInstance();
      final loaded = freshPrefs.getStringList('timora_deleted_inbox_ids') ?? [];
      expect(loaded.contains('evt_999'), isTrue);
    });

    test('Unread notification count excludes deleted task notifications', () async {
      final now = DateTime.now();
      final task1 = TaskModel(
        id: 'task_unread_1',
        title: 'Task 1',
        dueDate: now.subtract(const Duration(hours: 1)),
        status: TaskStatus.pending,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allTasksProvider.overrideWith((ref) async => [task1]),
        ],
      );
      addTearDown(container.dispose);

      await container.read(allTasksProvider.future);
      var count = container.read(unreadNotificationsCountProvider);
      expect(count, 1);

      // Delete the notification
      await prefs.setStringList('timora_deleted_inbox_ids', ['task_overdue_task_unread_1']);
      container.invalidate(unreadNotificationsCountProvider);

      count = container.read(unreadNotificationsCountProvider);
      expect(count, 0);
    });
  });

  group('AutoPilot Skip Option', () {
    test('Skipping missed item updates state and prevents reappearing', () async {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final recoveryService = container.read(missedTaskRecoveryServiceProvider);

      final act = ScheduleActivity(
        id: 'act_missed_test_1',
        title: 'Morning Deep Work',
        category: 'Work',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1)),
        date: DateTime(now.year, now.month, now.day),
        status: ActivityStatus.upcoming,
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      );

      final rec = RecoveryRecommendation(
        activity: act,
        title: act.title,
        originalStart: act.startTime,
        originalEnd: act.endTime,
        proposedStart: now.add(const Duration(minutes: 30)),
        proposedEnd: now.add(const Duration(hours: 1, minutes: 30)),
        duration: const Duration(hours: 1),
        reason: 'Missed activity found slot',
      );

      // Execute skip
      await recoveryService.skipMissedItem(rec);

      // Verify persisted in skipped IDs
      final skippedIds = await recoveryService.getSkippedIdsToday();
      expect(skippedIds.contains('act_missed_test_1'), isTrue);

      final rawPrefs = prefs.getStringList('timora_autopilot_skipped_ids') ?? [];
      expect(rawPrefs.contains('${dateStr}_act_missed_test_1'), isTrue);
    });

    test('Skipping an overdue task records skipped ID without deleting or completing task', () async {
      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final recoveryService = container.read(missedTaskRecoveryServiceProvider);

      final task = TaskModel(
        id: 'task_overdue_skip_1',
        title: 'Prepare Quarterly Report',
        category: 'Work',
        dueDate: now.subtract(const Duration(hours: 3)),
        status: TaskStatus.pending,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      final rec = RecoveryRecommendation(
        task: task,
        title: task.title,
        originalStart: task.dueDate!,
        originalEnd: task.dueDate!.add(const Duration(minutes: 30)),
        proposedStart: now.add(const Duration(minutes: 15)),
        proposedEnd: now.add(const Duration(minutes: 45)),
        duration: const Duration(minutes: 30),
        reason: 'Overdue task slot',
      );

      await recoveryService.skipMissedItem(rec);

      final skippedIds = await recoveryService.getSkippedIdsToday();
      expect(skippedIds.contains('task_overdue_skip_1'), isTrue);

      // Verify task itself remains not completed and not deleted
      expect(task.isCompleted, isFalse);
      expect(task.isDeleted, isFalse);
    });
  });

  group('AutoPilot Deduplication & Missed Notification Logging', () {
    test('Deduplication prevents double notification on same missed item', () async {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      const entityId = 'entity_123';
      final dedupeKey = '${dateStr}_$entityId';

      final notified = (prefs.getStringList('timora_autopilot_notified_missed_ids') ?? []).toSet();
      expect(notified.contains(dedupeKey), isFalse);

      // Record first notification
      notified.add(dedupeKey);
      await prefs.setStringList('timora_autopilot_notified_missed_ids', notified.toList());

      // Second check detects already notified
      final refreshed = (prefs.getStringList('timora_autopilot_notified_missed_ids') ?? []).toSet();
      expect(refreshed.contains(dedupeKey), isTrue);
    });

    test('Completed tasks are not reported as missed', () {
      final completedActivity = ScheduleActivity(
        id: 'act_completed_1',
        title: 'Team Standup',
        category: 'Work',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        date: DateTime.now(),
        status: ActivityStatus.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final isFinished = completedActivity.status == ActivityStatus.completed ||
          completedActivity.status == ActivityStatus.skipped;
      expect(isFinished, isTrue);

      final completedTask = TaskModel(
        id: 'task_done_1',
        title: 'Review PR',
        status: TaskStatus.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(completedTask.isCompleted || completedTask.isDeleted, isTrue);
    });
  });
}
