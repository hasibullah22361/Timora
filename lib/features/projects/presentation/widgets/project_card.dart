import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timora/features/projects/data/models/project_model.dart';
import '../providers/project_provider.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';
import 'package:timora/features/goals/presentation/providers/goal_provider.dart';

class ProjectCard extends ConsumerWidget {
  final ProjectModel project;
  final VoidCallback onTap;

  const ProjectCard({super.key, required this.project, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(projectProgressProvider(project.id));
    final tasksAsync = ref.watch(allTasksProvider);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: project.color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                project.color.withValues(alpha: 0.05),
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
                  Text(project.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (project.status == ProjectStatus.paused)
                          const Text('PAUSED', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        if (project.status == ProjectStatus.completed)
                          const Text('COMPLETED', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  _buildPriorityIndicator(project.priority),
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
                        backgroundColor: project.color.withValues(alpha: 0.2),
                        color: project.color,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 8,
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              
              // Linked Goal Preview
              if (project.goalId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final goalAsync = ref.watch(goalDetailsProvider(project.goalId!));
                      return goalAsync.when(
                        data: (goal) {
                          if (goal == null) return const SizedBox.shrink();
                          return Row(
                            children: [
                              Text(goal.icon, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
                
              // Stats Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_box_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      tasksAsync.when(
                        data: (t) {
                          final linked = t.where((x) => x.projectId == project.id).toList();
                          final completed = linked.where((x) => x.isCompleted).length;
                          return Text('$completed / ${linked.length} tasks', style: theme.textTheme.bodySmall);
                        },
                        loading: () => const SizedBox(width: 20, height: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                        error: (_, __) => const Text('Err'),
                      ),
                    ],
                  ),
                  if (project.targetDate != null)
                    Row(
                      children: [
                        Icon(Icons.event, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(project.targetDate!),
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

  Widget _buildPriorityIndicator(ProjectPriority priority) {
    Color color;
    switch (priority) {
      case ProjectPriority.urgent: color = Colors.red; break;
      case ProjectPriority.high: color = Colors.orange; break;
      case ProjectPriority.medium: color = Colors.blue; break;
      case ProjectPriority.low: color = Colors.grey; break;
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
