import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../models/routine_template.dart';

final routineTemplateRepositoryProvider =
    Provider<RoutineTemplateRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RoutineTemplateRepository(prefs);
});

final routineTemplatesProvider =
    StateNotifierProvider<RoutineTemplatesNotifier, List<RoutineTemplate>>(
        (ref) {
  final repo = ref.watch(routineTemplateRepositoryProvider);
  return RoutineTemplatesNotifier(repo);
});

class RoutineTemplateRepository {
  static const String _cacheKey = 'timora_cached_routine_templates';
  final SharedPreferences _prefs;

  RoutineTemplateRepository(this._prefs);

  List<RoutineTemplate> getCachedTemplates() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return RoutineTemplate.predefinedTemplates;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      final list = decoded
          .map((item) => RoutineTemplate.fromSupabase(
              Map<String, dynamic>.from(item as Map)))
          .toList();
      return list.isNotEmpty ? list : RoutineTemplate.predefinedTemplates;
    } catch (_) {
      return RoutineTemplate.predefinedTemplates;
    }
  }

  Future<List<RoutineTemplate>> fetchTemplatesFromSupabase() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('app_templates')
          .select(
              'id, title, description, template_type, category, icon, color, duration_minutes, default_days, is_active, sort_order, blocks')
          .inFilter('template_type', ['daily_routine', 'weekly_routine']).order(
              'sort_order',
              ascending: true);

      final rows = List<Map<String, dynamic>>.from(response as List);
      final List<RoutineTemplate> remoteTemplates = [];

      for (final row in rows) {
        final isActive = row['is_active'] as bool? ?? true;
        if (!isActive) continue;
        remoteTemplates.add(RoutineTemplate.fromSupabase(row));
      }

      // Cache the fetched templates
      if (remoteTemplates.isNotEmpty) {
        await _prefs.setString(_cacheKey, jsonEncode(rows));
        return remoteTemplates;
      }

      return getCachedTemplates();
    } catch (e) {
      debugPrint('[RoutineTemplateRepo] Notice: $e');
      return getCachedTemplates();
    }
  }
}

class RoutineTemplatesNotifier extends StateNotifier<List<RoutineTemplate>> {
  final RoutineTemplateRepository _repo;
  RealtimeChannel? _realtimeChannel;

  RoutineTemplatesNotifier(this._repo) : super(_repo.getCachedTemplates()) {
    _initAndListen();
  }

  Future<void> _initAndListen() async {
    // 1. Initial remote fetch
    try {
      final fresh = await _repo.fetchTemplatesFromSupabase();
      if (fresh.isNotEmpty) {
        state = fresh;
      }
    } catch (_) {}

    // 2. Supabase Realtime subscription
    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client.channel('public:timora_admin_templates');
      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_templates',
            callback: (payload) async {
              debugPrint(
                  '[RoutineTemplates] Realtime update on app_templates, refreshing...');
              final fresh = await _repo.fetchTemplatesFromSupabase();
              if (fresh.isNotEmpty) {
                state = fresh;
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[RoutineTemplates] Realtime subscription notice: $e');
    }
  }

  Future<void> refresh() async {
    final fresh = await _repo.fetchTemplatesFromSupabase();
    if (fresh.isNotEmpty) {
      state = fresh;
    }
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
