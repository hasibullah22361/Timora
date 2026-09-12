import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/remote_config_service.dart';
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
import '../../diary/presentation/providers/diary_provider.dart';
import '../../habits/presentation/providers/habit_provider.dart';
import '../../habits/data/models/habit_model.dart';
import '../../habits/data/models/habit_log_model.dart';
import '../../habits/data/repositories/habit_repository.dart';
import '../../daily_plan/data/models/daily_plan_model.dart';
import '../../daily_plan/data/models/planned_task_block_model.dart';
import '../../daily_plan/data/repositories/daily_plan_repository.dart';
import '../../weekly_plan/data/models/weekly_plan_model.dart';
import '../../weekly_plan/data/repositories/weekly_plan_repository.dart';
import '../../monthly_plan/data/models/monthly_plan_model.dart';
import '../../monthly_plan/data/repositories/monthly_plan_repository.dart';
import '../../career/data/models/career_document_model.dart';
import '../../career/data/repositories/career_document_repository.dart';
import '../../career/data/models/career_roadmap_model.dart';
import '../../career/data/models/career_milestone_model.dart';
import '../../career/data/repositories/career_roadmap_repository.dart';
import '../../schedule/data/models/autopilot_action_model.dart';
import '../../schedule/data/repositories/autopilot_action_repository.dart';
import '../../analytics/data/models/productivity_event_model.dart';
import '../../analytics/data/repositories/productivity_event_repository.dart';
import '../../widget/services/widget_update_service.dart';
import '../../analytics/services/productivity_event_service.dart';
import '../../analytics/services/consistency_score_service.dart';
import '../../analytics/services/report_generator_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

final globalSyncStatusProvider =
    StateProvider<SyncStatus>((ref) => SyncStatus.offline);

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
    debugPrint(
        '[Sync] Realtime change on table: ${payload.table}, triggering syncNow...');
    syncNow();
  }

  void onUserSignedOut() {
    _unsubscribeRealtime();
    try {
      _ref.read(globalSyncStatusProvider.notifier).state = SyncStatus.offline;
    } catch (_) {}
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
      _connectivitySubscription =
          connectivityService.statusStream.listen((status) {
        if (status == ConnectivityStatus.online) {
          debugPrint('[Sync] Connection restored, triggering sync...');
          autoSync();
        } else {
          _ref.read(globalSyncStatusProvider.notifier).state =
              SyncStatus.offline;
        }
      });
    } catch (e) {
      debugPrint('[Sync] Connectivity listener notice: $e');
    }
  }

  Future<void> autoSync() async {
    try {
      final provider = _ref.read(cloudSyncProvider);
      final user = await provider.getCurrentUser();
      if (user == null || !user.syncEnabled) return;

      await syncNow();
    } catch (_) {
      // Ignored for auto-sync; error status handled in syncNow
    }
  }

  Future<void> syncNow() async {
    int retries = 0;
    while (_isSyncing && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 50));
      retries++;
    }
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

      // Check if user account has been suspended by an administrator
      final currentProfile = _ref.read(userProfileProvider);
      if (currentProfile.isSuspended) {
        debugPrint(
            '[Sync] Account is suspended by administrator: ${currentProfile.suspendedReason}');
        statusNotifier.state = SyncStatus.failed;
        _isSyncing = false;
        return;
      }

      // Check if global maintenance mode is enabled remotely
      final remoteConfig = _ref.read(remoteConfigServiceProvider).currentConfig;
      if (remoteConfig.maintenanceMode) {
        debugPrint('[Sync] Cloud sync paused due to system maintenance mode');
        statusNotifier.state = SyncStatus.synced;
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

  int _entityPriority(String entityType, bool isDelete) {
    int rank;
    switch (entityType) {
      case 'user_profile':
      case 'settings':
        rank = 1;
        break;
      case 'projects':
      case 'goals':
      case 'career_roadmaps':
        rank = 2;
        break;
      case 'milestones':
      case 'career_milestones':
        rank = 3;
        break;
      case 'routines':
        rank = 4;
        break;
      case 'routine_blocks':
        rank = 5;
        break;
      case 'tasks':
        rank = 6;
        break;
      case 'subtasks':
        rank = 7;
        break;
      case 'schedule_activities':
        rank = 8;
        break;
      case 'habits':
        rank = 9;
        break;
      case 'habit_logs':
        rank = 10;
        break;
      case 'daily_plans':
        rank = 11;
        break;
      case 'planned_task_blocks':
      case 'daily_plan_blocks':
        rank = 12;
        break;
      case 'weekly_plans':
      case 'monthly_plans':
      case 'career_documents':
        rank = 13;
        break;
      case 'autopilot_actions':
        rank = 14;
        break;
      case 'productivity_events':
        rank = 15;
        break;
      case 'diary_entries':
      default:
        rank = 16;
        break;
    }
    return isDelete ? (100 - rank) : rank;
  }

  Future<void> _pushChanges() async {
    final syncRepo = _ref.read(syncRepositoryProvider);
    final provider = _ref.read(cloudSyncProvider);

    final pending = await syncRepo.getPendingItems();
    if (pending.isEmpty) return;

    // Sort pending items topologically:
    // Upserts: parents before children (e.g. routines before routine_blocks, tasks before subtasks)
    // Deletions: children before parents (e.g. subtasks before tasks)
    final sortedPending = List<SyncQueueItem>.from(pending);
    sortedPending.sort((a, b) {
      final isDelA = a.operation == SyncOperation.delete;
      final isDelB = b.operation == SyncOperation.delete;
      if (isDelA != isDelB) {
        return isDelA ? 1 : -1;
      }
      final prioA = _entityPriority(a.entityType, isDelA);
      final prioB = _entityPriority(b.entityType, isDelB);
      return prioA.compareTo(prioB);
    });

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
    final careerRoadmapRepo = _ref.read(careerRoadmapRepositoryProvider);
    final careerDocRepo = _ref.read(careerDocumentRepositoryProvider);
    final autopilotRepo = _ref.read(autopilotActionRepositoryProvider);
    final eventRepo = _ref.read(productivityEventRepositoryProvider);

    // Collect entity types that require lookup payloads
    final neededTypes = sortedPending
        .where((item) => item.operation != SyncOperation.delete)
        .map((item) => item.entityType)
        .toSet();

    // Preload ONLY required datasets for fast lookup, avoiding loading all 16 tables
    final tasks = neededTypes.contains('tasks')
        ? await taskRepo.getTasks()
        : const <TaskModel>[];
    final subtasks = neededTypes.contains('subtasks')
        ? await taskRepo.getAllSubtasks()
        : const <SubtaskModel>[];
    final routines = neededTypes.contains('routines')
        ? await routineRepo.getAllRoutines()
        : const <Routine>[];
    final blocks = neededTypes.contains('routine_blocks')
        ? await routineRepo.getAllBlocks()
        : const <RoutineBlock>[];
    final activities = neededTypes.contains('schedule_activities')
        ? await scheduleRepo.getAllActivities()
        : const <ScheduleActivity>[];
    final goals = neededTypes.contains('goals')
        ? await goalRepo.getGoals()
        : const <GoalModel>[];
    final milestones = neededTypes.contains('milestones')
        ? await goalRepo.getAllMilestones()
        : const <MilestoneModel>[];
    final projects = neededTypes.contains('projects')
        ? await projectRepo.getProjects()
        : const <ProjectModel>[];
    final profile =
        neededTypes.contains('user_profile') ? profileRepo.loadProfile() : null;
    final settings =
        neededTypes.contains('settings') ? settingsRepo.loadSettings() : null;
    final diaryEntries = neededTypes.contains('diary_entries')
        ? await diaryRepo.getAllEntries()
        : const <DiaryEntryModel>[];
    final habits = neededTypes.contains('habits')
        ? await habitRepo.getHabits()
        : const <HabitModel>[];
    final careerRoadmaps = neededTypes.contains('career_roadmaps')
        ? await careerRoadmapRepo.getRoadmaps()
        : const <CareerRoadmapModel>[];
    final careerMilestones = neededTypes.contains('career_milestones')
        ? await careerRoadmapRepo.getAllMilestones()
        : const <CareerMilestoneModel>[];
    final careerDocuments = neededTypes.contains('career_documents')
        ? await careerDocRepo.getDocuments()
        : const <CareerDocumentModel>[];
    final autopilotActions = neededTypes.contains('autopilot_actions')
        ? await autopilotRepo.getAllActions()
        : const <AutopilotActionModel>[];
    final productivityEvents = neededTypes.contains('productivity_events')
        ? await eventRepo.getAllEvents()
        : const <ProductivityEventModel>[];

    for (var item in sortedPending) {
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
          if (profile != null) payloads[item.entityId] = profile.toJson();
          break;
        case 'settings':
          if (settings != null) payloads[item.entityId] = settings.toJson();
          break;
        case 'diary_entries':
          final d =
              diaryEntries.where((x) => x.id == item.entityId).firstOrNull;
          if (d != null) payloads[item.entityId] = d.toJson();
          break;
        case 'habits':
          final h = habits.where((x) => x.id == item.entityId).firstOrNull;
          if (h != null) payloads[item.entityId] = h.toJson();
          break;
        case 'habit_logs':
          final log = await habitRepo.getLogById(item.entityId);
          if (log != null) payloads[item.entityId] = log.toJson();
          break;
        case 'daily_plans':
          final dp = await dailyPlanRepo.getPlanById(item.entityId);
          if (dp != null) payloads[item.entityId] = dp.toJson();
          break;
        case 'planned_task_blocks':
        case 'daily_plan_blocks':
          final block = await dailyPlanRepo.getBlockById(item.entityId);
          if (block != null) payloads[item.entityId] = block.toJson();
          break;
        case 'weekly_plans':
          final wp = await weeklyPlanRepo.getPlanById(item.entityId);
          if (wp != null) payloads[item.entityId] = wp.toJson();
          break;
        case 'monthly_plans':
          final mp = await monthlyPlanRepo.getPlanById(item.entityId);
          if (mp != null) payloads[item.entityId] = mp.toJson();
          break;
        case 'career_roadmaps':
          final rm =
              careerRoadmaps.where((x) => x.id == item.entityId).firstOrNull;
          if (rm != null) payloads[item.entityId] = rm.toJson();
          break;
        case 'career_milestones':
          final cm =
              careerMilestones.where((x) => x.id == item.entityId).firstOrNull;
          if (cm != null) payloads[item.entityId] = cm.toJson();
          break;
        case 'career_documents':
          final cd =
              careerDocuments.where((x) => x.id == item.entityId).firstOrNull;
          if (cd != null) payloads[item.entityId] = cd.toJson();
          break;
        case 'autopilot_actions':
          final aa =
              autopilotActions.where((x) => x.id == item.entityId).firstOrNull;
          if (aa != null) payloads[item.entityId] = aa.toJson();
          break;
        case 'productivity_events':
          final pe = productivityEvents
              .where((x) => x.id == item.entityId)
              .firstOrNull;
          if (pe != null) payloads[item.entityId] = pe.toJson();
          break;
      }
    }

    try {
      await provider.pushChanges(sortedPending, payloads);
      // On success, mark items synced
      for (var item in sortedPending) {
        await syncRepo.markItemSynced(item.id);
      }
    } catch (e) {
      for (var item in sortedPending) {
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
    final careerRoadmapRepo = _ref.read(careerRoadmapRepositoryProvider);
    final careerDocRepo = _ref.read(careerDocumentRepositoryProvider);
    final autopilotRepo = _ref.read(autopilotActionRepositoryProvider);
    final eventRepo = _ref.read(productivityEventRepositoryProvider);

    // Sort pulled entries in topological order (parents before children for inserts/updates)
    final sortedEntries = changes.entries.toList();
    sortedEntries.sort((a, b) {
      final isDelA = a.value['_deletedAt'] != null;
      final isDelB = b.value['_deletedAt'] != null;
      final typeA = a.value['_entityType'] as String? ?? '';
      final typeB = b.value['_entityType'] as String? ?? '';
      if (isDelA != isDelB) {
        return isDelA ? 1 : -1;
      }
      final prioA = _entityPriority(typeA, isDelA);
      final prioB = _entityPriority(typeB, isDelB);
      return prioA.compareTo(prioB);
    });

    for (var entry in sortedEntries) {
      final id = entry.key;
      final record = entry.value;

      try {
        final isDeleted = record['_deletedAt'] != null;
        final entityType = record['_entityType'] as String? ?? 'tasks';
        final serverUpdatedAt = record['_serverUpdatedAt'] != null
            ? (DateTime.tryParse(record['_serverUpdatedAt'].toString()) ??
                DateTime.now())
            : DateTime.now();

        final localMeta = await syncRepo.getMetadata(id);

        // Conflict Resolution: Last-Write-Wins
        if (localMeta != null &&
            localMeta.localUpdatedAt.isAfter(serverUpdatedAt)) {
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
              await taskRepo.updateSubtask(subtask);
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

          case 'habit_logs':
            if (isDeleted) {
              await habitRepo.deleteHabitLog(id);
            } else {
              final log = HabitLogModel.fromJson(record);
              await habitRepo.saveHabitLog(log);
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
          case 'daily_plan_blocks':
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

          case 'career_roadmaps':
            if (!isDeleted) {
              final rm = CareerRoadmapModel.fromJson(record);
              await careerRoadmapRepo.saveRoadmap(rm);
            }
            break;

          case 'career_milestones':
            if (isDeleted) {
              final rId = record['roadmap_id'] as String? ?? '';
              await careerRoadmapRepo.deleteMilestone(id, rId);
            } else {
              final cm = CareerMilestoneModel.fromJson(record);
              await careerRoadmapRepo.saveMilestone(cm);
            }
            break;

          case 'career_documents':
            if (isDeleted) {
              await careerDocRepo.deleteDocument(id);
            } else {
              final cd = CareerDocumentModel.fromJson(record);
              await careerDocRepo.savePulledDocument(cd);
            }
            break;

          case 'autopilot_actions':
            if (!isDeleted) {
              final aa = AutopilotActionModel.fromJson(record);
              await autopilotRepo.savePulledAction(aa);
            }
            break;

          case 'productivity_events':
            if (isDeleted) {
              await eventRepo.deleteEvent(id);
            } else {
              final pe = ProductivityEventModel.fromJson(record);
              await eventRepo.savePulledEvent(pe);
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
      } catch (itemError) {
        debugPrint(
            '[Sync] Notice: failed to apply pulled record $id: $itemError');
      }
    }

    final pulledTypes =
        changes.values.map((v) => v['_entityType'] as String?).toSet();

    // Granular Riverpod provider invalidations: only invalidate providers
    // for domain entities that were actually modified or pulled.
    if (pulledTypes.contains('tasks') || pulledTypes.contains('subtasks')) {
      _ref.invalidate(allTasksProvider);
      _ref.invalidate(todayTasksProvider);
      _ref.invalidate(overdueTasksProvider);
      _ref.invalidate(upcomingTasksProvider);
      _ref.invalidate(dailyReportProvider);
      _ref.invalidate(weeklyReportProvider);
      _ref.invalidate(monthlyReportProvider);
      _ref.invalidate(whatShouldIDoNowProvider);
    }
    if (pulledTypes.contains('routines') ||
        pulledTypes.contains('routine_blocks')) {
      _ref.invalidate(routinesProvider);
      _ref.invalidate(activeRoutineProvider);
    }
    if (pulledTypes.contains('schedule_activities')) {
      _ref.invalidate(scheduleActivitiesProvider);
      _ref.invalidate(dailyScheduleProvider);
    }
    if (pulledTypes.contains('goals') || pulledTypes.contains('milestones')) {
      _ref.invalidate(allGoalsProvider);
      _ref.invalidate(activeGoalsProvider);
    }
    if (pulledTypes.contains('projects')) {
      _ref.invalidate(allProjectsProvider);
      _ref.invalidate(activeProjectsProvider);
    }
    if (pulledTypes.contains('habits') || pulledTypes.contains('habit_logs')) {
      _ref.invalidate(allHabitsProvider);
    }
    if (pulledTypes.contains('diary_entries')) {
      _ref.invalidate(allDiaryEntriesProvider);
      _ref.invalidate(diaryEntryForSelectedDateProvider);
      _ref.invalidate(diaryStreakStatsProvider);
    }
    if (pulledTypes.contains('user_profile')) {
      _ref.invalidate(userProfileProvider);
    }
    if (pulledTypes.contains('settings')) {
      _ref.invalidate(settingsProvider);
    }
    if (pulledTypes.contains('daily_plans') ||
        pulledTypes.contains('planned_task_blocks') ||
        pulledTypes.contains('daily_plan_blocks')) {
      _ref.invalidate(dailyPlanRepositoryProvider);
    }
    if (pulledTypes.contains('weekly_plans')) {
      _ref.invalidate(weeklyPlanRepositoryProvider);
    }
    if (pulledTypes.contains('monthly_plans')) {
      _ref.invalidate(monthlyPlanRepositoryProvider);
    }
    if (pulledTypes.contains('career_roadmaps') ||
        pulledTypes.contains('career_milestones')) {
      _ref.invalidate(activeRoadmapProvider);
    }
    if (pulledTypes.contains('career_documents')) {
      _ref.invalidate(allCareerDocumentsProvider);
    }
    if (pulledTypes.contains('autopilot_actions')) {
      _ref.invalidate(autopilotHistoryProvider);
    }
    if (pulledTypes.contains('productivity_events')) {
      _ref.invalidate(allProductivityEventsProvider);
      _ref.invalidate(weeklyConsistencyScoreProvider);
    }

    // Only trigger home widget update if relevant schedule/task/routine items changed
    if (pulledTypes.contains('tasks') ||
        pulledTypes.contains('subtasks') ||
        pulledTypes.contains('routines') ||
        pulledTypes.contains('routine_blocks') ||
        pulledTypes.contains('schedule_activities')) {
      _ref.read(widgetUpdateServiceProvider).updateWidgets();
    }
  }

  /// Full restore: pulls all user data from Supabase on login/reinstall.
  /// This is called after successful authentication to restore cloud data.
  Future<void> fullRestore() async {
    // If a sync is currently in progress, wait briefly for it to complete
    int retries = 0;
    while (_isSyncing && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
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

      // CRITICAL: Pull all cloud data FIRST so empty local storage never overwrites cloud
      await _pullChanges();

      // Then push any local offline changes (if any existed)
      await _pushChanges();

      statusNotifier.state = SyncStatus.synced;
      debugPrint(
          '[Sync] Full restore completed successfully for user ${user.userId}');
    } catch (e) {
      statusNotifier.state = SyncStatus.failed;
      debugPrint('[Sync] Full restore error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
