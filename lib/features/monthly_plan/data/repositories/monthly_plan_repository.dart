import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../models/monthly_plan_model.dart';

final monthlyPlanRepositoryProvider = Provider<MonthlyPlanRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return MonthlyPlanRepository(prefs);
});

class MonthlyPlanRepository {
  static const String _storageKey = 'timora_monthly_plans_data';

  final SharedPreferences _prefs;
  final List<MonthlyPlanModel> _plans = [];

  MonthlyPlanRepository(this._prefs) {
    _loadFromStorage();
  }

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
}

