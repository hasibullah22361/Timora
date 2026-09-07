import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/cloud_sync/data/models/cloud_models.dart';
import 'package:timora/features/cloud_sync/data/repositories/sync_repository.dart';
import 'package:timora/features/cloud_sync/services/sync_service.dart';
import '../models/autopilot_action_model.dart';

final autopilotActionRepositoryProvider = Provider<AutopilotActionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AutopilotActionRepository(prefs, ref);
});

final autopilotHistoryProvider = FutureProvider<List<AutopilotActionModel>>((ref) async {
  final repo = ref.watch(autopilotActionRepositoryProvider);
  return repo.getAllActions();
});

class AutopilotActionRepository {
  static const String _storageKey = 'timora_autopilot_actions';
  final SharedPreferences _prefs;
  final Ref _ref;

  AutopilotActionRepository(this._prefs, this._ref);

  Future<List<AutopilotActionModel>> getAllActions() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => AutopilotActionModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> recordAction(AutopilotActionModel action) async {
    final list = await getAllActions();
    list.insert(0, action);

    // Trim to 500 actions
    final trimmed = list.take(500).toList();
    final jsonString = jsonEncode(trimmed.map((a) => a.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);

    try {
      await _ref.read(syncRepositoryProvider).enqueueChange(
        entityType: 'autopilot_actions',
        entityId: action.id,
        operation: SyncOperation.create,
      );
      _ref.read(syncServiceProvider).autoSync();
    } catch (_) {}
  }

  Future<void> savePulledAction(AutopilotActionModel action) async {
    final list = await getAllActions();
    final index = list.indexWhere((a) => a.id == action.id);
    if (index >= 0) {
      list[index] = action;
    } else {
      list.insert(0, action);
    }
    final trimmed = list.take(500).toList();
    final jsonString = jsonEncode(trimmed.map((a) => a.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }

  Future<int> getActionCountForEntity(String entityId) async {
    final list = await getAllActions();
    return list.where((a) => a.entityId == entityId).length;
  }
}
