import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../weekly_plan/presentation/providers/weekly_plan_provider.dart';
import '../../../weekly_plan/presentation/screens/weekly_plan_screen.dart';

class ThisWeekWidget extends ConsumerWidget {
  const ThisWeekWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weekStart = getStartOfWeek(DateTime.now());
    final statsAsync = ref.watch(weeklyStatsProvider(weekStart));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'This Week',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyPlanScreen()));
              },
              child: const Text('Open Planner'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyPlanScreen()));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
            ),
            child: statsAsync.when(
              data: (stats) {
                final progress = stats.totalTasks == 0 ? 0.0 : stats.completedTasks / stats.totalTasks;
                
                return Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.date_range, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          '${stats.completedTasks} / ${stats.totalTasks} tasks',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: theme.colorScheme.surface,
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ),
      ],
    );
  }
}
