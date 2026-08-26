import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/goals/data/models/goal_model.dart';
import 'package:timora/features/goals/data/models/milestone_model.dart';
import '../providers/goal_provider.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';

class GoalCard extends ConsumerWidget {
  final GoalModel goal;
  final VoidCallback onTap;

  const GoalCard({super.key, required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(goalProgressProvider(goal.id));
    final milestonesAsync = ref.watch(milestonesProvider(goal.id));
    final tasksAsync = ref.watch(allTasksProvider);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: goal.color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                goal.color.withValues(alpha: 0.1),
                theme.colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(goal.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (goal.status == GoalStatus.paused)
                          const Text('PAUSED', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        if (goal.status == GoalStatus.completed)
                          const Text('COMPLETED', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  _buildPriorityIndicator(goal.priority),
                ],
              ),
              const SizedBox(height: 20),
              
              // Progress Section
              progressAsync.when(
                data: (progress) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progress', style: theme.textTheme.bodySmall),
                          Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: goal.color.withValues(alpha: 0.2),
                        color: goal.color,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 8,
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              
              // Stats Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      milestonesAsync.when(
                        data: (m) {
                          final completed = m.where((x) => x.status == MilestoneStatus.completed).length;
                          return Text('$completed / ${m.length}', style: theme.textTheme.bodySmall);
                        },
                        loading: () => const SizedBox(width: 20, height: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                        error: (_, __) => const Text('Err'),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.check_box_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      tasksAsync.when(
                        data: (t) {
                          final linked = t.where((x) => x.goalId == goal.id).toList();
                          final completed = linked.where((x) => x.isCompleted).length;
                          return Text('$completed / ${linked.length}', style: theme.textTheme.bodySmall);
                        },
                        loading: () => const SizedBox(width: 20, height: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                        error: (_, __) => const Text('Err'),
                      ),
                    ],
                  ),
                  if (goal.targetDate != null)
                    Row(
                      children: [
                        Icon(Icons.event, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(goal.targetDate!),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityIndicator(GoalPriority priority) {
    Color color;
    switch (priority) {
      case GoalPriority.high: color = Colors.red; break;
      case GoalPriority.medium: color = Colors.orange; break;
      case GoalPriority.low: color = Colors.blue; break;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
