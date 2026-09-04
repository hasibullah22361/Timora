import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/connectivity_service.dart';
import '../data/models/cloud_models.dart';
import '../data/providers/cloud_sync_provider.dart';
import '../data/repositories/sync_repository.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/models/subtask_model.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../routine/presentation/providers/routine_provider.dart';
import '../../routine/data/models/routine.dart';
import '../../routine/data/models/routine_block.dart';
import '../../routine/data/repositories/routine_repository.dart';
import '../../schedule/presentation/providers/schedule_provider.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../schedule/data/repositories/schedule_repository.dart';
import '../../goals/presentation/providers/goal_provider.dart';
import '../../goals/data/models/goal_model.dart';
import '../../goals/data/models/milestone_model.dart';
import '../../goals/data/repositories/goal_repository.dart';
import '../../projects/presentation/providers/project_provider.dart';
import '../../projects/data/models/project_model.dart';
import '../../projects/data/repositories/project_repository.dart';
import '../../profile/presentation/providers/user_profile_provider.dart';
import '../../profile/data/models/user_profile.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../settings/data/models/settings_models.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../../diary/data/models/diary_entry_model.dart';
import '../../diary/data/repositories/diary_repository.dart';
import '../../habits/presentation/providers/habit_provider.dart';
import '../../habits/data/models/habit_model.dart';
import '../../habits/data/repositories/habit_repository.dart';
import '../../daily_plan/data/models/daily_plan_model.dart';
import '../../daily_plan/data/models/planned_task_block_model.dart';
import '../../daily_plan/data/repositories/daily_plan_repository.dart';
import '../../weekly_plan/data/models/weekly_plan_model.dart';
import '../../weekly_plan/data/repositories/weekly_plan_repository.dart';
import '../../monthly_plan/data/models/monthly_plan_model.dart';
import '../../monthly_plan/data/repositories/monthly_plan_repository.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

final globalSyncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.offline);

class SyncService {
  final Ref _ref;
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  RealtimeChannel? _realtimeChannel;
  String? _currentSubscribedUserId;
  StreamSubscription? _connectivitySubscription;

  SyncService(this._ref) {
    _startPeriodicSync();
    _checkAndInitRealtime();
    _listenToConnectivity();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      autoSync();
    });
  }

  void _checkAndInitRealtime() async {
    try {
      final provider = _ref.read(cloudSyncProvider);
      final user = await provider.getCurrentUser();
      if (user != null && user.userId.isNotEmpty) {
        _subscribeRealtime(user.userId);
      }
    } catch (_) {}
  }

  void _subscribeRealtime(String userId) {
    if (_currentSubscribedUserId == userId && _realtimeChannel != null) {
      return;
    }

    _unsubscribeRealtime();

    try {
      final client = Supabase.instance.client;
      _currentSubscribedUserId = userId;
      
      _realtimeChannel = client.channel('public:timora_realtime_$userId');
      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            callback: (payload) {
              _handleRealtimeEvent(payload);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime subscription notice: $e');
    }
  }

  void _unsubscribeRealtime() {
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
      _currentSubscribedUserId = null;
    }
  }

  void _handleRealtimeEvent(PostgresChangePayload payload) {
    // When a change is detected on Supabase, trigger a pull to merge changes locally
    autoSync();
  }

  void dispose() {
    _periodicSyncTimer?.cancel();
    _unsubscribeRealtime();
    _connectivitySubscription?.cancel();
  }

  /// Listens to connectivity changes. When connection returns, triggers sync.
  void _listenToConnectivity() {
    try {
      final connectivityService = _ref.read(connectivityServiceProvider);
      _connectivitySubscription = connectivityService.statusStream.listen((status) {
        if (status == ConnectivityStatus.online) {
          debugPrint('[Sync] Connection restored, triggering sync...');
          autoSync();
        } else {
          _ref.read(globalSyncStatusProvider.notifier).state = SyncStatus.offline;
        }
      });
    } catch (e) {
      debugPrint('[Sync] Connectivity listener notice: $e');
    }
  }

  Future<void> autoSync() async {
    final syncRepo = _ref.read(syncRepositoryProvider);
    final pending = await syncRepo.getPendingItems();
    if (pending.isEmpty) return;
    
    // Attempt sync
    try {
      await syncNow();
    } catch (_) {
      // Ignored for auto-sync; error status handled in syncNow
    }
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final statusNotifier = _ref.read(globalSyncStatusProvider.notifier);
    statusNotifier.state = SyncStatus.syncing;
    
    try {
      final provider = _ref.read(cloudSyncProvider);
      final user = await provider.getCurrentUser();
      
      if (user == null || !user.syncEnabled) {
        statusNotifier.state = SyncStatus.offline;
        _isSyncing = false;
        return;
      }

      // Ensure realtime is connected for this user
      _subscribeRealtime(user.userId);

      await _pushChanges();
      await _pullChanges();
      
      statusNotifier.state = SyncStatus.synced;
    } catch (e) {
      statusNotifier.state = SyncStatus.failed;
      debugPrint('Sync Notice/Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushChanges() async {
    final syncRepo = _ref.read(syncRepositoryProvider);
    final provider = _ref.read(cloudSyncProvider);
    
    final pending = await syncRepo.getPendingItems();
    if (pending.isEmpty) return;

    final payloads = <String, dynamic>{};
    
    // Extract repositories
    final taskRepo = _ref.read(taskRepositoryProvider);
    final routineRepo = _ref.read(routineRepositoryProvider);
    final scheduleRepo = _ref.read(scheduleRepositoryProvider);
    final goalRepo = _ref.read(goalRepositoryProvider);
    final projectRepo = _ref.read(projectRepositoryProvider);
    final profileRepo = _ref.read(userProfileRepositoryProvider);
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final diaryRepo = _ref.read(diaryRepositoryProvider);
    final habitRepo = _ref.read(habitRepositoryProvider);
    final dailyPlanRepo = _ref.read(dailyPlanRepositoryProvider);
    final weeklyPlanRepo = _ref.read(weeklyPlanRepositoryProvider);
    final monthlyPlanRepo = _ref.read(monthlyPlanRepositoryProvider);

    // Preload datasets
    final tasks = await taskRepo.getTasks();
    final subtasks = await taskRepo.getAllSubtasks();
    final routines = await routineRepo.getAllRoutines();
    final blocks = await routineRepo.getAllBlocks();
    final activities = await scheduleRepo.getAllActivities();
    final goals = await goalRepo.getGoals();
    final milestones = await goalRepo.getAllMilestones();
    final projects = await projectRepo.getProjects();
    final profile = profileRepo.loadProfile();
    final settings = settingsRepo.loadSettings();
    final diaryEntries = await diaryRepo.getAllEntries();
    final habits = await habitRepo.getHabits();

    for (var item in pending) {
      if (item.operation == SyncOperation.delete) continue;

      switch (item.entityType) {
        case 'tasks':
          final t = tasks.where((x) => x.id == item.entityId).firstOrNull;
          if (t != null) payloads[item.entityId] = t.toJson();
          break;
        case 'subtasks':
          final s = subtasks.where((x) => x.id == item.entityId).firstOrNull;
          if (s != null) payloads[item.entityId] = s.toJson();
          break;
        case 'routines':
          final r = routines.where((x) => x.id == item.entityId).firstOrNull;
          if (r != null) payloads[item.entityId] = r.toJson();
          break;
        case 'routine_blocks':
          final b = blocks.where((x) => x.id == item.entityId).firstOrNull;
          if (b != null) payloads[item.entityId] = b.toJson();
          break;
        case 'schedule_activities':
          final a = activities.where((x) => x.id == item.entityId).firstOrNull;
          if (a != null) payloads[item.entityId] = a.toJson();
          break;
        case 'goals':
          final g = goals.where((x) => x.id == item.entityId).firstOrNull;
          if (g != null) payloads[item.entityId] = g.toJson();
          break;
        case 'milestones':
          final m = milestones.where((x) => x.id == item.entityId).firstOrNull;
          if (m != null) payloads[item.entityId] = m.toJson();
          break;
        case 'projects':
          final p = projects.where((x) => x.id == item.entityId).firstOrNull;
          if (p != null) payloads[item.entityId] = p.toJson();
          break;
        case 'user_profile':
          payloads[item.entityId] = profile.toJson();
          break;
        case 'settings':
          payloads[item.entityId] = settings.toJson();
          break;
        case 'diary_entries':
          final d = diaryEntries.where((x) => x.id == item.entityId).firstOrNull;
          if (d != null) payloads[item.entityId] = d.toJson();
          break;
        case 'habits':
          final h = habits.where((x) => x.id == item.entityId).firstOrNull;
          if (h != null) payloads[item.entityId] = h.toJson();
          break;
        case 'daily_plans':
          final dp = await dailyPlanRepo.getPlanForDate(DateTime.now());
          if (dp != null && dp.id == item.entityId) payloads[item.entityId] = dp.toJson();
          break;
        case 'weekly_plans':
          final wp = await weeklyPlanRepo.getPlanForWeek(DateTime.now());
          if (wp != null && wp.id == item.entityId) payloads[item.entityId] = wp.toJson();
          break;
        case 'monthly_plans':
          final mp = await monthlyPlanRepo.getPlanForMonth(DateTime.now().year, DateTime.now().month);
          if (mp != null && mp.id == item.entityId) payloads[item.entityId] = mp.toJson();
          break;
      }
    }

    try {
      await provider.pushChanges(pending, payloads);
      // On success, mark items synced
      for (var item in pending) {
        await syncRepo.markItemSynced(item.id);
      }
    } catch (e) {
      for (var item in pending) {
        await syncRepo.markItemFailed(item.id, e.toString());
      }
      rethrow;
    }
  }

  Future<void> _pullChanges() async {
    final provider = _ref.read(cloudSyncProvider);
    final syncRepo = _ref.read(syncRepositoryProvider);
    final changes = await provider.pullChanges(null);
    
    if (changes.isEmpty) return;

    final taskRepo = _ref.read(taskRepositoryProvider);
    final routineRepo = _ref.read(routineRepositoryProvider);
    final scheduleRepo = _ref.read(scheduleRepositoryProvider);
    final goalRepo = _ref.read(goalRepositoryProvider);
    final projectRepo = _ref.read(projectRepositoryProvider);
    final profileRepo = _ref.read(userProfileRepositoryProvider);
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final diaryRepo = _ref.read(diaryRepositoryProvider);
    final habitRepo = _ref.read(habitRepositoryProvider);
    final dailyPlanRepo = _ref.read(dailyPlanRepositoryProvider);
    final weeklyPlanRepo = _ref.read(weeklyPlanRepositoryProvider);
    final monthlyPlanRepo = _ref.read(monthlyPlanRepositoryProvider);

    for (var entry in changes.entries) {
      final id = entry.key;
      final record = entry.value;
      
      final isDeleted = record['_deletedAt'] != null;
      final entityType = record['_entityType'] as String? ?? 'tasks';
      final serverUpdatedAt = record['_serverUpdatedAt'] != null
          ? DateTime.parse(record['_serverUpdatedAt'] as String)
          : DateTime.now();

      final localMeta = await syncRepo.getMetadata(id);
      
      // Conflict Resolution: Last-Write-Wins
      if (localMeta != null && localMeta.localUpdatedAt.isAfter(serverUpdatedAt)) {
        // Local is newer. Ignore server change for now; it will push in next cycle.
        continue;
      }

      // Apply server change locally
      switch (entityType) {
        case 'tasks':
          if (isDeleted) {
            await taskRepo.deleteTask(id);
          } else {
            final task = TaskModel.fromJson(record);
            final existing = await taskRepo.getTask(id);
            if (existing != null) {
              await taskRepo.updateTask(task);
            } else {
              await taskRepo.createTask(task);
            }
          }
          break;

        case 'subtasks':
          if (isDeleted) {
            await taskRepo.deleteSubtask(id);
          } else {
            final subtask = SubtaskModel.fromJson(record);
            await taskRepo.createSubtask(subtask);
          }
          break;

        case 'routines':
          if (isDeleted) {
            await routineRepo.deleteRoutine(id);
          } else {
            final routine = Routine.fromJson(record);
            await routineRepo.updateRoutine(routine);
          }
          break;

        case 'routine_blocks':
          if (isDeleted) {
            await routineRepo.deleteRoutineBlock(id);
          } else {
            final block = RoutineBlock.fromJson(record);
            await routineRepo.updateRoutineBlock(block);
          }
          break;

        case 'schedule_activities':
          if (isDeleted) {
            await scheduleRepo.deleteActivity(id);
          } else {
            final act = ScheduleActivity.fromJson(record);
            await scheduleRepo.updateActivity(act);
          }
          break;

        case 'goals':
          if (isDeleted) {
            await goalRepo.deleteGoal(id);
          } else {
            final goal = GoalModel.fromJson(record);
            final existing = await goalRepo.getGoal(id);
            if (existing != null) {
              await goalRepo.updateGoal(goal);
            } else {
              await goalRepo.createGoal(goal);
            }
          }
          break;

        case 'milestones':
          if (isDeleted) {
            await goalRepo.deleteMilestone(id);
          } else {
            final milestone = MilestoneModel.fromJson(record);
            await goalRepo.updateMilestone(milestone);
          }
          break;

        case 'projects':
          if (isDeleted) {
            await projectRepo.deleteProject(id);
          } else {
            final project = ProjectModel.fromJson(record);
            final existing = await projectRepo.getProject(id);
            if (existing != null) {
              await projectRepo.updateProject(project);
            } else {
              await projectRepo.createProject(project);
            }
          }
          break;

        case 'user_profile':
          if (!isDeleted) {
            final profile = UserProfile.fromJson(record);
            await profileRepo.saveProfile(profile);
          }
          break;

        case 'settings':
          if (!isDeleted) {
            final settings = AppSettings.fromJson(record);
            await settingsRepo.saveSettings(settings);
          }
          break;

        case 'diary_entries':
          if (isDeleted) {
            await diaryRepo.deleteEntry(id);
          } else {
            final diaryEntry = DiaryEntryModel.fromSupabaseMap(record);
            await diaryRepo.saveEntry(diaryEntry);
          }
          break;

        case 'habits':
          if (isDeleted) {
            await habitRepo.deleteHabit(id);
          } else {
            final habit = HabitModel.fromJson(record);
            final existing = await habitRepo.getHabit(id);
            if (existing != null) {
              await habitRepo.updateHabit(habit);
            } else {
              await habitRepo.createHabit(habit);
            }
          }
          break;

        case 'daily_plans':
          if (isDeleted) {
            await dailyPlanRepo.deletePlan(id);
          } else {
            final plan = DailyPlanModel.fromJson(record);
            await dailyPlanRepo.savePlan(plan);
          }
          break;

        case 'planned_task_blocks':
          if (isDeleted) {
            await dailyPlanRepo.deleteBlock(id);
          } else {
            final block = PlannedTaskBlockModel.fromJson(record);
            await dailyPlanRepo.saveBlock(block);
          }
          break;

        case 'weekly_plans':
          if (isDeleted) {
            await weeklyPlanRepo.deletePlan(id);
          } else {
            final plan = WeeklyPlanModel.fromJson(record);
            await weeklyPlanRepo.savePlan(plan);
          }
          break;

        case 'monthly_plans':
          if (isDeleted) {
            await monthlyPlanRepo.deletePlan(id);
          } else {
            final plan = MonthlyPlanModel.fromJson(record);
            await monthlyPlanRepo.savePlan(plan);
          }
          break;
      }

      // Update sync metadata
      await syncRepo.saveMetadata(SyncMetadata(
        entityId: id,
        entityType: entityType,
        localUpdatedAt: serverUpdatedAt,
        remoteUpdatedAt: serverUpdatedAt,
        lastSyncedAt: DateTime.now(),
        deletedAt: isDeleted ? serverUpdatedAt : null,
      ));
    }

    // Invalidate related Riverpod providers so the UI immediately refreshes everywhere
    _ref.invalidate(allTasksProvider);
    _ref.invalidate(todayTasksProvider);
    _ref.invalidate(overdueTasksProvider);
    _ref.invalidate(upcomingTasksProvider);
    _ref.invalidate(routinesProvider);
    _ref.invalidate(activeRoutineProvider);
    _ref.invalidate(scheduleActivitiesProvider);
    _ref.invalidate(dailyScheduleProvider);
    _ref.invalidate(allGoalsProvider);
    _ref.invalidate(activeGoalsProvider);
    _ref.invalidate(allProjectsProvider);
    _ref.invalidate(activeProjectsProvider);
    _ref.invalidate(allHabitsProvider);
    _ref.invalidate(userProfileProvider);
    _ref.invalidate(settingsProvider);
  }

  /// Full restore: pulls all user data from Supabase on login/reinstall.
  /// This is called after successful authentication to restore cloud data.
  Future<void> fullRestore() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final statusNotifier = _ref.read(globalSyncStatusProvider.notifier);
    statusNotifier.state = SyncStatus.syncing;

    try {
      final provider = _ref.read(cloudSyncProvider);
      final user = await provider.getCurrentUser();

      if (user == null) {
        statusNotifier.state = SyncStatus.offline;
        _isSyncing = false;
        return;
      }

      // Ensure realtime is connected
      _subscribeRealtime(user.userId);

      // Pull all cloud data (no lastSyncedAt filter = full pull)
      await _pullChanges();

      // Push any local offline changes
      await _pushChanges();

      statusNotifier.state = SyncStatus.synced;
      debugPrint('[Sync] Full restore completed for user ${user.userId}');
    } catch (e) {
      statusNotifier.state = SyncStatus.failed;
      debugPrint('[Sync] Full restore error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
