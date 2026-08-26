import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/goals/data/models/goal_model.dart';
import 'package:timora/features/goals/data/models/milestone_model.dart';
import '../providers/goal_provider.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/tasks/presentation/widgets/task_card.dart';
import 'package:timora/features/tasks/presentation/screens/create_edit_task_sheet.dart';
import 'package:timora/features/tasks/presentation/screens/task_details_screen.dart';
import 'create_edit_goal_sheet.dart';
import 'create_edit_milestone_sheet.dart';

class GoalDetailsScreen extends ConsumerWidget {
  final String goalId;

  const GoalDetailsScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goalAsync = ref.watch(goalDetailsProvider(goalId));

    return goalAsync.when(
      data: (goal) {
        if (goal == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Goal not found')));
        }
        
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditSheet(context, goal),
              ),
              _buildPopupMenu(context, ref, goal),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Header
              Row(
                children: [
                  Text(goal.icon, style: const TextStyle(fontSize: 48)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      goal.title,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (goal.description.isNotEmpty) ...[
                Text(goal.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
              ],
              
              // Progress
              _buildProgressSection(context, ref, goal),
              const SizedBox(height: 32),
              
              // Info grid
              _buildInfoGrid(context, goal),
              const SizedBox(height: 32),
              
              // Milestones
              _buildMilestonesSection(context, ref, goal),
              const SizedBox(height: 32),
              
              // Linked Tasks
              _buildLinkedTasksSection(context, ref, goal),
              const SizedBox(height: 100),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (ctx) => CreateEditMilestoneSheet(goalId: goal.id),
              );
            },
            child: const Icon(Icons.flag),
          ),
        );
      },
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $e'))),
    );
  }

  void _showEditSheet(BuildContext context, GoalModel goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => CreateEditGoalSheet(goalToEdit: goal),
    );
  }

  Widget _buildPopupMenu(BuildContext context, WidgetRef ref, GoalModel goal) {
    return PopupMenuButton<String>(
      onSelected: (val) async {
        final notifier = ref.read(goalNotifierProvider);
        if (val == 'pause') {
          await notifier.pauseGoal(goal);
        } else if (val == 'resume') {
          await notifier.resumeGoal(goal);
        } else if (val == 'complete') {
          final confirm = await _confirmDialog(context, 'Complete Goal', 'Mark this goal as completed?');
          if (confirm) await notifier.completeGoal(goal);
        } else if (val == 'delete') {
          final confirm = await _confirmDialog(context, 'Delete Goal', 'Linked tasks will remain, but milestons will be deleted.');
          if (confirm) {
            await notifier.deleteGoal(goal.id);
            if (context.mounted) Navigator.pop(context);
          }
        }
      },
      itemBuilder: (ctx) => [
        if (goal.status == GoalStatus.active) const PopupMenuItem(value: 'pause', child: Text('Pause Goal')),
        if (goal.status == GoalStatus.paused) const PopupMenuItem(value: 'resume', child: Text('Resume Goal')),
        if (goal.status != GoalStatus.completed) const PopupMenuItem(value: 'complete', child: Text('Complete Goal')),
        const PopupMenuItem(value: 'delete', child: Text('Delete Goal', style: TextStyle(color: Colors.red))),
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context, WidgetRef ref, GoalModel goal) {
    final progressAsync = ref.watch(goalProgressProvider(goal.id));
    final theme = Theme.of(context);
    
    return progressAsync.when(
      data: (progress) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('OVERALL PROGRESS', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
                Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              color: goal.color,
              backgroundColor: goal.color.withValues(alpha: 0.2),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildInfoGrid(BuildContext context, GoalModel goal) {
    return Row(
      children: [
        Expanded(child: _buildInfoTile(context, Icons.flag, 'Status', goal.status.name.toUpperCase())),
        Expanded(
          child: _buildInfoTile(
            context, 
            Icons.event, 
            'Target Date', 
            goal.targetDate != null ? DateFormat('MMM d, yyyy').format(goal.targetDate!) : 'None'
          ),
        ),
      ],
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

  Widget _buildMilestonesSection(BuildContext context, WidgetRef ref, GoalModel goal) {
    final milestonesAsync = ref.watch(milestonesProvider(goal.id));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MILESTONES', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 16),
        milestonesAsync.when(
          data: (milestones) {
            if (milestones.isEmpty) {
              return const Text('No milestones yet', style: TextStyle(color: Colors.grey));
            }
            return ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final items = List<MilestoneModel>.from(milestones);
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                ref.read(goalNotifierProvider).reorderMilestones(goal.id, items);
              },
              children: milestones.map((m) => _buildMilestoneTile(context, ref, m)).toList(),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Error loading milestones'),
        ),
      ],
    );
  }

  Widget _buildMilestoneTile(BuildContext context, WidgetRef ref, MilestoneModel m) {
    final theme = Theme.of(context);
    final isDone = m.status == MilestoneStatus.completed;

    return Container(
      key: ValueKey(m.id),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Checkbox(
          value: isDone,
          onChanged: (val) {
            final status = val == true ? MilestoneStatus.completed : MilestoneStatus.notStarted;
            ref.read(goalNotifierProvider).updateMilestone(m.copyWith(status: status));
          },
          shape: const CircleBorder(),
        ),
        title: Text(
          m.title,
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? theme.disabledColor : null,
          ),
        ),
        trailing: const Icon(Icons.drag_handle),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (ctx) => CreateEditMilestoneSheet(goalId: m.goalId, milestoneToEdit: m),
          );
        },
      ),
    );
  }

  Widget _buildLinkedTasksSection(BuildContext context, WidgetRef ref, GoalModel goal) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(allTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LINKED TASKS', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
            TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (ctx) => CreateEditTaskSheet(
                    initialGoalId: goal.id,
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Task'),
            ),
          ],
        ),
        tasksAsync.when(
          data: (tasks) {
            final linkedTasks = tasks.where((t) => t.goalId == goal.id).toList();
            if (linkedTasks.isEmpty) {
              return const Text('No linked tasks', style: TextStyle(color: Colors.grey));
            }
            return Column(
              children: linkedTasks.map((t) => TaskCard(
                task: t,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => TaskDetailsScreen(taskId: t.id),
                    ),
                  );
                },
              )).toList(),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Error loading tasks'),
        ),
      ],
    );
  }

  Future<bool> _confirmDialog(BuildContext context, String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    return result ?? false;
  }
}
