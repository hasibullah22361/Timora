import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/core/theme/app_colors.dart';
import '../../data/models/task_model.dart';
import '../providers/task_provider.dart';

class TaskCard extends ConsumerWidget {
  final TaskModel task;
  final VoidCallback onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompleted = task.status == TaskStatus.completed;

    final isBlocked = ref.watch(isTaskBlockedProvider(task.id));

    return Card(
      elevation: 0,
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isBlocked && !isCompleted
              ? const Color(0xFFF59E0B).withValues(alpha: 0.7)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isBlocked && !isCompleted ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Checkbox(
                value: isCompleted,
                shape: const CircleBorder(),
                onChanged: (val) {
                  final notifier = ref.read(taskNotifierProvider);
                  if (val == true) {
                    notifier.completeTask(task);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Task completed'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () => notifier.undoCompleteTask(task),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    notifier.undoCompleteTask(task);
                  }
                },
              ),
              const SizedBox(width: 8),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              color: isCompleted ? theme.disabledColor : null,
                            ),
                          ),
                        ),
                        if (isBlocked && !isCompleted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline, size: 11, color: Color(0xFFD97706)),
                                SizedBox(width: 3),
                                Text(
                                  'Blocked',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isCompleted ? theme.disabledColor : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    
                    // Metadata Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (task.priority != TaskPriority.none)
                          _buildPriorityBadge(context, task.priority, isCompleted),
                        if (task.dueDate != null)
                          _buildDateBadge(context, task.dueDate!, task.dueTime, isCompleted),
                        _buildCategoryBadge(context, task.category, isCompleted),
                        if (task.dependsOnTaskIds.isNotEmpty && !isCompleted)
                          _buildDependencyBadge(context, task.dependsOnTaskIds.length),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDependencyBadge(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_tree_outlined, size: 10, color: Color(0xFF6366F1)),
          const SizedBox(width: 4),
          Text(
            '$count prerequisite${count > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(BuildContext context, TaskPriority priority, bool isCompleted) {
    Color color;
    String text;
    IconData icon;
    
    switch (priority) {
      case TaskPriority.low:
        color = Colors.blue;
        text = 'Low';
        icon = Icons.keyboard_arrow_down;
        break;
      case TaskPriority.medium:
        color = Colors.orange;
        text = 'Medium';
        icon = Icons.remove;
        break;
      case TaskPriority.high:
        color = Colors.redAccent;
        text = 'High';
        icon = Icons.keyboard_arrow_up;
        break;
      case TaskPriority.urgent:
        color = Colors.red;
        text = 'Urgent';
        icon = Icons.warning_amber;
        break;
      default:
        color = Colors.grey;
        text = '';
        icon = Icons.info;
    }

    if (isCompleted) color = Theme.of(context).disabledColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDateBadge(BuildContext context, DateTime date, TimeOfDay? time, bool isCompleted) {
    final theme = Theme.of(context);
    final color = isCompleted ? theme.disabledColor : theme.colorScheme.onSurfaceVariant;
    
    String text = DateFormat('MMM d').format(date);
    if (time != null) {
      text += ' • ${time.format(context)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context, String category, bool isCompleted) {
    final theme = Theme.of(context);
    final color = isCompleted ? theme.disabledColor : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(category, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}
