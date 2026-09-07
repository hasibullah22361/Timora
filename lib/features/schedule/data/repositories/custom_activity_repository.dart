import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../activity_library.dart';
import '../models/activity_definition.dart';

final customActivityRepositoryProvider = Provider<CustomActivityRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return CustomActivityRepository(prefs, userId: currentUser?.id);
});

final allActivitiesProvider = StateNotifierProvider<AllActivitiesNotifier, List<ActivityDefinition>>((ref) {
  final repo = ref.watch(customActivityRepositoryProvider);
  return AllActivitiesNotifier(repo);
});

final recentActivitiesProvider = Provider<List<ActivityDefinition>>((ref) {
  final all = ref.watch(allActivitiesProvider);
  final repo = ref.watch(customActivityRepositoryProvider);
  final recentIds = repo.getRecentIds();
  if (all.isEmpty) return [];
  return recentIds
      .map((id) => all.where((a) => a.id == id).firstOrNull)
      .whereType<ActivityDefinition>()
      .toList();
});

class CustomActivityRepository {
  static const String _defaultCustomKey = 'timora_custom_activities_list';
  static const String _defaultFavoritesKey = 'timora_favorite_activity_ids';
  static const String _defaultRecentKey = 'timora_recent_activity_ids';

  final SharedPreferences _prefs;
  final String? _userId;

  CustomActivityRepository(this._prefs, {String? userId}) : _userId = userId;

  String get _customKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_custom_activities_${_userId}_list'
      : _defaultCustomKey;

  String get _favoritesKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_favorite_activity_${_userId}_ids'
      : _defaultFavoritesKey;

  String get _recentKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_recent_activity_${_userId}_ids'
      : _defaultRecentKey;

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
