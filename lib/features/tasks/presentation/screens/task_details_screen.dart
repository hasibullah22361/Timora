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

    final isBlocked = ref.watch(isTaskBlockedProvider(task.id));
    final prerequisites = ref.watch(taskPrerequisitesProvider(task.id));
    final dependents = ref.watch(taskDependentsProvider(task.id));

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
          // Blocked Alert Banner
          if (isBlocked && !isCompleted) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This task is blocked because prerequisite tasks are still pending.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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

          // Prerequisite Dependencies List
          if (prerequisites.isNotEmpty) ...[
            Text('Prerequisites', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            ...prerequisites.map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      p.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: p.isCompleted ? const Color(0xFF10B981) : Colors.orange,
                    ),
                    title: Text(
                      p.title,
                      style: TextStyle(
                        decoration: p.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailsScreen(taskId: p.id),
                        ),
                      );
                    },
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // Dependent Tasks List
          if (dependents.isNotEmpty) ...[
            Text('Blocks Following Tasks', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            ...dependents.map((d) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.arrow_forward, color: Color(0xFF6366F1)),
                    title: Text(d.title),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailsScreen(taskId: d.id),
                        ),
                      );
                    },
                  ),
                )),
            const SizedBox(height: 16),
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
