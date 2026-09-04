import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/project_model.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return ProjectRepository(prefs, userId: currentUser?.id);
});

class ProjectRepository {
  static const String _defaultStorageKey = 'timora_projects_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<ProjectModel> _projects = [];

  ProjectRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _storageKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_projects_${_userId}_data'
      : _defaultStorageKey;

  void _loadFromStorage() {
    final jsonString = _prefs.getString(_storageKey);
    _projects.clear();
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        for (var item in decoded) {
          _projects.add(ProjectModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final jsonString = jsonEncode(_projects.map((p) => p.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
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

