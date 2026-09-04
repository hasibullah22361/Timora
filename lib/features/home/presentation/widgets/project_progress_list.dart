import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../projects/presentation/providers/project_provider.dart';
import '../../../projects/presentation/screens/projects_screen.dart';

class ProjectProgressList extends ConsumerWidget {
  const ProjectProgressList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncProjects = ref.watch(activeProjectsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Projects',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProjectsScreen()),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        asyncProjects.when(
          data: (projects) {
            if (projects.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text("No active projects", style: TextStyle(color: Colors.grey))),
              );
            }
            final displayProjects = projects.take(2).toList();
            return Column(
              children: displayProjects.map((project) {
                final progressAsync = ref.watch(projectProgressProvider(project.id));
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: project.color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(project.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              project.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          progressAsync.when(
                            data: (p) => Text('${(p * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: project.color)),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      progressAsync.when(
                        data: (p) => LinearProgressIndicator(
                          value: p,
                          color: project.color,
                          backgroundColor: project.color.withValues(alpha: 0.1),
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
