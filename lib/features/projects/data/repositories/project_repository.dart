import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../models/project_model.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ProjectRepository(prefs);
});

class ProjectRepository {
  static const String _storageKey = 'timora_projects_data';

  final SharedPreferences _prefs;
  final List<ProjectModel> _projects = [];
  final _uuid = const Uuid();

  ProjectRepository(this._prefs) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final jsonString = _prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _projects.clear();
        for (var item in decoded) {
          _projects.add(ProjectModel.fromJson(item as Map<String, dynamic>));
        }
        if (_projects.isNotEmpty) {
          return;
        }
      } catch (_) {}
    }
    _seedData();
  }

  Future<void> _saveToStorage() async {
    final jsonString = jsonEncode(_projects.map((p) => p.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }

  void _seedData() {
    final now = DateTime.now();
    _projects.add(
      ProjectModel(
        id: _uuid.v4(),
        title: 'Personal Portfolio & Brand',
        description: 'Design and launch responsive personal website and showcase work.',
        status: ProjectStatus.active,
        priority: ProjectPriority.high,
        category: 'Work',
        targetDate: now.add(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    );
    _saveToStorage();
  }

  Future<List<ProjectModel>> getProjects() async {
    return _projects.where((p) => !p.isDeleted).toList();
  }

  Future<ProjectModel?> getProject(String id) async {
    try {
      return _projects.firstWhere((p) => p.id == id && !p.isDeleted);
    } catch (_) {
      return null;
    }
  }

  Future<void> createProject(ProjectModel project) async {
    _projects.add(project);
    await _saveToStorage();
  }

  Future<void> updateProject(ProjectModel project) async {
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      _projects[index] = project.copyWith(updatedAt: DateTime.now());
      await _saveToStorage();
    }
  }

  Future<void> deleteProject(String id) async {
    final index = _projects.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _projects[index] = _projects[index].copyWith(isDeleted: true, updatedAt: DateTime.now());
      await _saveToStorage();
    }
  }
}

