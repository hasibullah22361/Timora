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
        } else {
          final payload = payloads[item.entityId];
          if (payload != null) {
            final formatted = _formatPayloadForSupabase(item.entityType, payload, user.id);
            await client.from(tableName).upsert(formatted);
          }
        }
      } catch (e) {
        debugPrint('Supabase push error on ${item.entityType}/${item.entityId}: $e');
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
    ];

    for (var table in tables) {
      try {
        var query = client.from(table).select().eq('user_id', user.id);
        if (lastSyncedAt != null) {
          query = query.gt('updated_at', lastSyncedAt.toIso8601String());
        }

        final List<dynamic> rows = await query;
        for (var row in rows) {
          final id = row['id'] as String;
          changes[id] = {
            ...row,
            '_entityType': _resolveEntityType(table),
            '_serverUpdatedAt': row['updated_at'] ?? DateTime.now().toIso8601String(),
            '_deletedAt': row['is_deleted'] == true ? row['updated_at'] : null,
          };
        }
      } catch (e) {
        debugPrint('Supabase pull notice on $table: $e');
      }
    }

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

    if (entityType == 'diary_entries') {
      if (map.containsKey('date')) map['entry_date'] = map.remove('date');
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
    }

    // Convert camelCase keys to snake_case for PostgreSQL if required
    if (entityType == 'tasks') {
      if (map.containsKey('dueDate')) map['due_date'] = map.remove('dueDate');
      if (map.containsKey('dueTime')) map['due_time'] = map.remove('dueTime');
      if (map.containsKey('reminderEnabled')) map['reminder_enabled'] = map.remove('reminderEnabled');
      if (map.containsKey('reminderMinutesBefore')) map['reminder_minutes_before'] = map.remove('reminderMinutesBefore');
      if (map.containsKey('scheduleActivityId')) map['schedule_activity_id'] = map.remove('scheduleActivityId');
      if (map.containsKey('projectId')) map['project_id'] = map.remove('projectId');
      if (map.containsKey('goalId')) map['goal_id'] = map.remove('goalId');
      if (map.containsKey('milestoneId')) map['milestone_id'] = map.remove('milestoneId');
      if (map.containsKey('isDeleted')) map['is_deleted'] = map.remove('isDeleted');
      if (map.containsKey('estimatedDurationMinutes')) map['estimated_duration_minutes'] = map.remove('estimatedDurationMinutes');
      if (map.containsKey('actualDurationMinutes')) map['actual_duration_minutes'] = map.remove('actualDurationMinutes');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
      if (map.containsKey('completedAt')) map['completed_at'] = map.remove('completedAt');
    }

    if (entityType == 'daily_plans') {
      if (map.containsKey('date')) map['plan_date'] = map.remove('date');
      if (map.containsKey('plannedDurationSeconds')) map['planned_duration_seconds'] = map.remove('plannedDurationSeconds');
      if (map.containsKey('completedDurationSeconds')) map['completed_duration_seconds'] = map.remove('completedDurationSeconds');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
    }

    if (entityType == 'planned_task_blocks' || entityType == 'daily_plan_blocks') {
      if (map.containsKey('dailyPlanId')) map['daily_plan_id'] = map.remove('dailyPlanId');
      if (map.containsKey('taskId')) map['task_id'] = map.remove('taskId');
      if (map.containsKey('startHour')) map['start_hour'] = map.remove('startHour');
      if (map.containsKey('startMinute')) map['start_minute'] = map.remove('startMinute');
      if (map.containsKey('endHour')) map['end_hour'] = map.remove('endHour');
      if (map.containsKey('endMinute')) map['end_minute'] = map.remove('endMinute');
      if (map.containsKey('estimatedDurationSeconds')) map['estimated_duration_seconds'] = map.remove('estimatedDurationSeconds');
      if (map.containsKey('focusSessionId')) map['focus_session_id'] = map.remove('focusSessionId');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
    }

    if (entityType == 'weekly_plans') {
      if (map.containsKey('weekStartDate')) map['week_start_date'] = map.remove('weekStartDate');
      if (map.containsKey('weekEndDate')) map['week_end_date'] = map.remove('weekEndDate');
      if (map.containsKey('plannedDurationSeconds')) map['planned_duration_seconds'] = map.remove('plannedDurationSeconds');
      if (map.containsKey('targetFocusDurationSeconds')) map['target_focus_duration_seconds'] = map.remove('targetFocusDurationSeconds');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
    }

    if (entityType == 'monthly_plans') {
      if (map.containsKey('year')) map['plan_year'] = map.remove('year');
      if (map.containsKey('month')) map['plan_month'] = map.remove('month');
      if (map.containsKey('plannedDurationSeconds')) map['planned_duration_seconds'] = map.remove('plannedDurationSeconds');
      if (map.containsKey('targetFocusDurationSeconds')) map['target_focus_duration_seconds'] = map.remove('targetFocusDurationSeconds');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
    }

    if (entityType == 'habits') {
      if (map.containsKey('targetDaysPerWeek')) map['target_days_per_week'] = map.remove('targetDaysPerWeek');
      if (map.containsKey('reminderTime')) map['reminder_time'] = map.remove('reminderTime');
      if (map.containsKey('currentStreak')) map['current_streak'] = map.remove('currentStreak');
      if (map.containsKey('bestStreak')) map['best_streak'] = map.remove('bestStreak');
      if (map.containsKey('goalId')) map['goal_id'] = map.remove('goalId');
      if (map.containsKey('isArchived')) map['is_archived'] = map.remove('isArchived');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
      if (map.containsKey('updatedAt')) map['updated_at'] = map.remove('updatedAt');
    }

    if (entityType == 'habit_logs') {
      if (map.containsKey('habitId')) map['habit_id'] = map.remove('habitId');
      if (map.containsKey('logDate')) map['log_date'] = map.remove('logDate');
      if (map.containsKey('createdAt')) map['created_at'] = map.remove('createdAt');
    }

    return map;
  }
}
