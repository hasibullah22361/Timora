import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:timora/features/recap/domain/models/recap_models.dart';

final recapRepositoryProvider = Provider<RecapRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return RecapRepository(prefs, userId: currentUser?.id);
});

final allRecapsProvider = FutureProvider<List<TimoraRecapModel>>((ref) async {
  final repo = ref.watch(recapRepositoryProvider);
  return repo.getAllRecaps();
});

class RecapRepository {
  static const String _defaultStorageKey = 'timora_recaps_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<TimoraRecapModel> _recaps = [];

  RecapRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _storageKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_recaps_${_userId}_data'
      : _defaultStorageKey;

  void _loadFromStorage() {
    final raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        _recaps.clear();
        for (var item in decoded) {
          _recaps.add(TimoraRecapModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final raw = jsonEncode(_recaps.map((r) => r.toJson()).toList());
    await _prefs.setString(_storageKey, raw);
  }

  Future<List<TimoraRecapModel>> getAllRecaps() async {
    return List.unmodifiable(_recaps);
  }

  Future<List<TimoraRecapModel>> getRecapsByType(RecapType type) async {
    final list = _recaps.where((r) => r.type == type).toList()
      ..sort((a, b) => b.targetDate.compareTo(a.targetDate));
    return list;
  }

  Future<TimoraRecapModel?> getRecapById(String id) async {
    try {
      return _recaps.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<TimoraRecapModel?> getRecapForDate(
      RecapType type, DateTime date) async {
    final id = TimoraRecapModel.buildRecapId(type, date);
    return getRecapById(id);
  }

  Future<TimoraRecapModel?> getLatestRecap(RecapType type) async {
    final matching = _recaps.where((r) => r.type == type).toList()
      ..sort((a, b) => b.targetDate.compareTo(a.targetDate));
    return matching.isNotEmpty ? matching.first : null;
  }

  Future<void> saveRecap(TimoraRecapModel recap) async {
    final index = _recaps.indexWhere((r) => r.id == recap.id);
    final toSave = recap.copyWith(updatedAt: DateTime.now());

    if (index >= 0) {
      _recaps[index] = toSave;
    } else {
      _recaps.add(toSave);
    }

    await _saveToStorage();
  }

  Future<void> deleteRecap(String id) async {
    _recaps.removeWhere((r) => r.id == id);
    await _saveToStorage();
  }
}
