import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import '../../../schedule/data/models/schedule_activity.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../focus/presentation/providers/focus_provider.dart';
import '../../../focus/data/models/focus_session_model.dart';
import '../../../analytics/presentation/screens/analytics_screen.dart';

class ProgressSection extends ConsumerWidget {
  const ProgressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(dailyScheduleProvider);
    final todayTasksAsync = ref.watch(todayTasksProvider);
    final focusSessionsAsync = ref.watch(todayFocusSessionsProvider);
    final timerState = ref.watch(focusTimerProvider);

    // 1. Compute Schedule completion
    int totalActivities = 0;
    int completedActivities = 0;
    scheduleAsync.whenData((activities) {
      totalActivities = activities.length;
      if (totalActivities > 0) {
        completedActivities = activities.where((a) => a.status == ActivityStatus.completed).length;
      }
    });

    // 2. Compute Tasks completion (for today)
    int totalTodayTasks = 0;
    int completedTodayTasks = 0;
    todayTasksAsync.whenData((tasks) {
      final activeOrCompleted = tasks.where((t) => !t.isDeleted && t.status != TaskStatus.cancelled).toList();
      totalTodayTasks = activeOrCompleted.length;
      if (totalTodayTasks > 0) {
        completedTodayTasks = activeOrCompleted.where((t) => t.status == TaskStatus.completed).length;
      }
    });

    // 3. Compute Focus Duration (actual logged focus time + current active focus session)
    int totalFocusSeconds = 0;
    focusSessionsAsync.whenData((sessions) {
      totalFocusSeconds = sessions
          .where((s) => s.status == FocusSessionStatus.completed)
          .fold<int>(0, (sum, s) => sum + s.actualDurationSeconds);
    });

    if (timerState.activeSession != null &&
        (timerState.activeSession!.status == FocusSessionStatus.running ||
            timerState.activeSession!.status == FocusSessionStatus.paused ||
            timerState.activeSession!.status == FocusSessionStatus.breakTime)) {
      totalFocusSeconds += timerState.elapsedSeconds;
    }

    final focusHours = totalFocusSeconds ~/ 3600;
    final focusMins = (totalFocusSeconds % 3600) ~/ 60;
    final focusStr = totalFocusSeconds > 0
        ? '${focusHours > 0 ? '${focusHours}h ' : ''}${focusMins}m'
        : '0m';

    final tasksDoneDisplay = '$completedTodayTasks';

    // 4. Compute Overall Daily Productivity
    final totalActionable = totalActivities + totalTodayTasks;
    final totalCompleted = completedActivities + completedTodayTasks;
    final productivityPct = totalActionable > 0
        ? ((totalCompleted / totalActionable) * 100).round()
        : 0;

    // 5. Focus Score: 2 pts per focus min + 20 pts per completed task
    final computedScore = ((totalFocusSeconds / 60) * 2 + completedTodayTasks * 20).round();
    final focusScoreDisplay = '$computedScore';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Today's Progress + See Details ->
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Progress",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                );
              },
              child: Row(
                children: [
                  Text(
                    'See Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Segmented Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C1322) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF172033) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Metric 1: Focused
              Expanded(
                child: _buildMetric(
                  context: context,
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  value: focusStr,
                  label: 'Focused',
                ),
              ),
              _buildDivider(isDark),
              // Metric 2: Tasks Done
              Expanded(
                child: _buildMetric(
                  context: context,
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF22C55E),
                  value: tasksDoneDisplay,
                  label: 'Tasks Done',
                ),
              ),
              _buildDivider(isDark),
              // Metric 3: Productivity
              Expanded(
                child: _buildMetric(
                  context: context,
                  icon: Icons.gps_fixed_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  value: '$productivityPct%',
                  label: 'Productivity',
                ),
              ),
              _buildDivider(isDark),
              // Metric 4: Focus Score
              Expanded(
                child: _buildMetric(
                  context: context,
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  value: focusScoreDisplay,
                  label: 'Focus Score',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 44,
      color: isDark ? const Color(0xFF1A2438) : const Color(0xFFF1F5F9),
    );
  }

  Widget _buildMetric({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}


