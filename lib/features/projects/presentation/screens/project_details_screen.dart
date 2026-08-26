import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/projects/data/models/project_model.dart';
import '../providers/project_provider.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/tasks/presentation/widgets/task_card.dart';
import 'package:timora/features/tasks/presentation/screens/create_edit_task_sheet.dart';
import 'package:timora/features/tasks/presentation/screens/task_details_screen.dart';
import 'package:timora/features/focus/presentation/screens/focus_screen.dart';
import 'package:timora/features/daily_plan/presentation/screens/daily_plan_screen.dart';
import 'create_edit_project_sheet.dart';

class ProjectDetailsScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projectAsync = ref.watch(projectDetailsProvider(projectId));

    return projectAsync.when(
      data: (project) {
        if (project == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Project not found')));
        }
        
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditSheet(context, project),
              ),
              _buildPopupMenu(context, ref, project),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Header
              Row(
                children: [
                  Text(project.icon, style: const TextStyle(fontSize: 48)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      project.title,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (project.description.isNotEmpty) ...[
                Text(project.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
              ],
              
              // Progress
              _buildProgressSection(context, ref, project),
              const SizedBox(height: 32),
              
              // Info grid
              _buildInfoGrid(context, project),
              const SizedBox(height: 32),
              
              // Focus integration
              _buildFocusSection(context, ref, project),
              const SizedBox(height: 32),
              
              // Linked Tasks
              _buildLinkedTasksSection(context, ref, project),
              const SizedBox(height: 100),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (ctx) => CreateEditTaskSheet(
                  initialProjectId: project.id,
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Task'),
          ),
        );
      },
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $e'))),
    );
  }

  void _showEditSheet(BuildContext context, ProjectModel project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => CreateEditProjectSheet(projectToEdit: project),
    );
  }

  Widget _buildPopupMenu(BuildContext context, WidgetRef ref, ProjectModel project) {
    return PopupMenuButton<String>(
      onSelected: (val) async {
        final notifier = ref.read(projectNotifierProvider);
        if (val == 'pause') {
          await notifier.pauseProject(project);
        } else if (val == 'resume') {
          await notifier.updateProject(project.copyWith(status: ProjectStatus.active));
        } else if (val == 'complete') {
          final confirm = await _confirmDialog(context, 'Complete Project', 'Mark this project as completed?');
          if (confirm) await notifier.completeProject(project);
        } else if (val == 'delete') {
          final confirm = await _confirmDialog(context, 'Delete Project', 'Tasks will remain, but the project relationship will be removed.');
          if (confirm) {
            await notifier.deleteProject(project.id);
            if (context.mounted) Navigator.pop(context);
          }
        }
      },
      itemBuilder: (ctx) => [
        if (project.status == ProjectStatus.active) const PopupMenuItem(value: 'pause', child: Text('Pause Project')),
        if (project.status == ProjectStatus.paused) const PopupMenuItem(value: 'resume', child: Text('Resume Project')),
        if (project.status != ProjectStatus.completed) const PopupMenuItem(value: 'complete', child: Text('Complete Project')),
        const PopupMenuItem(value: 'delete', child: Text('Delete Project', style: TextStyle(color: Colors.red))),
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context, WidgetRef ref, ProjectModel project) {
    final progressAsync = ref.watch(projectProgressProvider(project.id));
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
              color: project.color,
              backgroundColor: project.color.withValues(alpha: 0.2),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildInfoGrid(BuildContext context, ProjectModel project) {
    return Row(
      children: [
        Expanded(child: _buildInfoTile(context, Icons.flag, 'Status', project.status.name.toUpperCase())),
        Expanded(
          child: _buildInfoTile(
            context, 
            Icons.event, 
            'Target Date', 
            project.targetDate != null ? DateFormat('MMM d, yyyy').format(project.targetDate!) : 'None'
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

  Widget _buildFocusSection(BuildContext context, WidgetRef ref, ProjectModel project) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyPlanScreen()));
            },
            icon: const Icon(Icons.event_available),
            label: const Text('Plan Work'),
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
                  builder: (_) => FocusScreen(initialProjectId: project.id),
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
    );
  }

  Widget _buildLinkedTasksSection(BuildContext context, WidgetRef ref, ProjectModel project) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(allTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TASKS', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
            TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (ctx) => CreateEditTaskSheet(
                    initialProjectId: project.id,
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Task'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        tasksAsync.when(
          data: (tasks) {
            final linkedTasks = tasks.where((t) => t.projectId == project.id).toList();
            if (linkedTasks.isEmpty) {
              return const Text('No tasks yet', style: TextStyle(color: Colors.grey));
            }
            
            final pendingTasks = linkedTasks.where((t) => !t.isCompleted).toList();
            final completedTasks = linkedTasks.where((t) => t.isCompleted).toList();
            
            return Column(
              children: [
                ...pendingTasks.map((t) => TaskCard(
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
                if (completedTasks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('COMPLETED', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...completedTasks.map((t) => Opacity(
                    opacity: 0.6,
                    child: TaskCard(
                      task: t,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => TaskDetailsScreen(taskId: t.id),
                          ),
                        );
                      },
                    ),
                  )),
                ],
              ],
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
