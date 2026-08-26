import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../data/models/export_models.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../focus/presentation/providers/focus_provider.dart';
import '../../goals/presentation/providers/goal_provider.dart';
import '../../projects/presentation/providers/project_provider.dart';
import '../../reviews/presentation/providers/review_provider.dart';
import '../../settings/presentation/providers/settings_provider.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref);
});

class ExportService {
  final Ref _ref;

  ExportService(this._ref);

  Future<void> exportData({
    required bool exportTasks,
    required bool exportFocus,
    required bool exportGoals,
    required bool exportProjects,
    required bool exportReviews,
    required bool exportSettings,
  }) async {
    final data = <String, dynamic>{};

    if (exportTasks) {
      final tasks = await _ref.read(allTasksProvider.future);
      data['tasks'] = tasks.map((t) => t.toJson()).toList();
    }
    
    if (exportFocus) {
      final sessions = await _ref.read(allFocusSessionsProvider.future);
      // Ensure FocusSessionModel has a toJson method or manually map it
      data['focusSessions'] = sessions.map((s) => {
        'id': s.id,
        'plannedDurationSeconds': s.plannedDurationSeconds,
        'actualDurationSeconds': s.actualDurationSeconds,
        'status': s.status.name,
        'createdAt': s.createdAt.toIso8601String(),
        'taskId': s.taskId,
        'projectId': s.projectId,
      }).toList();
    }

    if (exportGoals) {
      final goals = await _ref.read(allGoalsProvider.future);
      data['goals'] = goals.map((g) => {
        'id': g.id,
        'title': g.title,
        'description': g.description,
        'targetValue': 100,
        'currentValue': g.manualProgress,
        'createdAt': g.createdAt.toIso8601String(),
        'deadline': g.targetDate?.toIso8601String(),
        'status': g.status.name,
      }).toList();
    }

    if (exportProjects) {
      final projects = await _ref.read(allProjectsProvider.future);
      data['projects'] = projects.map((p) => {
        'id': p.id,
        'name': p.title,
        'description': p.description,
        'createdAt': p.createdAt.toIso8601String(),
        'deadline': p.targetDate?.toIso8601String(),
        'status': p.status.name,
        'goalId': p.goalId,
      }).toList();
    }

    if (exportReviews) {
      final reviews = await _ref.read(allReviewsProvider.future);
      data['reviews'] = reviews.map((r) => {
        'id': r.id,
        'type': r.type.name,
        'date': r.date.toIso8601String(),
        'periodStart': r.periodStart.toIso8601String(),
        'periodEnd': r.periodEnd.toIso8601String(),
        'status': r.status.name,
        'completedAt': r.completedAt?.toIso8601String(),
        'createdAt': r.createdAt.toIso8601String(),
      }).toList();
    }

    if (exportSettings) {
      final settings = _ref.read(settingsProvider);
      data['settings'] = settings.toJson();
    }

    final envelope = ExportEnvelope(
      format: 'timora',
      formatVersion: 1,
      appVersion: '1.0.0', // Read from package_info in real app
      exportedAt: DateTime.now(),
      data: data,
    );

    final jsonString = jsonEncode(envelope.toJson());
    
    // Write to temp file
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final filename = 'timora_backup_$timestamp.timora.json';
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(jsonString);

    // Share the file
    final result = await Share.shareXFiles([XFile(file.path)], text: 'Timora Backup File');
    
    // Cleanup if successful
    if (result.status == ShareResultStatus.success) {
      // Optional cleanup
    }
  }
}
