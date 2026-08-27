import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/weekly_plan_model.dart';

final weeklyPlanRepositoryProvider = Provider<WeeklyPlanRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return WeeklyPlanRepository(prefs, userId: currentUser?.id);
});

class WeeklyPlanRepository {
  static const String _defaultStorageKey = 'timora_weekly_plans_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<WeeklyPlanModel> _plans = [];

  WeeklyPlanRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _storageKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_weekly_plans_${_userId}_data'
      : _defaultStorageKey;

  void _loadFromStorage() {
    final jsonString = _prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _plans.clear();
        for (var item in decoded) {
          _plans.add(WeeklyPlanModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final jsonString = jsonEncode(_plans.map((p) => p.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }

  Future<WeeklyPlanModel?> getPlanForWeek(DateTime startOfWeek) async {
    try {
      return _plans.firstWhere((p) => 
        p.weekStartDate.year == startOfWeek.year && 
        p.weekStartDate.month == startOfWeek.month && 
        p.weekStartDate.day == startOfWeek.day
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlan(WeeklyPlanModel plan) async {
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      _plans[index] = plan;
    } else {
      _plans.add(plan);
    }
    await _saveToStorage();
  }
}

