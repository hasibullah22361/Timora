import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'create_edit_task_sheet.dart';
import 'package:timora/features/focus/presentation/screens/focus_screen.dart';
import 'package:timora/features/daily_plan/presentation/providers/daily_plan_provider.dart';
import 'package:timora/features/daily_plan/presentation/widgets/plan_task_sheet.dart';

class TaskDetailsScreen extends ConsumerWidget {
  final String taskId;

  const TaskDetailsScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allTasks = ref.watch(allTasksProvider).valueOrNull ?? [];
    
    // Find task manually since it might be updated in list
    TaskModel? task;
    try {
      task = allTasks.firstWhere((t) => t.id == taskId);
    } catch (_) {}

    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Task not found')),
      );
    }

    final isCompleted = task.status == TaskStatus.completed;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (ctx) => CreateEditTaskSheet(taskToEdit: task),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final notifier = ref.read(taskNotifierProvider);
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete this task?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await notifier.softDeleteTask(task!);
                  if (context.mounted) Navigator.pop(context);
                }
              } else if (value == 'duplicate') {
                final duplicated = TaskModel(
                  id: UniqueKey().toString(),
                  title: '${task!.title} Copy',
                  description: task.description,
                  status: TaskStatus.pending,
                  priority: task.priority,
                  category: task.category,
                  dueDate: task.dueDate,
                  dueTime: task.dueTime,
                  reminderEnabled: task.reminderEnabled,
                  reminderMinutesBefore: task.reminderMinutesBefore,
                  notes: task.notes,
                  recurrence: task.recurrence,
                  estimatedDurationMinutes: task.estimatedDurationMinutes,
                  projectId: task.projectId,
                  goalId: task.goalId,
                  milestoneId: task.milestoneId,
                  createdAt: DateTime.now(),
                );
                await notifier.createTask(duplicated);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task duplicated')));
                  Navigator.pop(context); // Go back to list
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Task')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Task', style: TextStyle(color: Colors.red))),
            ],
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Checkbox(
                value: isCompleted,
                shape: const CircleBorder(),
                onChanged: (val) {
                  if (val == true) {
                    ref.read(taskNotifierProvider).completeTask(task!);
                  } else {
                    ref.read(taskNotifierProvider).undoCompleteTask(task!);
                  }
                },
              ),
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? theme.disabledColor : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (task.description.isNotEmpty) ...[
            Text('Description', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            Text(task.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
          ],
          
          Row(
            children: [
              Expanded(child: _buildInfoTile(context, Icons.flag, 'Priority', task.priority.name.toUpperCase())),
              Expanded(child: _buildInfoTile(context, Icons.folder, 'Category', task.category)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  context, 
                  Icons.calendar_today, 
                  'Due', 
                  task.dueDate != null ? DateFormat('MMM d, yyyy').format(task.dueDate!) : 'None'
                ),
              ),
              Expanded(
                child: _buildInfoTile(
                  context, 
                  Icons.access_time, 
                  'Time', 
                  task.dueTime != null ? task.dueTime!.format(context) : 'None'
                ),
              ),
            ],
          ),
          
          if (task.reminderEnabled && task.dueTime != null) ...[
            const SizedBox(height: 16),
            _buildInfoTile(context, Icons.notifications, 'Reminder', '${task.reminderMinutesBefore} mins before'),
          ],
          
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final date = ref.read(selectedDateProvider);
                    final planAsync = ref.read(dailyPlanProvider(date));
                    planAsync.whenData((plan) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (ctx) => PlanTaskSheet(date: date, plan: plan, initialTaskId: task!.id),
                      );
                    });
                  },
                  icon: const Icon(Icons.event_available),
                  label: const Text('Plan Task'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FocusScreen(initialTaskId: task!.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.self_improvement),
                  label: const Text('Focus'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          
          if (task.notes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Notes', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(task.notes),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
