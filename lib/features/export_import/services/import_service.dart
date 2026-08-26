import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/export_models.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';
import '../../goals/presentation/providers/goal_provider.dart';
import '../../goals/data/models/goal_model.dart';
import '../../goals/data/repositories/goal_repository.dart';
import '../../projects/presentation/providers/project_provider.dart';
import '../../projects/data/models/project_model.dart';
import '../../projects/data/repositories/project_repository.dart';

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref);
});

class ImportService {
  final Ref _ref;

  ImportService(this._ref);

  Future<ExportEnvelope?> pickAndValidateBackup() async {
    final files = await FilePicker.pickFiles(
      type: FileType.any,
    );

    if (files.isEmpty) {
      return null;
    }

    final selectedFile = files.first;

    if (selectedFile.path == null) {
      throw Exception('Unable to access the selected backup file.');
    }

    final file = File(selectedFile.path!);
    final content = await file.readAsString();

    try {
      final jsonMap = jsonDecode(content);

      if (jsonMap is! Map<String, dynamic>) {
        throw Exception('Invalid backup file structure.');
      }

      final envelope = ExportEnvelope.fromJson(jsonMap);

      if (envelope.format != 'timora') {
        throw Exception('Invalid file format. Not a Timora backup.');
      }

      if (envelope.formatVersion > 1) {
        throw Exception(
          'This backup was created by a newer version of Timora. '
          'Please update the app.',
        );
      }

      return envelope;
    } catch (e) {
      throw Exception('Failed to read backup: $e');
    }
  }

  ImportPreviewModel generatePreview(ExportEnvelope envelope) {
    final data = envelope.data;

    return ImportPreviewModel(
      taskCount: (data['tasks'] as List?)?.length ?? 0,
      focusSessionCount: (data['focusSessions'] as List?)?.length ?? 0,
      goalCount: (data['goals'] as List?)?.length ?? 0,
      projectCount: (data['projects'] as List?)?.length ?? 0,
      reviewCount: (data['reviews'] as List?)?.length ?? 0,
      exportedAt: envelope.exportedAt,
      formatVersion: envelope.formatVersion,
    );
  }

  Future<void> executeImport(
    ExportEnvelope envelope, {
    required bool replace,
  }) async {
    // 1. Transaction Simulation
    // In our MVP, we don't have SQL transactions.
    // Everything is parsed before providers are modified.

    final Map<String, dynamic> data = envelope.data;

    // Parse Tasks
    final importedTasks = <TaskModel>[];

    if (data['tasks'] != null) {
      for (final json in data['tasks']) {
        importedTasks.add(
          TaskModel(
            id: json['id'],
            title: json['title'] ?? 'Imported Task',
            createdAt:
                DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
          ),
        );
      }
    }

    // Parse Goals
    final importedGoals = <GoalModel>[];

    if (data['goals'] != null) {
      for (final json in data['goals']) {
        importedGoals.add(
          GoalModel(
            id: json['id'],
            title: json['title'] ?? 'Imported Goal',
            manualProgress: json['currentValue'] ?? 0.0,
            createdAt:
                DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
          ),
        );
      }
    }

    // Parse Projects
    final importedProjects = <ProjectModel>[];

    if (data['projects'] != null) {
      for (final json in data['projects']) {
        importedProjects.add(
          ProjectModel(
            id: json['id'],
            title: json['name'] ?? 'Imported Project',
            createdAt:
                DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
          ),
        );
      }
    }

    // 2. Execution (Replace or Merge)
    //
    // REPLACE:
    // In the current MVP, repositories don't expose a complete database
    // wipe/overwrite operation, so imported records are added.
    if (replace) {
      for (final task in importedTasks) {
        await _ref.read(taskRepositoryProvider).createTask(task);
      }

      for (final goal in importedGoals) {
        await _ref.read(goalRepositoryProvider).createGoal(goal);
      }

      for (final project in importedProjects) {
        await _ref.read(projectRepositoryProvider).createProject(project);
      }
    }

    // MERGE:
    else {
      // Upsert logic is delegated to repositories.
      for (final task in importedTasks) {
        await _ref.read(taskRepositoryProvider).createTask(task);
      }

      for (final goal in importedGoals) {
        await _ref.read(goalRepositoryProvider).createGoal(goal);
      }

      for (final project in importedProjects) {
        await _ref.read(projectRepositoryProvider).createProject(project);
      }
    }

    // Invalidate everything so UI redraws.
    _ref.invalidate(allTasksProvider);
    _ref.invalidate(allGoalsProvider);
    _ref.invalidate(allProjectsProvider);
  }
}
