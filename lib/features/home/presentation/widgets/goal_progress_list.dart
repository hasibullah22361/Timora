import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../goals/presentation/providers/goal_provider.dart';

class GoalProgressList extends ConsumerWidget {
  const GoalProgressList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncGoals = ref.watch(activeGoalsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Goals',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Goals tab (assuming index 3 for goals based on MainLayout structure)
                // Note: since MainLayout is stateful without a provider for navigation right now, 
                // this won't work perfectly until MainLayout is refactored, but it's here for completeness.
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        asyncGoals.when(
          data: (goals) {
            if (goals.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text("No active goals", style: TextStyle(color: Colors.grey))),
              );
            }
            final displayGoals = goals.take(2).toList();
            return Column(
              children: displayGoals.map((goal) {
                final progressAsync = ref.watch(goalProgressProvider(goal.id));
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: goal.color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(goal.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              goal.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          progressAsync.when(
                            data: (p) => Text('${(p * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: goal.color)),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      progressAsync.when(
                        data: (p) => LinearProgressIndicator(
                          value: p,
                          color: goal.color,
                          backgroundColor: goal.color.withValues(alpha: 0.1),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        loading: () => const LinearProgressIndicator(minHeight: 6),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }
}
