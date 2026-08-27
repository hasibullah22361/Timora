import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import '../../../schedule/data/models/schedule_activity.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';
import '../../../focus/presentation/providers/focus_provider.dart';
import '../../../focus/data/models/focus_session_model.dart';

class ProgressSection extends ConsumerWidget {
  const ProgressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheduleAsync = ref.watch(dailyScheduleProvider);
    final todayTasksAsync = ref.watch(todayTasksProvider);
    final focusSessionsAsync = ref.watch(todayFocusSessionsProvider);
    final profile = ref.watch(userProfileProvider);

    // 1. Compute Schedule completion
    int totalActivities = 0;
    int completedActivities = 0;
    double scheduleProgress = 0.0;
    scheduleAsync.whenData((activities) {
      totalActivities = activities.length;
      if (totalActivities > 0) {
        completedActivities = activities.where((a) => a.status == ActivityStatus.completed).length;
        scheduleProgress = completedActivities / totalActivities;
      }
    });

    // 2. Compute Tasks completion (for today)
    int totalTodayTasks = 0;
    int completedTodayTasks = 0;
    double taskProgress = 0.0;
    todayTasksAsync.whenData((tasks) {
      final activeOrCompleted = tasks.where((t) => !t.isDeleted && t.status != TaskStatus.cancelled).toList();
      totalTodayTasks = activeOrCompleted.length;
      if (totalTodayTasks > 0) {
        completedTodayTasks = activeOrCompleted.where((t) => t.status == TaskStatus.completed).length;
        taskProgress = completedTodayTasks / totalTodayTasks;
      }
    });

    // 3. Compute Focus Goal completion
    double focusProgress = 0.0;
    focusSessionsAsync.whenData((sessions) {
      if (profile.dailyGoalHours > 0) {
        final totalSeconds = sessions
            .where((s) => s.status == FocusSessionStatus.completed)
            .fold<int>(0, (sum, s) => sum + s.actualDurationSeconds);
        final hoursLogged = totalSeconds / 3600.0;
        focusProgress = (hoursLogged / profile.dailyGoalHours).clamp(0.0, 1.0);
      }
    });

    // 4. Compute Overall Daily Productivity based on actual today items
    double overallProgress = 0.0;
    final totalActionableItems = totalActivities + totalTodayTasks;
    final totalCompletedItems = completedActivities + completedTodayTasks;

    if (totalActionableItems > 0) {
      overallProgress = (totalCompletedItems / totalActionableItems).clamp(0.0, 1.0);
    } else if (profile.dailyGoalHours > 0) {
      overallProgress = focusProgress;
    } else {
      overallProgress = 0.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Progress",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Goal: ${profile.dailyGoalHours.toStringAsFixed(0)}h',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildProgressItem(context, 'Schedule', scheduleProgress, const Color(0xFF2563EB)),
            _buildProgressItem(context, 'Tasks', taskProgress, const Color(0xFF10B981)),
            _buildProgressItem(context, 'Focus Goal', focusProgress, const Color(0xFFF59E0B)),
            _buildProgressItem(context, 'Overall', overallProgress, const Color(0xFF8B5CF6)),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressItem(BuildContext context, String label, double progress, Color color) {
    final theme = Theme.of(context);
    final clamped = progress.clamp(0.0, 1.0);
    final percentageInt = (clamped * 100).round();

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 58,
              width: 58,
              child: CircularProgressIndicator(
                value: clamped,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
                strokeWidth: 5.5,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              '$percentageInt%',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
