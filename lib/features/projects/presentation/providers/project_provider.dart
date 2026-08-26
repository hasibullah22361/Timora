import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/projects/data/models/project_model.dart';
import 'package:timora/features/projects/data/repositories/project_repository.dart';
import 'package:timora/features/tasks/presentation/providers/task_provider.dart';

final allProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getProjects();
});

final activeProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final projects = await ref.watch(allProjectsProvider.future);
  return projects.where((p) => p.status == ProjectStatus.active).toList();
});

final completedProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final projects = await ref.watch(allProjectsProvider.future);
  return projects.where((p) => p.status == ProjectStatus.completed).toList();
});

final pausedProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final projects = await ref.watch(allProjectsProvider.future);
  return projects.where((p) => p.status == ProjectStatus.paused).toList();
});

final archivedProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final projects = await ref.watch(allProjectsProvider.future);
  return projects.where((p) => p.status == ProjectStatus.archived).toList();
});

final projectDetailsProvider = FutureProvider.family<ProjectModel?, String>((ref, id) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getProject(id);
});

final projectProgressProvider = FutureProvider.family<double, String>((ref, projectId) async {
  final allTasks = await ref.watch(allTasksProvider.future);
  final projectTasks = allTasks.where((t) => t.projectId == projectId).toList();
  
  if (projectTasks.isEmpty) return 0.0;
  
  final completed = projectTasks.where((t) => t.isCompleted).length;
  return completed / projectTasks.length;
});

class ProjectNotifier extends StateNotifier<AsyncValue<void>> {
  final ProjectRepository _repo;
  final Ref _ref;

  ProjectNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> createProject(ProjectModel project) async {
    await _repo.createProject(project);
    _ref.invalidate(allProjectsProvider);
  }

  Future<void> updateProject(ProjectModel project) async {
    await _repo.updateProject(project);
    _ref.invalidate(allProjectsProvider);
    _ref.invalidate(projectDetailsProvider(project.id));
  }

  Future<void> deleteProject(String id) async {
    await _repo.deleteProject(id);
    _ref.invalidate(allProjectsProvider);
    _ref.invalidate(projectDetailsProvider(id));
  }
  
  Future<void> pauseProject(ProjectModel project) async {
    await _repo.updateProject(project.copyWith(status: ProjectStatus.paused));
    _ref.invalidate(allProjectsProvider);
    _ref.invalidate(projectDetailsProvider(project.id));
  }
  
  Future<void> completeProject(ProjectModel project) async {
    await _repo.updateProject(project.copyWith(status: ProjectStatus.completed, completedAt: DateTime.now()));
    _ref.invalidate(allProjectsProvider);
    _ref.invalidate(projectDetailsProvider(project.id));
  }
  
  Future<void> archiveProject(ProjectModel project) async {
    await _repo.updateProject(project.copyWith(status: ProjectStatus.archived));
    _ref.invalidate(allProjectsProvider);
    _ref.invalidate(projectDetailsProvider(project.id));
  }
}

final projectNotifierProvider = Provider<ProjectNotifier>((ref) {
  return ProjectNotifier(ref.watch(projectRepositoryProvider), ref);
});
