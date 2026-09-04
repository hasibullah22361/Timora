import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/monthly_plan_model.dart';

final monthlyPlanRepositoryProvider = Provider<MonthlyPlanRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return MonthlyPlanRepository(prefs, userId: currentUser?.id);
});

class MonthlyPlanRepository {
  static const String _defaultStorageKey = 'timora_monthly_plans_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<MonthlyPlanModel> _plans = [];

  MonthlyPlanRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _storageKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_monthly_plans_${_userId}_data'
      : _defaultStorageKey;

  void _loadFromStorage() {
    final jsonString = _prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _plans.clear();
        for (var item in decoded) {
          _plans.add(MonthlyPlanModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final jsonString = jsonEncode(_plans.map((p) => p.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }

  Future<MonthlyPlanModel?> getPlanForMonth(int year, int month) async {
    try {
      return _plans.firstWhere((p) => p.year == year && p.month == month);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlan(MonthlyPlanModel plan) async {
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      _plans[index] = plan;
    } else {
      _plans.add(plan);
    }
    await _saveToStorage();
  }

  Future<MonthlyPlanModel?> deletePlan(String id) async {
    final index = _plans.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final removed = _plans.removeAt(index);
      await _saveToStorage();
      return removed;
    }
    return null;
  }

  Future<MonthlyPlanModel?> deletePlanForMonth(int year, int month) async {
    final index = _plans.indexWhere((p) => p.year == year && p.month == month);
    if (index >= 0) {
      final removed = _plans.removeAt(index);
      await _saveToStorage();
      return removed;
    }
    return null;
  }
}

