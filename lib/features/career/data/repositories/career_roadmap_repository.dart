import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../tasks/presentation/providers/task_provider.dart';
import '../../../analytics/services/productivity_event_service.dart';
import '../models/career_roadmap_model.dart';
import '../models/career_milestone_model.dart';

final careerRoadmapRepositoryProvider = Provider<CareerRoadmapRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CareerRoadmapRepository(prefs, ref);
});

final activeRoadmapProvider = FutureProvider<CareerRoadmapModel?>((ref) async {
  final repo = ref.read(careerRoadmapRepositoryProvider);
  return repo.getActiveRoadmap();
});

final roadmapMilestonesProvider = FutureProvider.family<List<CareerMilestoneModel>, String>((ref, roadmapId) async {
  final repo = ref.read(careerRoadmapRepositoryProvider);
  return repo.getMilestonesForRoadmap(roadmapId);
});

class CareerRoadmapRepository {
  static const String _roadmapsKey = 'timora_career_roadmaps';
  static const String _milestonesKey = 'timora_career_milestones';
  final SharedPreferences _prefs;
  final Ref _ref;

  CareerRoadmapRepository(this._prefs, this._ref);

  Future<CareerRoadmapModel?> getActiveRoadmap() async {
    final list = await getRoadmaps();
    if (list.isNotEmpty) return list.first;
    return initializeDefaultIfEmpty();
  }

  Future<List<CareerRoadmapModel>> getRoadmaps() async {
    final raw = _prefs.getString(_roadmapsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CareerRoadmapModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<CareerRoadmapModel> initializeDefaultIfEmpty() async {
    final list = await getRoadmaps();
    if (list.isNotEmpty) return list.first;

    final defaultRoadmap = CareerRoadmapModel(
      id: 'roadmap_ai_engineer',
      title: 'AI & Machine Learning Engineer',
      description: 'End-to-end pathway from programming and mathematical foundation to production deep learning systems.',
      targetRole: 'Senior AI Engineer',
      status: CareerRoadmapStatus.inProgress,
      progress: 25.0,
    );
    await saveRoadmap(defaultRoadmap, invalidateProvider: false);
    await _seedDefaultMilestones('roadmap_ai_engineer');
    return defaultRoadmap;
  }

  Future<void> _seedDefaultMilestones(String roadmapId) async {
    final defaultMilestones = [
      CareerMilestoneModel(
        roadmapId: roadmapId,
        title: 'Python Programming Mastery',
        description: 'Object-oriented programming, data structures, and asynchronous workflows in Python.',
        status: CareerMilestoneStatus.completed,
        priority: 'High',
        progress: 100,
        sortOrder: 0,
      ),
      CareerMilestoneModel(
        roadmapId: roadmapId,
        title: 'Mathematical Foundations',
        description: 'Linear algebra, multivariate calculus, and statistical inference for AI.',
        status: CareerMilestoneStatus.inProgress,
        priority: 'High',
        progress: 60,
        sortOrder: 1,
      ),
      CareerMilestoneModel(
        roadmapId: roadmapId,
        title: 'Classic Machine Learning',
        description: 'Regression, tree ensembles, SVMs, and unsupervised clustering with scikit-learn.',
        status: CareerMilestoneStatus.inProgress,
        priority: 'High',
        progress: 30,
        sortOrder: 2,
      ),
      CareerMilestoneModel(
        roadmapId: roadmapId,
        title: 'Deep Learning & Neural Networks',
        description: 'PyTorch fundamentals, CNN architectures, optimization, and transfer learning.',
        status: CareerMilestoneStatus.notStarted,
        priority: 'High',
        progress: 0,
        sortOrder: 3,
      ),
      CareerMilestoneModel(
        roadmapId: roadmapId,
        title: 'Transformers & Large Language Models',
        description: 'Attention mechanisms, fine-tuning, RAG architectures, and agentic workflows.',
        status: CareerMilestoneStatus.notStarted,
        priority: 'High',
        progress: 0,
        sortOrder: 4,
      ),
      CareerMilestoneModel(
        roadmapId: roadmapId,
        title: 'Production Capstone & Portfolio',
        description: 'Deploy real-time inference services and build public GitHub showcase.',
        status: CareerMilestoneStatus.notStarted,
        priority: 'Medium',
        progress: 0,
        sortOrder: 5,
      ),
    ];

    final list = await getAllMilestones();
    for (final m in defaultMilestones) {
      final index = list.indexWhere((x) => x.id == m.id);
      if (index >= 0) {
        list[index] = m;
      } else {
        list.add(m);
      }
    }
    final jsonString = jsonEncode(list.map((m) => m.toJson()).toList());
    await _prefs.setString(_milestonesKey, jsonString);

    try {
      for (final m in defaultMilestones) {
        await _ref.read(syncRepositoryProvider).enqueueChange(
          entityType: 'career_milestones',
          entityId: m.id,
          operation: SyncOperation.create,
        );
      }
      _ref.read(syncServiceProvider).autoSync();
    } catch (_) {}
  }

  Future<void> saveRoadmap(CareerRoadmapModel roadmap, {bool invalidateProvider = true}) async {
    final raw = _prefs.getString(_roadmapsKey);
    List<CareerRoadmapModel> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        list = decoded
            .map((item) => CareerRoadmapModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {}
    }
    final index = list.indexWhere((r) => r.id == roadmap.id);
    if (index >= 0) {
      list[index] = roadmap;
    } else {
      list.insert(0, roadmap);
    }

    final jsonString = jsonEncode(list.map((r) => r.toJson()).toList());
    await _prefs.setString(_roadmapsKey, jsonString);

    try {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'career_roadmaps',
        entityId: roadmap.id,
        operation: index >= 0 ? SyncOperation.update : SyncOperation.create,
      );
      _ref.read(syncServiceProvider).autoSync();
    } catch (_) {}

    if (invalidateProvider) {
      _ref.invalidate(activeRoadmapProvider);
    }
  }

  Future<List<CareerMilestoneModel>> getAllMilestones() async {
    final raw = _prefs.getString(_milestonesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CareerMilestoneModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<CareerMilestoneModel>> getMilestonesForRoadmap(String roadmapId) async {
    final all = await getAllMilestones();
    final list = all.where((m) => m.roadmapId == roadmapId).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<void> saveMilestone(CareerMilestoneModel milestone) async {
    final list = await getAllMilestones();
    final index = list.indexWhere((m) => m.id == milestone.id);
    if (index >= 0) {
      list[index] = milestone;
    } else {
      list.add(milestone);
    }

    final jsonString = jsonEncode(list.map((m) => m.toJson()).toList());
    await _prefs.setString(_milestonesKey, jsonString);

    try {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'career_milestones',
        entityId: milestone.id,
        operation: index >= 0 ? SyncOperation.update : SyncOperation.create,
      );
      _ref.read(syncServiceProvider).autoSync();
    } catch (_) {}

    // If milestone completed, log productivity event
    if (milestone.progress >= 100 || milestone.status == CareerMilestoneStatus.completed) {
      try {
        await _ref.read(productivityEventServiceProvider).logCareerMilestoneCompleted(
              milestone.id,
              milestone.title,
            );
      } catch (_) {}
    }

    _ref.invalidate(roadmapMilestonesProvider(milestone.roadmapId));
    await _recalculateRoadmapProgress(milestone.roadmapId);
  }

  Future<void> _recalculateRoadmapProgress(String roadmapId) async {
    final milestones = await getMilestonesForRoadmap(roadmapId);
    if (milestones.isEmpty) return;

    final total = milestones.fold<int>(0, (sum, m) => sum + m.progress);
    final overall = (total / (milestones.length * 100)) * 100;

    final roadmaps = await getRoadmaps();
    final roadmap = roadmaps.where((r) => r.id == roadmapId).firstOrNull;
    if (roadmap != null) {
      await saveRoadmap(roadmap.copyWith(progress: double.parse(overall.toStringAsFixed(1))));
    }
  }

  Future<void> convertMilestoneToTimoraTask(CareerMilestoneModel milestone) async {
    final taskId = const Uuid().v4();
    final task = TaskModel(
      id: taskId,
      title: 'Milestone: ${milestone.title}',
      description: milestone.description,
      priority: milestone.priority == 'High' ? TaskPriority.high : TaskPriority.medium,
      category: 'Career',
      dueDate: milestone.targetDate ?? DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
    );

    await _ref.read(taskNotifierProvider).createTask(task);
    await saveMilestone(milestone.copyWith(linkedTaskId: taskId));
  }

  Future<void> deleteMilestone(String id, String roadmapId) async {
    final list = await getAllMilestones();
    list.removeWhere((m) => m.id == id);
    final jsonString = jsonEncode(list.map((m) => m.toJson()).toList());
    await _prefs.setString(_milestonesKey, jsonString);

    try {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'career_milestones',
        entityId: id,
        operation: SyncOperation.delete,
      );
      _ref.read(syncServiceProvider).autoSync();
    } catch (_) {}

    _ref.invalidate(roadmapMilestonesProvider(roadmapId));
    await _recalculateRoadmapProgress(roadmapId);
  }
}
