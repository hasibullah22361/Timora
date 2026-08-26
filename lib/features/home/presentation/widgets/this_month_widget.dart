import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../monthly_plan/presentation/providers/monthly_plan_provider.dart';
import '../../../monthly_plan/presentation/screens/monthly_plan_screen.dart';

class ThisMonthWidget extends ConsumerWidget {
  const ThisMonthWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final statsAsync = ref.watch(monthlyStatsProvider(monthStart));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'This Month',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyPlanScreen()));
              },
              child: const Text('Open Planner'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyPlanScreen()));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.1)),
            ),
            child: statsAsync.when(
              data: (stats) {
                final progress = stats.totalTasks == 0 ? 0.0 : stats.completedTasks / stats.totalTasks;
                
                return Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month, color: theme.colorScheme.secondary),
                        const SizedBox(width: 12),
                        Text(
                          '${stats.completedTasks} / ${stats.totalTasks} tasks',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: theme.colorScheme.surface,
                      color: theme.colorScheme.secondary,
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
