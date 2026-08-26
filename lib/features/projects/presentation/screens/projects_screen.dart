import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/project_provider.dart';
import '../../data/models/project_model.dart';
import '../widgets/project_card.dart';
import 'create_edit_project_sheet.dart';
import 'project_details_screen.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Projects', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Search functionality
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'ACTIVE'),
                Tab(text: 'COMPLETED'),
                Tab(text: 'PAUSED'),
                Tab(text: 'ARCHIVED'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildProjectsList(ref, activeProjectsProvider, 'No active projects'),
                  _buildProjectsList(ref, completedProjectsProvider, 'No completed projects'),
                  _buildProjectsList(ref, pausedProjectsProvider, 'No paused projects'),
                  _buildProjectsList(ref, archivedProjectsProvider, 'No archived projects'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (ctx) => const CreateEditProjectSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Project'),
      ),
    );
  }

  Widget _buildProjectsList(WidgetRef ref, FutureProvider<List<ProjectModel>> provider, String emptyMsg) {
    final asyncProjects = ref.watch(provider);
    
    return asyncProjects.when(
      data: (projects) {
        if (projects.isEmpty) {
          return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 100),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return ProjectCard(
              project: project,
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => ProjectDetailsScreen(projectId: project.id))
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
