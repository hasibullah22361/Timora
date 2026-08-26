import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';
import '../providers/schedule_provider.dart';
import 'add_edit_activity_sheet.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/tasks/presentation/screens/create_edit_task_sheet.dart';
import 'package:timora/features/tasks/presentation/screens/task_details_screen.dart';
import 'package:timora/features/tasks/presentation/widgets/task_card.dart';

class ActivityDetailsSheet extends ConsumerWidget {
  final ScheduleActivity activity;

  const ActivityDetailsSheet({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final format = DateFormat('h:mm a');
    final duration = activity.endTime.difference(activity.startTime);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(activity.icon, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        activity.category,
                        style: TextStyle(color: activity.color, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddEditActivitySheet(activityToEdit: activity),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(context, Icons.access_time_rounded, '${format.format(activity.startTime)} – ${format.format(activity.endTime)} (${duration.inHours}h ${duration.inMinutes % 60}m)'),
            const SizedBox(height: 16),
            if (activity.description.isNotEmpty) ...[
              _buildDetailRow(context, Icons.notes_rounded, activity.description),
              const SizedBox(height: 16),
            ],
            _buildDetailRow(context, Icons.info_outline_rounded, 'Status: ${activity.status.name.toUpperCase()}'),
            const SizedBox(height: 16),
            
            // Linked Tasks
            _buildLinkedTasks(context, ref),
            
            const SizedBox(height: 32),
            Row(
              children: [
                if (activity.status == ActivityStatus.current || activity.status == ActivityStatus.upcoming) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Start Focus mode in later phase
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${activity.title} started.')));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activity.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Start'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (activity.status != ActivityStatus.completed) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(scheduleNotifierProvider).markCompleted(activity);
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                      child: const Text('Complete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (activity.status != ActivityStatus.skipped) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirm = await _showConfirmDialog(context, 'Skip this activity?');
                        if (confirm == true) {
                          await ref.read(scheduleNotifierProvider).markSkipped(activity);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.grey,
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (activity.isOverridden) ...[
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final confirm = await _showConfirmDialog(context, 'Reset to Routine template?');
                    if (confirm == true) {
                      await ref.read(scheduleNotifierProvider).resetToRoutine(activity);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Colors.blue),
                  label: const Text('Reset to Routine', style: TextStyle(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final confirm = await _showConfirmDialog(context, 'Delete this activity?');
                  if (confirm == true) {
                    await ref.read(scheduleNotifierProvider).deleteActivity(activity.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Delete Activity', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildLinkedTasks(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allTasks = ref.watch(allTasksProvider).valueOrNull ?? [];
    final linkedTasks = allTasks.where((t) => t.scheduleActivityId == activity.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Linked Tasks', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (ctx) => CreateEditTaskSheet(initialScheduleActivityId: activity.id),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        if (linkedTasks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 32, top: 4),
            child: Text('No tasks linked', style: TextStyle(color: Colors.grey)),
          )
        else
          ...linkedTasks.map((t) => TaskCard(
                task: t,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => TaskDetailsScreen(taskId: t.id),
                    ),
                  );
                },
              )),
      ],
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
  }
}
