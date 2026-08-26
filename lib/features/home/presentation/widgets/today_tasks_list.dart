import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main_layout/presentation/providers/navigation_provider.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../../../tasks/data/models/task_model.dart';

class TodayTasksList extends ConsumerWidget {
  const TodayTasksList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncTasks = ref.watch(todayTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Tasks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Tasks tab (index 2 based on main layout)
                ref.read(navigationIndexProvider.notifier).state = 2;
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        asyncTasks.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text("You're clear for today 🎉", style: TextStyle(color: Colors.grey))),
              );
            }
            final displayTasks = tasks.take(3).toList();
            return Column(
              children: displayTasks.map((task) => _buildTaskItem(context, ref, task)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }

  Widget _buildTaskItem(BuildContext context, WidgetRef ref, TaskModel task) {
    final theme = Theme.of(context);
    final isCompleted = task.status == TaskStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Checkbox(
          value: isCompleted,
          shape: const CircleBorder(),
          onChanged: (val) {
             if (val == true) {
               ref.read(taskNotifierProvider).completeTask(task);
             } else {
               ref.read(taskNotifierProvider).undoCompleteTask(task);
             }
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? theme.disabledColor : null,
          ),
        ),
        trailing: _buildPriorityChip(context, task.priority, isCompleted),
      ),
    );
  }

  Widget _buildPriorityChip(BuildContext context, TaskPriority priority, bool isCompleted) {
    Color color;
    String text;

    switch (priority) {
      case TaskPriority.low:
        color = Colors.blue;
        text = 'Low';
        break;
      case TaskPriority.medium:
        color = Colors.orange;
        text = 'Medium';
        break;
      case TaskPriority.high:
        color = Colors.redAccent;
        text = 'High';
        break;
      case TaskPriority.urgent:
        color = Colors.red;
        text = 'Urgent';
        break;
      default:
        color = Colors.grey;
        text = 'None';
    }

    if (isCompleted) color = Theme.of(context).disabledColor;
    if (priority == TaskPriority.none) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
