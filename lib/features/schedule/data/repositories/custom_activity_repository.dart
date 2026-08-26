import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../activity_library.dart';
import '../models/activity_definition.dart';

final customActivityRepositoryProvider = Provider<CustomActivityRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CustomActivityRepository(prefs);
});

final allActivitiesProvider = StateNotifierProvider<AllActivitiesNotifier, List<ActivityDefinition>>((ref) {
  final repo = ref.watch(customActivityRepositoryProvider);
  return AllActivitiesNotifier(repo);
});

final recentActivitiesProvider = Provider<List<ActivityDefinition>>((ref) {
  final all = ref.watch(allActivitiesProvider);
  final repo = ref.watch(customActivityRepositoryProvider);
  final recentIds = repo.getRecentIds();
  return recentIds.map((id) => all.firstWhere((a) => a.id == id, orElse: () => all.first)).toList();
});

class CustomActivityRepository {
  static const String _customKey = 'timora_custom_activities_list';
  static const String _favoritesKey = 'timora_favorite_activity_ids';
  static const String _recentKey = 'timora_recent_activity_ids';

  final SharedPreferences _prefs;

  CustomActivityRepository(this._prefs);

  List<ActivityDefinition> getCustomActivities() {
    final jsonStr = _prefs.getString(_customKey);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => ActivityDefinition.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomActivities(List<ActivityDefinition> customList) async {
    final jsonStr = jsonEncode(customList.map((e) => e.toJson()).toList());
    await _prefs.setString(_customKey, jsonStr);
  }

  Set<String> getFavoriteIds() {
    final list = _prefs.getStringList(_favoritesKey) ?? [];
    return list.toSet();
  }

  Future<void> setFavorite(String id, bool isFav) async {
    final favs = getFavoriteIds();
    if (isFav) {
      favs.add(id);
    } else {
      favs.remove(id);
    }
    await _prefs.setStringList(_favoritesKey, favs.toList());
  }

  List<String> getRecentIds() {
    return _prefs.getStringList(_recentKey) ?? [];
  }

  Future<void> trackRecent(String id) async {
    final list = getRecentIds();
    list.remove(id);
    list.insert(0, id);
    if (list.length > 10) {
      list.removeRange(10, list.length);
    }
    await _prefs.setStringList(_recentKey, list);
  }
}

class AllActivitiesNotifier extends StateNotifier<List<ActivityDefinition>> {
  final CustomActivityRepository _repo;

  AllActivitiesNotifier(this._repo) : super([]) {
    _loadAll();
  }

  void _loadAll() {
    final customList = _repo.getCustomActivities();
    final favIds = _repo.getFavoriteIds();

    final all = [...ActivityLibrary.defaultActivities, ...customList];
    final updated = all.map((a) {
      return a.copyWith(isFavorite: favIds.contains(a.id));
    }).toList();

    state = updated;
  }

  Future<void> addCustomActivity(ActivityDefinition custom) async {
    final customList = _repo.getCustomActivities();
    customList.add(custom);
    await _repo.saveCustomActivities(customList);
    _loadAll();
  }

  Future<void> deleteCustomActivity(String id) async {
    final customList = _repo.getCustomActivities();
    customList.removeWhere((a) => a.id == id);
    await _repo.saveCustomActivities(customList);
    _loadAll();
  }

  Future<void> toggleFavorite(String id) async {
    final item = state.firstWhere((a) => a.id == id);
    final nextFav = !item.isFavorite;
    await _repo.setFavorite(id, nextFav);
    state = state.map((a) => a.id == id ? a.copyWith(isFavorite: nextFav) : a).toList();
  }

  Future<void> trackActivityUsed(String id) async {
    await _repo.trackRecent(id);
  }
}
