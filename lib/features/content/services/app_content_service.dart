import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../data/models/app_content_model.dart';

final appContentServiceProvider = Provider<AppContentService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppContentService(prefs);
});

final appContentProvider =
    StateNotifierProvider<AppContentNotifier, List<AppContentModel>>((ref) {
  final service = ref.watch(appContentServiceProvider);
  return AppContentNotifier(service);
});

class AppContentService {
  static const String _cacheKey = 'timora_app_content_cache';
  final SharedPreferences _prefs;

  AppContentService(this._prefs);

  List<AppContentModel> getCachedContent() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((item) => AppContentModel.fromSupabase(
              Map<String, dynamic>.from(item as Map)))
          .where((c) => _isContentCurrentlyActive(c))
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool _isContentCurrentlyActive(AppContentModel content) {
    if (!content.isActive) return false;
    final now = DateTime.now();
    if (content.startDate != null && content.startDate!.isAfter(now))
      return false;
    if (content.endDate != null && content.endDate!.isBefore(now)) return false;
    return true;
  }

  Future<List<AppContentModel>> fetchRemoteContent() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('app_content')
          .select('*')
          .eq('is_active', true)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(response as List);
      final List<AppContentModel> parsed = [];

      for (final row in rows) {
        final model = AppContentModel.fromSupabase(row);
        if (_isContentCurrentlyActive(model)) {
          parsed.add(model);
        }
      }

      await _prefs.setString(_cacheKey, jsonEncode(rows));
      return parsed;
    } catch (e) {
      debugPrint('[AppContent] Notice: $e');
      return getCachedContent();
    }
  }
}

class AppContentNotifier extends StateNotifier<List<AppContentModel>> {
  final AppContentService _service;
  RealtimeChannel? _realtimeChannel;

  AppContentNotifier(this._service) : super(_service.getCachedContent()) {
    _initAndListen();
  }

  Future<void> _initAndListen() async {
    // 1. Initial remote fetch
    try {
      final fresh = await _service.fetchRemoteContent();
      state = fresh;
    } catch (_) {}

    // 2. Realtime subscription on public.app_content
    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client.channel('public:timora_admin_app_content');
      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_content',
            callback: (payload) async {
              debugPrint(
                  '[AppContent] Realtime change on app_content, refreshing...');
              final fresh = await _service.fetchRemoteContent();
              state = fresh;
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[AppContent] Realtime subscription notice: $e');
    }
  }

  Future<void> refresh() async {
    final fresh = await _service.fetchRemoteContent();
    state = fresh;
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }
}
