import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/schedule/data/activity_library.dart';
import '../../features/tasks/data/repositories/task_repository.dart';
import '../../features/schedule/data/repositories/schedule_repository.dart';
import '../../features/routine/data/repositories/routine_repository.dart';
import '../../features/projects/data/repositories/project_repository.dart';
import '../../features/goals/data/repositories/goal_repository.dart';

final suggestionServiceProvider = Provider<SuggestionService>((ref) {
  return SuggestionService(
    taskRepo: ref.watch(taskRepositoryProvider),
    scheduleRepo: ref.watch(scheduleRepositoryProvider),
    routineRepo: ref.watch(routineRepositoryProvider),
    projectRepo: ref.watch(projectRepositoryProvider),
    goalRepo: ref.watch(goalRepositoryProvider),
  );
});

class SuggestionService {
  final TaskRepository _taskRepo;
  final ScheduleRepository _scheduleRepo;
  final RoutineRepository _routineRepo;
  final ProjectRepository _projectRepo;
  final GoalRepository _goalRepo;

  SuggestionService({
    required TaskRepository taskRepo,
    required ScheduleRepository scheduleRepo,
    required RoutineRepository routineRepo,
    required ProjectRepository projectRepo,
    required GoalRepository goalRepo,
  })  : _taskRepo = taskRepo,
        _scheduleRepo = scheduleRepo,
        _routineRepo = routineRepo,
        _projectRepo = projectRepo,
        _goalRepo = goalRepo;

  /// Returns matching suggestions for the given query.
  /// Sources: predefined activities, user tasks, schedules, routines, projects, goals.
  /// Fully offline — all data is local.
  Future<List<SuggestionItem>> getSuggestions(
    String query, {
    int limit = 10,
    Set<SuggestionSource>? sources,
  }) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.trim().toLowerCase();
    final results = <SuggestionItem>{};
    final effectiveSources = sources ?? SuggestionSource.values.toSet();

    // 1. Predefined activities
    if (effectiveSources.contains(SuggestionSource.predefined)) {
      for (final activity in ActivityLibrary.defaultActivities) {
        if (_matches(activity.name, lowerQuery)) {
          results.add(SuggestionItem(
            name: activity.name,
            icon: activity.icon,
            category: activity.category,
            source: SuggestionSource.predefined,
          ));
        }
      }
    }

    // 2. User tasks
    if (effectiveSources.contains(SuggestionSource.tasks)) {
      try {
        final tasks = await _taskRepo.getTasks();
        for (final task in tasks) {
          if (_matches(task.title, lowerQuery)) {
            results.add(SuggestionItem(
              name: task.title,
              icon: '✅',
              category: task.category,
              source: SuggestionSource.tasks,
            ));
          }
        }
      } catch (_) {}
    }

    // 3. Schedule activities
    if (effectiveSources.contains(SuggestionSource.schedules)) {
      try {
        final activities = await _scheduleRepo.getAllActivities();
        for (final activity in activities) {
          if (_matches(activity.title, lowerQuery)) {
            results.add(SuggestionItem(
              name: activity.title,
              icon: activity.icon,
              category: activity.category,
              source: SuggestionSource.schedules,
            ));
          }
        }
      } catch (_) {}
    }

    // 4. Routines
    if (effectiveSources.contains(SuggestionSource.routines)) {
      try {
        final routines = await _routineRepo.getAllRoutines();
        for (final routine in routines) {
          if (_matches(routine.name, lowerQuery)) {
            results.add(SuggestionItem(
              name: routine.name,
              icon: routine.icon,
              category: 'Routine',
              source: SuggestionSource.routines,
            ));
          }
        }
      } catch (_) {}
    }

    // 5. Projects
    if (effectiveSources.contains(SuggestionSource.projects)) {
      try {
        final projects = await _projectRepo.getProjects();
        for (final project in projects) {
          if (_matches(project.title, lowerQuery)) {
            results.add(SuggestionItem(
              name: project.title,
              icon: project.icon,
              category: project.category,
              source: SuggestionSource.projects,
            ));
          }
        }
      } catch (_) {}
    }

    // 6. Goals
    if (effectiveSources.contains(SuggestionSource.goals)) {
      try {
        final goals = await _goalRepo.getGoals();
        for (final goal in goals) {
          if (_matches(goal.title, lowerQuery)) {
            results.add(SuggestionItem(
              name: goal.title,
              icon: goal.icon,
              category: goal.category,
              source: SuggestionSource.goals,
            ));
          }
        }
      } catch (_) {}
    }

    // Sort: prefix matches first, then contains matches
    final sorted = results.toList()
      ..sort((a, b) {
        final aPrefix = a.name.toLowerCase().startsWith(lowerQuery) ? 0 : 1;
        final bPrefix = b.name.toLowerCase().startsWith(lowerQuery) ? 0 : 1;
        if (aPrefix != bPrefix) return aPrefix.compareTo(bPrefix);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return sorted.take(limit).toList();
  }

  bool _matches(String name, String lowerQuery) {
    final lowerName = name.toLowerCase();
    return lowerName.contains(lowerQuery);
  }
}

enum SuggestionSource {
  predefined,
  tasks,
  schedules,
  routines,
  projects,
  goals,
}

class SuggestionItem {
  final String name;
  final String icon;
  final String category;
  final SuggestionSource source;

  const SuggestionItem({
    required this.name,
    required this.icon,
    required this.category,
    required this.source,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuggestionItem &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
