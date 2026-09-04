import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/auth/data/models/auth_models.dart';
import 'package:timora/features/auth/presentation/providers/auth_provider.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/providers/cloud_sync_provider.dart';
import 'package:timora/features/cloud_sync/data/providers/mock_supabase_provider.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import 'package:timora/features/goals/data/models/goal_model.dart';
import 'package:timora/features/goals/presentation/providers/goal_provider.dart';
import 'package:timora/features/home/presentation/providers/home_provider.dart';
import 'package:timora/features/home/presentation/widgets/progress_section.dart';
import 'package:timora/features/projects/data/models/project_model.dart';
import 'package:timora/features/projects/presentation/providers/project_provider.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/routine/data/models/routine_block.dart';
import 'package:timora/features/routine/presentation/providers/routine_provider.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudSyncProvider.overrideWith((ref) => ref.watch(mockSupabaseProvider)),
        currentUserProvider.overrideWith((ref) => AuthUser(
              id: 'user_test_123',
              email: 'test@timora.com',
              name: 'Test User',
              createdAt: DateTime.now(),
            )),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group("1. Automatic Reactive Refresh Across All Related App Sections", () {
    test("Creating and completing a task updates task providers and linked goal/project progress immediately", () async {
      final taskNotifier = container.read(taskNotifierProvider);
      final goalNotifier = container.read(goalNotifierProvider);
      final projectNotifier = container.read(projectNotifierProvider);

      // Create a goal & project
      final goal = GoalModel(
        id: 'goal_1',
        title: 'Learn Flutter & Riverpod',
        progressMode: ProgressMode.auto,
        createdAt: DateTime.now(),
      );
      await goalNotifier.createGoal(goal);

      final project = ProjectModel(
        id: 'proj_1',
        title: 'Timora Architecture',
        createdAt: DateTime.now(),
      );
      await projectNotifier.createProject(project);

      // Create linked task
      final task = TaskModel(
        id: 'task_1',
        title: 'Master State Management',
        goalId: 'goal_1',
        projectId: 'proj_1',
        createdAt: DateTime.now(),
      );
      await taskNotifier.createTask(task);

      // Verify task exists in allTasksProvider
      var tasks = await container.read(allTasksProvider.future);
      expect(tasks.any((t) => t.id == 'task_1'), isTrue);

      // Verify goal progress is 0.0 (1 task, 0 completed)
      var goalProgress = await container.read(goalProgressProvider('goal_1').future);
      expect(goalProgress, 0.0);

      // Complete the task
      await taskNotifier.completeTask(task);

      // Verify task is completed
      tasks = await container.read(allTasksProvider.future);
      expect(tasks.firstWhere((t) => t.id == 'task_1').isCompleted, isTrue);

      // Verify goal progress automatically recalculated to 100% (1 of 1 completed)
      goalProgress = await container.read(goalProgressProvider('goal_1').future);
      expect(goalProgress, 1.0);

      // Verify project progress automatically recalculated to 100%
      final projProgress = await container.read(projectProgressProvider('proj_1').future);
      expect(projProgress, 1.0);
    });

    test("Creating and updating routines refreshes routine providers and schedule immediately", () async {
      final routineNotifier = container.read(routineNotifierProvider);

      final routine = Routine(
        id: 'routine_morning',
        name: 'Morning Power Routine',
        icon: '☀️',
        color: const Color(0xFFF59E0B),
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        createdAt: DateTime.now(),
      );

      final block = RoutineBlock(
        id: 'block_meditate',
        routineId: 'routine_morning',
        title: 'Meditation & Breathwork',
        startTime: const TimeOfDay(hour: 6, minute: 30),
        endTime: const TimeOfDay(hour: 7, minute: 0),
        category: 'Health',
        icon: '🧘',
        color: const Color(0xFF10B981),
        order: 0,
      );

      await routineNotifier.addRoutine(routine, [block]);

      final routines = await container.read(routinesProvider.future);
      expect(routines.any((r) => r.id == 'routine_morning'), isTrue);

      final blocks = await container.read(routineBlocksProvider('routine_morning').future);
      expect(blocks.length, 1);
      expect(blocks.first.title, 'Meditation & Breathwork');

      // Update block
      final updatedBlock = block.copyWith(title: 'Deep Meditation & Stretch');
      await routineNotifier.updateRoutineBlock(updatedBlock);

      final updatedBlocks = await container.read(routineBlocksProvider('routine_morning').future);
      expect(updatedBlocks.first.title, 'Deep Meditation & Stretch');
    });
  });

  group("2. Today's Progress Percentage Calculation & Display", () {
    final today = DateTime.now();

    final List<ScheduleActivity> baseActivities = [
      ScheduleActivity(
        id: 'act_1',
        title: 'Morning Yoga',
        description: 'Yoga session',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 7, 0),
        endTime: DateTime(today.year, today.month, today.day, 8, 0),
        category: 'Health',
        icon: '🧘',
        color: const Color(0xFF10B981),
        status: ActivityStatus.upcoming,
        createdAt: today,
      ),
      ScheduleActivity(
        id: 'act_2',
        title: 'Deep Work',
        description: 'Focus block',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 9, 0),
        endTime: DateTime(today.year, today.month, today.day, 12, 0),
        category: 'Work',
        icon: '💻',
        color: const Color(0xFF2563EB),
        status: ActivityStatus.upcoming,
        createdAt: today,
      ),
      ScheduleActivity(
        id: 'act_3',
        title: 'Evening Run',
        description: 'Cardio workout',
        date: today,
        startTime: DateTime(today.year, today.month, today.day, 18, 0),
        endTime: DateTime(today.year, today.month, today.day, 19, 0),
        category: 'Health',
        icon: '🏃',
        color: const Color(0xFF10B981),
        status: ActivityStatus.upcoming,
        createdAt: today,
      ),
    ];

    final List<TaskModel> baseTasks = [
      TaskModel(
        id: 'task_t1',
        title: 'Prepare presentation',
        dueDate: today,
        status: TaskStatus.pending,
        createdAt: today,
      ),
      TaskModel(
        id: 'task_t2',
        title: 'Review PRs',
        dueDate: today,
        status: TaskStatus.pending,
        createdAt: today,
      ),
    ];

    testWidgets("0 completed out of 5 total displays 0%", (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('case_0_pct'),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            dailyScheduleProvider.overrideWith((ref) => Future<List<ScheduleActivity>>.value(baseActivities)),
            todayTasksProvider.overrideWith((ref) => Future<List<TaskModel>>.value(baseTasks)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProgressSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0%'), findsWidgets);
    });

    testWidgets("1 completed out of 5 total (1 activity) displays 20% overall", (tester) async {
      final List<ScheduleActivity> activitiesWith1Completed = [
        baseActivities[0].copyWith(status: ActivityStatus.completed),
        baseActivities[1],
        baseActivities[2],
      ];

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('case_20_pct'),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            dailyScheduleProvider.overrideWith((ref) => Future<List<ScheduleActivity>>.value(activitiesWith1Completed)),
            todayTasksProvider.overrideWith((ref) => Future<List<TaskModel>>.value(baseTasks)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProgressSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('20%'), findsOneWidget); // Overall is 1/5 = 20%
    });

    testWidgets("2 completed out of 5 total (1 activity + 1 task) displays 40% overall", (tester) async {
      final List<ScheduleActivity> activitiesWith1Completed = [
        baseActivities[0].copyWith(status: ActivityStatus.completed),
        baseActivities[1],
        baseActivities[2],
      ];
      final List<TaskModel> tasksWith1Completed = [
        baseTasks[0].copyWith(status: TaskStatus.completed),
        baseTasks[1],
      ];

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('case_40_pct'),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            dailyScheduleProvider.overrideWith((ref) => Future<List<ScheduleActivity>>.value(activitiesWith1Completed)),
            todayTasksProvider.overrideWith((ref) => Future<List<TaskModel>>.value(tasksWith1Completed)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProgressSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('40%'), findsOneWidget); // Overall is 2/5 = 40%
    });

    testWidgets("All 5 completed displays 100%", (tester) async {
      final List<ScheduleActivity> allCompletedActivities = baseActivities.map((a) => a.copyWith(status: ActivityStatus.completed)).toList();
      final List<TaskModel> allCompletedTasks = baseTasks.map((t) => t.copyWith(status: TaskStatus.completed)).toList();

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('case_100_pct'),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            dailyScheduleProvider.overrideWith((ref) => Future<List<ScheduleActivity>>.value(allCompletedActivities)),
            todayTasksProvider.overrideWith((ref) => Future<List<TaskModel>>.value(allCompletedTasks)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProgressSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsWidgets);
    });
  });

  group("3. Offline Actions & Persistent Queueing", () {
    test("Multiple offline actions are preserved in persistent queue across restarts", () async {
      final syncRepo = container.read(syncRepositoryProvider);

      // Perform multiple offline actions
      await syncRepo.enqueueChange(
        entityType: 'routines',
        entityId: 'routine_offline_1',
        operation: SyncOperation.create,
      );
      await syncRepo.enqueueChange(
        entityType: 'tasks',
        entityId: 'task_offline_2',
        operation: SyncOperation.create,
      );
      await syncRepo.enqueueChange(
        entityType: 'goals',
        entityId: 'goal_offline_3',
        operation: SyncOperation.create,
      );
      await syncRepo.enqueueChange(
        entityType: 'tasks',
        entityId: 'task_offline_2',
        operation: SyncOperation.update,
      );

      var pending = await syncRepo.getPendingItems();
      expect(pending.length, 3); // Deduplicated task update

      // Simulate App Restart by creating a new repository with the same SharedPreferences
      final reloadedRepo = SyncRepository(prefs, userId: 'user_test_123');
      final reloadedPending = await reloadedRepo.getPendingItems();

      expect(reloadedPending.length, 3);
      expect(reloadedPending.any((p) => p.entityId == 'routine_offline_1'), isTrue);
      expect(reloadedPending.any((p) => p.entityId == 'task_offline_2'), isTrue);
      expect(reloadedPending.any((p) => p.entityId == 'goal_offline_3'), isTrue);
    });

    test("Deleting a pending-creation item removes it from the offline queue entirely", () async {
      final syncRepo = container.read(syncRepositoryProvider);

      await syncRepo.enqueueChange(
        entityType: 'tasks',
        entityId: 'temp_task_99',
        operation: SyncOperation.create,
      );

      var pending = await syncRepo.getPendingItems();
      expect(pending.length, 1);

      // Delete the unpushed item
      await syncRepo.enqueueChange(
        entityType: 'tasks',
        entityId: 'temp_task_99',
        operation: SyncOperation.delete,
      );

      pending = await syncRepo.getPendingItems();
      expect(pending.isEmpty, isTrue);
    });
  });

  group("4. Cloud Synchronization, Bi-Directional Sync & Online Recovery", () {
    test("When online, pending changes upload automatically to cloud and clear queue", () async {
      final mockCloud = container.read(mockSupabaseProvider);
      final syncService = container.read(syncServiceProvider);
      final syncRepo = container.read(syncRepositoryProvider);
      final taskNotifier = container.read(taskNotifierProvider);

      // Setup Cloud User
      mockCloud.setCurrentUser(CloudAccount(
        userId: 'user_test_123',
        email: 'test@timora.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        syncEnabled: true,
      ));

      // Create a task
      final task = TaskModel(
        id: 'cloud_sync_task_1',
        title: 'Verify Cloud Sync Upload',
        createdAt: DateTime.now(),
      );
      await taskNotifier.createTask(task);

      // Perform sync
      await syncService.syncNow();

      // Verify item was uploaded to cloud database
      final cloudRecord = mockCloud.getCloudRecord('cloud_sync_task_1');
      expect(cloudRecord, isNotNull);
      expect(cloudRecord!['title'], 'Verify Cloud Sync Upload');

      // Verify pending queue is now empty
      final pending = await syncRepo.getPendingItems();
      expect(pending.isEmpty, isTrue);
    });

    test("Failed network sync retains pending items with retry counts without data loss", () async {
      final mockCloud = container.read(mockSupabaseProvider);
      final syncService = container.read(syncServiceProvider);
      final syncRepo = container.read(syncRepositoryProvider);
      final taskNotifier = container.read(taskNotifierProvider);

      mockCloud.setCurrentUser(CloudAccount(
        userId: 'user_test_123',
        email: 'test@timora.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        syncEnabled: true,
      ));

      final task = TaskModel(
        id: 'retry_task_1',
        title: 'Task before network outage',
        createdAt: DateTime.now(),
      );
      await taskNotifier.createTask(task);

      // Simulate offline / network failure
      mockCloud.setOffline(true);

      await syncService.syncNow();

      // Check that sync status is failed
      expect(container.read(globalSyncStatusProvider), SyncStatus.failed);

      // Check that items remain in queue with incremented retry count
      final pending = await syncRepo.getPendingItems();
      expect(pending.length, 1);
      expect(pending.first.retryCount, greaterThanOrEqualTo(1));

      // Now simulate internet returning
      mockCloud.setOffline(false);

      await syncService.syncNow();

      // Verify successful sync and cleared queue
      expect(container.read(globalSyncStatusProvider), SyncStatus.synced);
      final clearedPending = await syncRepo.getPendingItems();
      expect(clearedPending.isEmpty, isTrue);
    });
  });
}
