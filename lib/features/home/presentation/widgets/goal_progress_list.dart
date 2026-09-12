import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../goals/presentation/providers/goal_provider.dart';
import '../../../goals/presentation/screens/goals_screen.dart';

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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        asyncGoals.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
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
