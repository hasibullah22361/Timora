import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/daily_plan_model.dart';
import '../models/planned_task_block_model.dart';

final dailyPlanRepositoryProvider = Provider<DailyPlanRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return DailyPlanRepository(prefs, userId: currentUser?.id);
});

class DailyPlanRepository {
  static const String _defaultPlansKey = 'timora_daily_plans_data';
  static const String _defaultBlocksKey = 'timora_planned_blocks_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<DailyPlanModel> _plans = [];
  final List<PlannedTaskBlockModel> _blocks = [];

  DailyPlanRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _plansKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_daily_plans_${_userId}_data'
      : _defaultPlansKey;

  String get _blocksKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_planned_blocks_${_userId}_data'
      : _defaultBlocksKey;

  void _loadFromStorage() {
    final plansJson = _prefs.getString(_plansKey);
    final blocksJson = _prefs.getString(_blocksKey);

    if (plansJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(plansJson);
        _plans.clear();
        for (var item in decoded) {
          _plans.add(DailyPlanModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    if (blocksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(blocksJson);
        _blocks.clear();
        for (var item in decoded) {
          _blocks.add(PlannedTaskBlockModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final plansJson = jsonEncode(_plans.map((p) => p.toJson()).toList());
    final blocksJson = jsonEncode(_blocks.map((b) => b.toJson()).toList());
    await _prefs.setString(_plansKey, plansJson);
    await _prefs.setString(_blocksKey, blocksJson);
  }

  // --- Plans ---
  
  Future<DailyPlanModel?> getPlanForDate(DateTime date) async {
    try {
      return _plans.firstWhere((p) =>
          p.date.year == date.year &&
          p.date.month == date.month &&
          p.date.day == date.day);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlan(DailyPlanModel plan) async {
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      _plans[index] = plan;
    } else {
      _plans.add(plan);
    }
    await _saveToStorage();
  }
  
  // --- Blocks ---
  
  Future<List<PlannedTaskBlockModel>> getBlocksForDate(String dailyPlanId) async {
    return _blocks.where((b) => b.dailyPlanId == dailyPlanId).toList();
  }

  Future<void> saveBlock(PlannedTaskBlockModel block) async {
    final index = _blocks.indexWhere((b) => b.id == block.id);
    if (index >= 0) {
      _blocks[index] = block;
    } else {
      _blocks.add(block);
    }
    await _saveToStorage();
  }
  
  Future<void> saveBlocks(List<PlannedTaskBlockModel> blocks) async {
    for (var b in blocks) {
      final index = _blocks.indexWhere((existing) => existing.id == b.id);
      if (index >= 0) {
        _blocks[index] = b;
      } else {
        _blocks.add(b);
      }
    }
    await _saveToStorage();
  }

  Future<void> deleteBlock(String id) async {
    _blocks.removeWhere((b) => b.id == id);
    await _saveToStorage();
  }
}

