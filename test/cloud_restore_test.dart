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
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/routine/data/models/routine_block.dart';
import 'package:timora/features/routine/data/repositories/routine_repository.dart';
import 'package:timora/features/daily_plan/data/models/daily_plan_model.dart';
import 'package:timora/features/daily_plan/data/repositories/daily_plan_repository.dart';
import 'package:timora/features/habits/data/models/habit_log_model.dart';
import 'package:timora/features/habits/data/repositories/habit_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Timora Cloud Restoration & Two-Way Sync Verification', () {
    test('Uninstall/Reinstall: Empty local storage restores all cloud data without overwriting cloud', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockCloud = MockSupabaseProvider();
      final now = DateTime.now();

      mockCloud.setCurrentUser(CloudAccount(
        userId: 'user_account_a',
        email: 'account_a@timora.com',
        displayName: 'Account A',
        createdAt: now,
        syncEnabled: true,
        backupEnabled: true,
      ));

      // Seed cloud database with Account A data (as if it was created before uninstall)
      await mockCloud.pushChanges([
        SyncQueueItem(
          id: 'q1',
          entityType: 'routines',
          entityId: 'routine_cloud_1',
          operation: SyncOperation.create,
          createdAt: now,
          updatedAt: now,
        ),
        SyncQueueItem(
          id: 'q2',
          entityType: 'routine_blocks',
          entityId: 'block_cloud_1',
          operation: SyncOperation.create,
          createdAt: now,
          updatedAt: now,
        ),
        SyncQueueItem(
          id: 'q3',
          entityType: 'tasks',
          entityId: 'task_cloud_1',
          operation: SyncOperation.create,
          createdAt: now,
          updatedAt: now,
        ),
        SyncQueueItem(
          id: 'q4',
          entityType: 'daily_plans',
          entityId: 'plan_cloud_1',
          operation: SyncOperation.create,
          createdAt: now,
          updatedAt: now,
        ),
      ], {
        'routine_cloud_1': Routine(
          id: 'routine_cloud_1',
          name: 'Morning Power Routine',
          daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
          createdAt: now,
          updatedAt: now,
        ).toJson(),
        'block_cloud_1': RoutineBlock(
          id: 'block_cloud_1',
          routineId: 'routine_cloud_1',
          title: 'Deep Meditation',
          startTime: const TimeOfDay(hour: 7, minute: 0),
          endTime: const TimeOfDay(hour: 7, minute: 20),
          category: 'Health',
          icon: '🧘',
          order: 0,
        ).toJson(),
        'task_cloud_1': TaskModel(
          id: 'task_cloud_1',
          title: 'Complete Master Architecture',
          createdAt: now,
          updatedAt: now,
        ).toJson(),
        'plan_cloud_1': DailyPlanModel(
          id: 'plan_cloud_1',
          date: DateTime(now.year, now.month, now.day),
          plannedDurationSeconds: 7200,
          completedDurationSeconds: 3600,
          createdAt: now,
          updatedAt: now,
        ).toJson(),
      });

      // Now create a fresh installation container (simulating reinstall / new device)
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudSyncProvider.overrideWithValue(mockCloud),
          currentUserProvider.overrideWith((ref) => AuthUser(
                id: 'user_account_a',
                email: 'account_a@timora.com',
                name: 'Account A',
                createdAt: now,
              )),
        ],
      );

      // Verify local storage is completely empty before restore
      final taskRepo = container.read(taskRepositoryProvider);
      final routineRepo = container.read(routineRepositoryProvider);
      final dailyPlanRepo = container.read(dailyPlanRepositoryProvider);

      expect(await taskRepo.getTasks(), isEmpty);
      expect(await routineRepo.getAllRoutines(), isEmpty);
      expect(await dailyPlanRepo.getAllPlans(), isEmpty);

      // Perform full automatic restoration (called on login / startup)
      final syncService = container.read(syncServiceProvider);
      await syncService.fullRestore();

      // Verify cloud data is downloaded into local storage
      final tasks = await taskRepo.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Complete Master Architecture');

      final routines = await routineRepo.getAllRoutines();
      expect(routines.length, 1);
      expect(routines.first.name, 'Morning Power Routine');
      final blocks = await routineRepo.getBlocksForRoutine('routine_cloud_1');
      expect(blocks.length, 1);
      expect(blocks.first.title, 'Deep Meditation');

      final plans = await dailyPlanRepo.getAllPlans();
      expect(plans.length, 1);
      expect(plans.first.plannedDurationSeconds, 7200);

      // CRITICAL CHECK: Verify cloud database was NOT overwritten or wiped by empty local state
      final cloudRecords = await mockCloud.pullChanges(null);
      expect(cloudRecords.containsKey('task_cloud_1'), isTrue);
      expect(cloudRecords.containsKey('routine_cloud_1'), isTrue);
      expect(cloudRecords.containsKey('block_cloud_1'), isTrue);
      expect(cloudRecords.containsKey('plan_cloud_1'), isTrue);

      container.dispose();
    });

    test('Multi-Account Isolation: Account B sees zero data from Account A', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockCloudA = MockSupabaseProvider();
      final now = DateTime.now();

      mockCloudA.setCurrentUser(CloudAccount(
        userId: 'user_account_a',
        email: 'account_a@timora.com',
        displayName: 'Account A',
        createdAt: now,
        syncEnabled: true,
        backupEnabled: true,
      ));

      // Account A logs in and creates a task
      final containerA = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudSyncProvider.overrideWithValue(mockCloudA),
          currentUserProvider.overrideWith((ref) => AuthUser(
                id: 'user_account_a',
                email: 'account_a@timora.com',
                name: 'Account A',
                createdAt: now,
              )),
        ],
      );

      final taskNotifierA = containerA.read(taskNotifierProvider);
      await taskNotifierA.createTask(TaskModel(
        id: 'task_user_a',
        title: 'Secret Task A',
        createdAt: now,
      ));

      // Auto-sync pushes to cloud
      final syncA = containerA.read(syncServiceProvider);
      await syncA.syncNow();

      final tasksA = await containerA.read(taskRepositoryProvider).getTasks();
      expect(tasksA.length, 1);
      containerA.dispose();

      // Account B logs in on the same device with a separate cloud database
      final mockCloudB = MockSupabaseProvider();
      mockCloudB.setCurrentUser(CloudAccount(
        userId: 'user_account_b',
        email: 'account_b@timora.com',
        displayName: 'Account B',
        createdAt: now,
        syncEnabled: true,
        backupEnabled: true,
      ));

      final containerB = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudSyncProvider.overrideWithValue(mockCloudB),
          currentUserProvider.overrideWith((ref) => AuthUser(
                id: 'user_account_b',
                email: 'account_b@timora.com',
                name: 'Account B',
                createdAt: now,
              )),
        ],
      );

      final syncB = containerB.read(syncServiceProvider);
      await syncB.fullRestore();

      // Account B must NOT see Account A tasks
      final taskRepoB = containerB.read(taskRepositoryProvider);
      expect(await taskRepoB.getTasks(), isEmpty);

      containerB.dispose();
    });

    test('Automatic Two-Way Sync: Habit log pushes and pulls correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockCloud = MockSupabaseProvider();
      final now = DateTime.now();

      mockCloud.setCurrentUser(CloudAccount(
        userId: 'user_test_habits',
        email: 'habits@timora.com',
        displayName: 'Habit User',
        createdAt: now,
        syncEnabled: true,
        backupEnabled: true,
      ));

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudSyncProvider.overrideWithValue(mockCloud),
          currentUserProvider.overrideWith((ref) => AuthUser(
                id: 'user_test_habits',
                email: 'habits@timora.com',
                name: 'Habit User',
                createdAt: now,
              )),
        ],
      );

      final habitRepo = container.read(habitRepositoryProvider);
      final syncService = container.read(syncServiceProvider);

      final log = HabitLogModel(
        id: 'log_1',
        habitId: 'habit_1',
        logDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      );
      await habitRepo.saveHabitLog(log);
      await container.read(syncRepositoryProvider).enqueueChange(
        entityType: 'habit_logs',
        entityId: 'log_1',
        operation: SyncOperation.create,
      );

      // Perform sync
      await syncService.syncNow();

      final cloudRecords = await mockCloud.pullChanges(null);
      expect(cloudRecords.containsKey('log_1'), isTrue);

      container.dispose();
    });
  });
}
