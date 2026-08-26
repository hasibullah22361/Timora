import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import '../../../schedule/data/models/schedule_activity.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';

class ProgressSection extends ConsumerWidget {
  const ProgressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheduleAsync = ref.watch(dailyScheduleProvider);
    final tasksAsync = ref.watch(allTasksProvider);
    final profile = ref.watch(userProfileProvider);

    // Compute Schedule completion
    double scheduleProgress = 0.0;
    scheduleAsync.whenData((activities) {
      if (activities.isNotEmpty) {
        final completed = activities.where((a) => a.status == ActivityStatus.completed).length;
        scheduleProgress = completed / activities.length;
      }
    });

    // Compute Tasks completion
    double taskProgress = 0.0;
    tasksAsync.whenData((tasks) {
      if (tasks.isNotEmpty) {
        final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
        taskProgress = completed / tasks.length;
      }
    });

    // Compute Overall Daily Productivity
    final overallProgress = ((scheduleProgress + taskProgress) / 2).clamp(0.0, 1.0);

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
            _buildProgressItem(context, 'Focus Goal', (profile.dailyGoalHours > 0 ? 0.75 : 0.0), const Color(0xFFF59E0B)),
            _buildProgressItem(context, 'Overall', overallProgress > 0 ? overallProgress : 0.5, const Color(0xFF8B5CF6)),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressItem(BuildContext context, String label, double progress, Color color) {
    final theme = Theme.of(context);
    final clamped = progress.clamp(0.0, 1.0);

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
              '${(clamped * 100).toInt()}%',
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

