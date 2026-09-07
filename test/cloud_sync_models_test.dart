import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/routine/data/models/routine_block.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import 'package:timora/features/projects/data/models/project_model.dart';
import 'package:timora/features/goals/data/models/goal_model.dart';
import 'package:timora/features/goals/data/models/milestone_model.dart';
import 'package:timora/features/tasks/data/models/subtask_model.dart';
import 'package:timora/features/daily_plan/data/models/daily_plan_model.dart';
import 'package:timora/features/weekly_plan/data/models/weekly_plan_model.dart';
import 'package:timora/features/monthly_plan/data/models/monthly_plan_model.dart';

void main() {
  group('Supabase Snake Case Deserialization Tests', () {
    test('Routine deserialization handles Supabase row format', () {
      final supabaseRow = {
        'id': 'routine-123',
        'user_id': 'user-abc',
        'name': 'Morning Energy',
        'description': 'Rise and shine',
        'icon': '☀️',
        'color': 4280656875,
        'enabled': true,
        'days_of_week': [1, 2, 3, 4, 5],
        'created_at': '2026-09-01T08:00:00.000Z',
        'updated_at': '2026-09-02T10:00:00.000Z',
      };

      final routine = Routine.fromJson(supabaseRow);
      expect(routine.id, 'routine-123');
      expect(routine.name, 'Morning Energy');
      expect(routine.daysOfWeek, [1, 2, 3, 4, 5]);
      expect(routine.createdAt.toIso8601String(), contains('2026-09-01'));
      expect(routine.updatedAt?.toIso8601String(), contains('2026-09-02'));
    });

    test('RoutineBlock deserialization handles Supabase row format', () {
      final supabaseRow = {
        'id': 'block-123',
        'user_id': 'user-abc',
        'routine_id': 'routine-123',
        'title': 'Morning Meditation',
        'description': 'Focus breath',
        'start_hour': 6,
        'start_minute': 30,
        'end_hour': 7,
        'end_minute': 0,
        'category': 'Wellness',
        'icon': '🧘',
        'color': 4280656875,
        'sort_order': 1,
        'enabled': true,
        'notes': 'Quiet space',
        'created_at': '2026-09-01T08:00:00.000Z',
      };

      final block = RoutineBlock.fromJson(supabaseRow);
      expect(block.id, 'block-123');
      expect(block.routineId, 'routine-123');
      expect(block.startTime.hour, 6);
      expect(block.startTime.minute, 30);
      expect(block.endTime.hour, 7);
      expect(block.endTime.minute, 0);
      expect(block.order, 1);
    });

    test('ScheduleActivity deserialization handles Supabase row format', () {
      final supabaseRow = {
        'id': 'act-123',
        'user_id': 'user-abc',
        'title': 'Deep Work Session',
        'description': 'Coding Timora',
        'activity_date': '2026-09-05T00:00:00.000Z',
        'start_time': '2026-09-05T09:00:00.000Z',
        'end_time': '2026-09-05T11:00:00.000Z',
        'category': 'Work',
        'icon': '💻',
        'color': 4280656875,
        'status': 'upcoming',
        'notes': 'No distractions',
        'reminder_enabled': true,
        'routine_block_id': 'block-123',
        'is_overridden': false,
        'created_at': '2026-09-01T08:00:00.000Z',
        'updated_at': '2026-09-02T08:00:00.000Z',
      };

      final act = ScheduleActivity.fromJson(supabaseRow);
      expect(act.id, 'act-123');
      expect(act.title, 'Deep Work Session');
      expect(act.startTime.hour, 9);
      expect(act.endTime.hour, 11);
      expect(act.routineBlockId, 'block-123');
      expect(act.reminderEnabled, isTrue);
    });

    test('ProjectModel and GoalModel deserialization handle Supabase rows', () {
      final projectRow = {
        'id': 'proj-123',
        'user_id': 'user-abc',
        'title': 'Timora Web Release',
        'description': 'Release Web and Android',
        'category': 'Dev',
        'status': 'active',
        'color': 4280656875,
        'icon': '🚀',
        'target_date': '2026-09-30T00:00:00.000Z',
        'goal_id': 'goal-123',
        'created_at': '2026-09-01T08:00:00.000Z',
        'updated_at': '2026-09-02T08:00:00.000Z',
      };

      final project = ProjectModel.fromJson(projectRow);
      expect(project.id, 'proj-123');
      expect(project.goalId, 'goal-123');
      expect(project.targetDate?.year, 2026);

      final goalRow = {
        'id': 'goal-123',
        'user_id': 'user-abc',
        'title': 'Master Time Management',
        'description': 'Consistent routines',
        'category': 'Personal',
        'status': 'active',
        'priority': 'high',
        'icon': '🎯',
        'color': 4280656875,
        'start_date': '2026-09-01T00:00:00.000Z',
        'target_date': '2026-12-31T00:00:00.000Z',
        'progress_mode': 'auto',
        'manual_progress': 0.5,
        'notes': 'Review weekly',
        'is_deleted': false,
        'created_at': '2026-09-01T08:00:00.000Z',
        'updated_at': '2026-09-02T08:00:00.000Z',
      };

      final goal = GoalModel.fromJson(goalRow);
      expect(goal.id, 'goal-123');
      expect(goal.startDate?.month, 9);
      expect(goal.targetDate?.month, 12);
      expect(goal.manualProgress, 0.5);
    });

    test('Subtask and Milestone deserialization handle Supabase rows', () {
      final subtaskRow = {
        'id': 'sub-123',
        'user_id': 'user-abc',
        'task_id': 'task-123',
        'title': 'Implement tests',
        'is_completed': true,
        'sort_order': 2,
        'created_at': '2026-09-01T08:00:00.000Z',
        'updated_at': '2026-09-02T08:00:00.000Z',
      };

      final subtask = SubtaskModel.fromJson(subtaskRow);
      expect(subtask.id, 'sub-123');
      expect(subtask.taskId, 'task-123');
      expect(subtask.completed, isTrue);
      expect(subtask.order, 2);

      final milestoneRow = {
        'id': 'ms-123',
        'user_id': 'user-abc',
        'goal_id': 'goal-123',
        'title': 'Finish MVP',
        'description': 'All core features',
        'status': 'inProgress',
        'priority': 2,
        'sort_order': 1,
        'target_date': '2026-09-15T00:00:00.000Z',
        'created_at': '2026-09-01T08:00:00.000Z',
        'updated_at': '2026-09-02T08:00:00.000Z',
      };

      final ms = MilestoneModel.fromJson(milestoneRow);
      expect(ms.id, 'ms-123');
      expect(ms.goalId, 'goal-123');
      expect(ms.order, 1);
    });

    test('Daily, Weekly, and Monthly plans handle Supabase rows', () {
      final dailyRow = {
        'id': 'dp-123',
        'user_id': 'user-abc',
        'plan_date': '2026-09-05T00:00:00.000Z',
        'planned_duration_seconds': 7200,
        'completed_duration_seconds': 3600,
        'created_at': '2026-09-05T07:00:00.000Z',
      };
      final dp = DailyPlanModel.fromJson(dailyRow);
      expect(dp.id, 'dp-123');
      expect(dp.plannedDurationSeconds, 7200);

      final weeklyRow = {
        'id': 'wp-123',
        'user_id': 'user-abc',
        'week_start_date': '2026-09-01T00:00:00.000Z',
        'week_end_date': '2026-09-07T00:00:00.000Z',
        'planned_duration_seconds': 36000,
        'target_focus_duration_seconds': 28800,
        'created_at': '2026-09-01T00:00:00.000Z',
      };
      final wp = WeeklyPlanModel.fromJson(weeklyRow);
      expect(wp.id, 'wp-123');
      expect(wp.plannedDurationSeconds, 36000);

      final monthlyRow = {
        'id': 'mp-123',
        'user_id': 'user-abc',
        'plan_year': 2026,
        'plan_month': 9,
        'planned_duration_seconds': 144000,
        'target_focus_duration_seconds': 100000,
        'created_at': '2026-09-01T00:00:00.000Z',
      };
      final mp = MonthlyPlanModel.fromJson(monthlyRow);
      expect(mp.id, 'mp-123');
      expect(mp.year, 2026);
      expect(mp.month, 9);
    });
  });
}
