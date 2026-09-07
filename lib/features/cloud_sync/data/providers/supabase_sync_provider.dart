import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_sync_provider.dart';
import '../models/cloud_models.dart';

final supabaseSyncProvider = Provider<SupabaseSyncProvider>((ref) {
  return SupabaseSyncProvider();
});

class SupabaseSyncProvider implements CloudSyncProvider {
  final SupabaseClient? _customClient;

  SupabaseSyncProvider({SupabaseClient? supabaseClient})
      : _customClient = supabaseClient;

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CloudAccount?> authenticate(String email, String password) async {
    final client = _client;
    if (client == null) return null;

    final res = await client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    if (res.user == null) return null;

    final user = res.user!;
    return CloudAccount(
      userId: user.id,
      email: user.email ?? email,
      displayName: (user.userMetadata?['full_name'] as String?) ??
          (user.email?.split('@').first ?? 'User'),
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      syncEnabled: true,
      backupEnabled: true,
    );
  }

  @override
  Future<CloudAccount?> getCurrentUser() async {
    final client = _client;
    if (client == null) return null;

    final session = client.auth.currentSession;
    final user = client.auth.currentUser ?? session?.user;
    if (user == null || session == null || session.isExpired) {
      return null;
    }

    return CloudAccount(
      userId: user.id,
      email: user.email ?? '',
      displayName: (user.userMetadata?['full_name'] as String?) ??
          (user.email?.split('@').first ?? 'User'),
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      syncEnabled: true,
      backupEnabled: true,
    );
  }

  @override
  Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      await client.auth.signOut();
    }
  }

  @override
  Future<DateTime> getServerTime() async {
    return DateTime.now().toUtc();
  }

  @override
  Future<void> pushChanges(
    List<SyncQueueItem> items,
    Map<String, dynamic> payloads,
  ) async {
    final client = _client;
    if (client == null) return;

    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Unauthorized: Active Supabase session required for sync');
    }

    debugPrint('[SupabaseSync] Pushing ${items.length} items to Supabase for user ${user.id}...');

    for (var item in items) {
      final tableName = _resolveTableName(item.entityType);
      if (tableName == null) continue;

      try {
        if (item.operation == SyncOperation.delete) {
          // Soft delete or hard delete in Supabase
          if (tableName == 'tasks' || tableName == 'goals') {
            await client
                .from(tableName)
                .update({'is_deleted': true, 'updated_at': DateTime.now().toIso8601String()})
                .eq('id', item.entityId)
                .eq('user_id', user.id);
          } else {
            await client
                .from(tableName)
                .delete()
                .eq('id', item.entityId)
                .eq('user_id', user.id);
          }
          debugPrint('[SupabaseSync] Deleted ${item.entityType}/${item.entityId} from $tableName');
        } else {
          final payload = payloads[item.entityId];
          if (payload != null) {
            final formatted = _formatPayloadForSupabase(item.entityType, payload, user.id);
            await client.from(tableName).upsert(formatted);
            debugPrint('[SupabaseSync] Upserted ${item.entityType}/${item.entityId} into $tableName');
          }
        }
      } catch (e) {
        debugPrint('[SupabaseSync] Push error on ${item.entityType}/${item.entityId}: $e');
        rethrow;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> pullChanges(DateTime? lastSyncedAt) async {
    final client = _client;
    if (client == null) return {};

    final user = client.auth.currentUser;
    if (user == null) {
      return {};
    }

    debugPrint('[SupabaseSync] Pulling cloud changes for authenticated user ${user.id}...');

    final changes = <String, dynamic>{};
    final tables = [
      'tasks',
      'task_subtasks',
      'routines',
      'routine_blocks',
      'schedule_activities',
      'goals',
      'goal_milestones',
      'projects',
      'diary_entries',
      'habits',
      'habit_logs',
      'daily_plans',
      'planned_task_blocks',
      'weekly_plans',
      'monthly_plans',
      'career_roadmaps',
      'career_milestones',
      'career_documents',
      'autopilot_actions',
      'productivity_events',
    ];

    for (var table in tables) {
      try {
        var query = client.from(table).select().eq('user_id', user.id);
        if (lastSyncedAt != null) {
          if (table == 'routine_blocks' || table == 'habit_logs') {
            query = query.gt('created_at', lastSyncedAt.toIso8601String());
          } else {
            query = query.gt('updated_at', lastSyncedAt.toIso8601String());
          }
        }

        final List<dynamic> rows = await query;
        for (var row in rows) {
          final id = row['id'] as String;
          final sUpdated = row['updated_at'] ?? row['created_at'] ?? DateTime.now().toIso8601String();
          changes[id] = {
            ...row,
            '_entityType': _resolveEntityType(table),
            '_serverUpdatedAt': sUpdated,
            '_deletedAt': row['is_deleted'] == true ? sUpdated : null,
          };
        }
      } catch (e) {
        debugPrint('[SupabaseSync] Pull notice on $table: $e');
      }
    }

    // Pull profile (keyed on id = user.id)
    try {
      final List<dynamic> profileRows = await client.from('profiles').select().eq('id', user.id);
      if (profileRows.isNotEmpty) {
        final pRow = profileRows.first as Map<String, dynamic>;
        changes[user.id] = {
          ...pRow,
          '_entityType': 'user_profile',
          '_serverUpdatedAt': pRow['updated_at'] ?? DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      debugPrint('[SupabaseSync] Profile pull notice: $e');
    }

    debugPrint('[SupabaseSync] Pull complete: retrieved ${changes.length} cloud records for user ${user.id}');
    return changes;
  }

  String? _resolveTableName(String entityType) {
    switch (entityType) {
      case 'tasks':
        return 'tasks';
      case 'subtasks':
        return 'task_subtasks';
      case 'routines':
        return 'routines';
      case 'routine_blocks':
        return 'routine_blocks';
      case 'schedule_activities':
        return 'schedule_activities';
      case 'goals':
        return 'goals';
      case 'milestones':
        return 'goal_milestones';
      case 'projects':
        return 'projects';
      case 'user_profile':
        return 'profiles';
      case 'diary_entries':
        return 'diary_entries';
      case 'habits':
        return 'habits';
      case 'habit_logs':
        return 'habit_logs';
      case 'daily_plans':
        return 'daily_plans';
      case 'planned_task_blocks':
      case 'daily_plan_blocks':
        return 'planned_task_blocks';
      case 'weekly_plans':
        return 'weekly_plans';
      case 'monthly_plans':
        return 'monthly_plans';
      case 'career_roadmaps':
        return 'career_roadmaps';
      case 'career_milestones':
        return 'career_milestones';
      case 'career_documents':
        return 'career_documents';
      case 'autopilot_actions':
        return 'autopilot_actions';
      case 'productivity_events':
        return 'productivity_events';
      default:
        return null;
    }
  }

  String _resolveEntityType(String tableName) {
    switch (tableName) {
      case 'tasks':
        return 'tasks';
      case 'task_subtasks':
        return 'subtasks';
      case 'routines':
        return 'routines';
      case 'routine_blocks':
        return 'routine_blocks';
      case 'schedule_activities':
        return 'schedule_activities';
      case 'goals':
        return 'goals';
      case 'goal_milestones':
        return 'milestones';
      case 'projects':
        return 'projects';
      case 'profiles':
        return 'user_profile';
      case 'diary_entries':
        return 'diary_entries';
      case 'habits':
        return 'habits';
      case 'habit_logs':
        return 'habit_logs';
      case 'daily_plans':
        return 'daily_plans';
      case 'planned_task_blocks':
        return 'planned_task_blocks';
      case 'weekly_plans':
        return 'weekly_plans';
      case 'monthly_plans':
        return 'monthly_plans';
      case 'career_roadmaps':
        return 'career_roadmaps';
      case 'career_milestones':
        return 'career_milestones';
      case 'career_documents':
        return 'career_documents';
      case 'autopilot_actions':
        return 'autopilot_actions';
      case 'productivity_events':
        return 'productivity_events';
      default:
        return tableName;
    }
  }

  Map<String, dynamic> _formatPayloadForSupabase(
    String entityType,
    Map<String, dynamic> payload,
    String userId,
  ) {
    final map = Map<String, dynamic>.from(payload);
    map['user_id'] = userId;
    final nowIso = DateTime.now().toIso8601String();

    String? cleanUuid(dynamic val) {
      if (val == null) return null;
      final s = val.toString().trim();
      return s.isNotEmpty ? s : null;
    }

    String? cleanDate(dynamic val) {
      if (val == null) return null;
      final s = val.toString().trim();
      if (s.isEmpty) return null;
      return s.contains('T') ? s.split('T').first : s;
    }

    if (entityType == 'user_profile') {
      map['id'] = userId;
      map.remove('user_id');
      if (map.containsKey('displayName')) map['display_name'] = map.remove('displayName');
      if (map.containsKey('avatarPreset')) map['avatar_preset'] = map.remove('avatarPreset');
      if (map.containsKey('avatarColorValue')) map['avatar_color_value'] = map.remove('avatarColorValue');
      if (map.containsKey('avatarUrl')) map['avatar_url'] = map.remove('avatarUrl');
      if (map.containsKey('workHoursStartMinutes')) map['work_hours_start_minutes'] = map.remove('workHoursStartMinutes');
      if (map.containsKey('workHoursEndMinutes')) map['work_hours_end_minutes'] = map.remove('workHoursEndMinutes');
      if (map.containsKey('dailyGoalHours')) map['daily_goal_hours'] = map.remove('dailyGoalHours');
      if (map.containsKey('dailyTaskGoal')) map['daily_task_goal'] = map.remove('dailyTaskGoal');
      if (map.containsKey('routinePreference')) map['routine_preference'] = map.remove('routinePreference');
      if (map.containsKey('themeMode')) map['theme_mode'] = map.remove('themeMode');
      if (map.containsKey('notificationsEnabled')) map['notifications_enabled'] = map.remove('notificationsEnabled');
      if (map.containsKey('syncEnabled')) map['sync_enabled'] = map.remove('syncEnabled');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'diary_entries') {
      if (map.containsKey('date')) map['entry_date'] = cleanDate(map.remove('date'));
      if (map.containsKey('entry_date')) map['entry_date'] = cleanDate(map['entry_date']);
      if (map.containsKey('moodKey')) {
        map['mood'] = map.remove('moodKey');
      } else if (map.containsKey('mood')) {
        map['mood'] = map['mood'].toString();
      }
      if (map.containsKey('energyLevel')) map['energy'] = map.remove('energyLevel');
      if (map.containsKey('isEncrypted')) map['is_private'] = map.remove('isEncrypted');
      if (map.containsKey('highlights') && map['highlights'] is List) {
        map['tomorrow_priorities'] = (map.remove('highlights') as List).join('\n');
      }
      if (map.containsKey('gratitudeList') && map['gratitudeList'] is List) {
        map['lessons_learned'] = (map.remove('gratitudeList') as List).join('\n');
      }
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'tasks') {
      if (map.containsKey('dueDate')) map['due_date'] = cleanDate(map.remove('dueDate'));
      if (map.containsKey('due_date')) map['due_date'] = cleanDate(map['due_date']);
      if (map.containsKey('dueTime')) map['due_time'] = map.remove('dueTime');
      if (map.containsKey('reminderEnabled')) map['reminder_enabled'] = map.remove('reminderEnabled');
      if (map.containsKey('reminderMinutesBefore')) map['reminder_minutes_before'] = map.remove('reminderMinutesBefore');
      if (map.containsKey('scheduleActivityId')) map['schedule_activity_id'] = cleanUuid(map.remove('scheduleActivityId'));
      if (map.containsKey('projectId')) map['project_id'] = cleanUuid(map.remove('projectId'));
      if (map.containsKey('project_id')) map['project_id'] = cleanUuid(map['project_id']);
      if (map.containsKey('goalId')) map['goal_id'] = cleanUuid(map.remove('goalId'));
      if (map.containsKey('goal_id')) map['goal_id'] = cleanUuid(map['goal_id']);
      if (map.containsKey('milestoneId')) map['milestone_id'] = cleanUuid(map.remove('milestoneId'));
      if (map.containsKey('milestone_id')) map['milestone_id'] = cleanUuid(map['milestone_id']);
      if (map.containsKey('parentTaskId')) map['parent_task_id'] = cleanUuid(map.remove('parentTaskId'));
      if (map.containsKey('parent_task_id')) map['parent_task_id'] = cleanUuid(map['parent_task_id']);
      if (map.containsKey('isDeleted')) map['is_deleted'] = map.remove('isDeleted');
      if (map.containsKey('estimatedDurationMinutes')) map['estimated_duration_minutes'] = map.remove('estimatedDurationMinutes');
      if (map.containsKey('actualDurationMinutes')) map['actual_duration_minutes'] = map.remove('actualDurationMinutes');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      if (map.containsKey('completedAt')) map['completed_at'] = map.remove('completedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;

      // Strip non-table attributes from tasks payload
      map.remove('startTime');
      map.remove('endTime');
      map.remove('tags');
      map.remove('dependsOnTaskIds');
    }

    if (entityType == 'subtasks') {
      if (map.containsKey('taskId')) map['task_id'] = cleanUuid(map.remove('taskId'));
      if (map.containsKey('task_id')) map['task_id'] = cleanUuid(map['task_id']);
      if (map.containsKey('completed')) map['is_completed'] = map.remove('completed');
      if (map.containsKey('order')) map['sort_order'] = map.remove('order');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'routines') {
      if (map.containsKey('daysOfWeek')) map['days_of_week'] = map.remove('daysOfWeek');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;

      // Strip non-table attributes from routines payload
      map.remove('startDate');
      map.remove('endDate');
      map.remove('frequency');
      map.remove('monthlyDay');
    }

    if (entityType == 'routine_blocks') {
      if (map.containsKey('routineId')) map['routine_id'] = cleanUuid(map.remove('routineId'));
      if (map.containsKey('routine_id')) map['routine_id'] = cleanUuid(map['routine_id']);
      if (map.containsKey('startHour')) map['start_hour'] = map.remove('startHour');
      if (map.containsKey('startMinute')) map['start_minute'] = map.remove('startMinute');
      if (map.containsKey('endHour')) map['end_hour'] = map.remove('endHour');
      if (map.containsKey('endMinute')) map['end_minute'] = map.remove('endMinute');
      if (map.containsKey('order')) map['sort_order'] = map.remove('order');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');

      map['created_at'] ??= nowIso;
      // routine_blocks table has NO updated_at column
      map.remove('updatedAt');
      map.remove('updated_at');
    }

    if (entityType == 'schedule_activities') {
      if (map.containsKey('date')) map['activity_date'] = cleanDate(map.remove('date'));
      if (map.containsKey('activity_date')) map['activity_date'] = cleanDate(map['activity_date']);
      if (map.containsKey('startTime')) map['start_time'] = map.remove('startTime');
      if (map.containsKey('endTime')) map['end_time'] = map.remove('endTime');
      if (map.containsKey('reminderEnabled')) map['reminder_enabled'] = map.remove('reminderEnabled');
      if (map.containsKey('routineBlockId')) map['routine_block_id'] = cleanUuid(map.remove('routineBlockId'));
      if (map.containsKey('routine_block_id')) map['routine_block_id'] = cleanUuid(map['routine_block_id']);
      if (map.containsKey('isOverridden')) map['is_overridden'] = map.remove('isOverridden');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      if (map.containsKey('completedAt')) map['completed_at'] = map.remove('completedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'goals') {
      if (map.containsKey('startDate')) map['start_date'] = map.remove('startDate');
      if (map.containsKey('targetDate')) map['target_date'] = map.remove('targetDate');
      if (map.containsKey('progressMode')) map['progress_mode'] = map.remove('progressMode');
      if (map.containsKey('manualProgress')) map['manual_progress'] = map.remove('manualProgress');
      if (map.containsKey('isDeleted')) map['is_deleted'] = map.remove('isDeleted');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      if (map.containsKey('completedAt')) map['completed_at'] = map.remove('completedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'milestones') {
      if (map.containsKey('goalId')) map['goal_id'] = cleanUuid(map.remove('goalId'));
      if (map.containsKey('goal_id')) map['goal_id'] = cleanUuid(map['goal_id']);
      if (map.containsKey('targetDate')) map['target_date'] = map.remove('targetDate');
      if (map.containsKey('order')) map['sort_order'] = map.remove('order');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      if (map.containsKey('completedAt')) map['completed_at'] = map.remove('completedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'projects') {
      if (map.containsKey('targetDate')) map['target_date'] = map.remove('targetDate');
      if (map.containsKey('goalId')) map['goal_id'] = cleanUuid(map.remove('goalId'));
      if (map.containsKey('goal_id')) map['goal_id'] = cleanUuid(map['goal_id']);
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      if (map.containsKey('completedAt')) map['completed_at'] = map.remove('completedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;

      // Strip non-table attributes from projects payload
      map.remove('startDate');
      map.remove('priority');
      map.remove('milestoneId');
      map.remove('notes');
      map.remove('isDeleted');
    }

    if (entityType == 'daily_plans') {
      if (map.containsKey('date')) map['plan_date'] = cleanDate(map.remove('date'));
      if (map.containsKey('plan_date')) map['plan_date'] = cleanDate(map['plan_date']);
      if (map.containsKey('plannedDurationSeconds')) map['planned_duration_seconds'] = map.remove('plannedDurationSeconds');
      if (map.containsKey('completedDurationSeconds')) map['completed_duration_seconds'] = map.remove('completedDurationSeconds');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'planned_task_blocks' || entityType == 'daily_plan_blocks') {
      if (map.containsKey('dailyPlanId')) map['daily_plan_id'] = cleanUuid(map.remove('dailyPlanId'));
      if (map.containsKey('daily_plan_id')) map['daily_plan_id'] = cleanUuid(map['daily_plan_id']);
      if (map.containsKey('taskId')) map['task_id'] = cleanUuid(map.remove('taskId'));
      if (map.containsKey('task_id')) map['task_id'] = cleanUuid(map['task_id']);
      if (map.containsKey('startHour')) map['start_hour'] = map.remove('startHour');
      if (map.containsKey('startMinute')) map['start_minute'] = map.remove('startMinute');
      if (map.containsKey('endHour')) map['end_hour'] = map.remove('endHour');
      if (map.containsKey('endMinute')) map['end_minute'] = map.remove('endMinute');
      if (map.containsKey('estimatedDurationSeconds')) map['estimated_duration_seconds'] = map.remove('estimatedDurationSeconds');
      if (map.containsKey('focusSessionId')) map['focus_session_id'] = cleanUuid(map.remove('focusSessionId'));
      if (map.containsKey('focus_session_id')) map['focus_session_id'] = cleanUuid(map['focus_session_id']);
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'weekly_plans') {
      if (map.containsKey('weekStartDate')) map['week_start_date'] = cleanDate(map.remove('weekStartDate'));
      if (map.containsKey('week_start_date')) map['week_start_date'] = cleanDate(map['week_start_date']);
      if (map.containsKey('weekEndDate')) map['week_end_date'] = cleanDate(map.remove('weekEndDate'));
      if (map.containsKey('week_end_date')) map['week_end_date'] = cleanDate(map['week_end_date']);
      if (map.containsKey('plannedDurationSeconds')) map['planned_duration_seconds'] = map.remove('plannedDurationSeconds');
      if (map.containsKey('targetFocusDurationSeconds')) map['target_focus_duration_seconds'] = map.remove('targetFocusDurationSeconds');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'monthly_plans') {
      if (map.containsKey('year')) map['plan_year'] = map.remove('year');
      if (map.containsKey('month')) map['plan_month'] = map.remove('month');
      if (map.containsKey('plannedDurationSeconds')) map['planned_duration_seconds'] = map.remove('plannedDurationSeconds');
      if (map.containsKey('targetFocusDurationSeconds')) map['target_focus_duration_seconds'] = map.remove('targetFocusDurationSeconds');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'habits') {
      if (map.containsKey('targetDaysPerWeek')) map['target_days_per_week'] = map.remove('targetDaysPerWeek');
      if (map.containsKey('reminderTime')) map['reminder_time'] = map.remove('reminderTime');
      if (map.containsKey('currentStreak')) map['current_streak'] = map.remove('currentStreak');
      if (map.containsKey('bestStreak')) map['best_streak'] = map.remove('bestStreak');
      if (map.containsKey('goalId')) map['goal_id'] = cleanUuid(map.remove('goalId'));
      if (map.containsKey('goal_id')) map['goal_id'] = cleanUuid(map['goal_id']);
      if (map.containsKey('isArchived')) map['is_archived'] = map.remove('isArchived');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');

      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'habit_logs') {
      if (map.containsKey('habitId')) map['habit_id'] = cleanUuid(map.remove('habitId'));
      if (map.containsKey('habit_id')) map['habit_id'] = cleanUuid(map['habit_id']);
      if (map.containsKey('logDate')) map['log_date'] = cleanDate(map.remove('logDate'));
      if (map.containsKey('log_date')) map['log_date'] = cleanDate(map['log_date']);
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');

      map['created_at'] ??= nowIso;
      // habit_logs table has NO updated_at column
      map.remove('updatedAt');
      map.remove('updated_at');
    }

    if (entityType == 'career_roadmaps') {
      if (map.containsKey('targetRole')) map['target_role'] = map.remove('targetRole');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'career_milestones') {
      if (map.containsKey('roadmapId')) map['roadmap_id'] = cleanUuid(map.remove('roadmapId'));
      if (map.containsKey('roadmap_id')) map['roadmap_id'] = cleanUuid(map['roadmap_id']);
      if (map.containsKey('targetDate')) map['target_date'] = map.remove('targetDate');
      if (map.containsKey('sortOrder')) map['sort_order'] = map.remove('sortOrder');
      if (map.containsKey('linkedTaskId')) map['linked_task_id'] = cleanUuid(map.remove('linkedTaskId'));
      if (map.containsKey('linked_task_id')) map['linked_task_id'] = cleanUuid(map['linked_task_id']);
      if (map.containsKey('linkedGoalId')) map['linked_goal_id'] = cleanUuid(map.remove('linkedGoalId'));
      if (map.containsKey('linked_goal_id')) map['linked_goal_id'] = cleanUuid(map['linked_goal_id']);
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'career_documents') {
      if (map.containsKey('fileName')) map['file_name'] = map.remove('fileName');
      if (map.containsKey('documentType')) map['document_type'] = map.remove('documentType');
      if (map.containsKey('fileUrl')) map['file_url'] = map.remove('fileUrl');
      if (map.containsKey('fileSize')) map['file_size'] = map.remove('fileSize');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      map['created_at'] ??= nowIso;
      map['updated_at'] ??= nowIso;
    }

    if (entityType == 'autopilot_actions') {
      if (map.containsKey('actionType')) map['action_type'] = map.remove('actionType');
      if (map.containsKey('entityId')) map['entity_id'] = cleanUuid(map.remove('entityId'));
      if (map.containsKey('originalStart')) map['original_start'] = map.remove('originalStart');
      if (map.containsKey('originalEnd')) map['original_end'] = map.remove('originalEnd');
      if (map.containsKey('newStart')) map['new_start'] = map.remove('newStart');
      if (map.containsKey('newEnd')) map['new_end'] = map.remove('newEnd');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      map['created_at'] ??= nowIso;
    }

    if (entityType == 'productivity_events') {
      if (map.containsKey('eventType')) map['event_type'] = map.remove('eventType');
      if (map.containsKey('entityType')) map['entity_type'] = map.remove('entityType');
      if (map.containsKey('entityId')) map['entity_id'] = cleanUuid(map.remove('entityId'));
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      map['created_at'] ??= nowIso;
    }

    return map;
  }
}
