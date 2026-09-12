import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/shared_prefs_provider.dart';

final featureFlagsServiceProvider = Provider<FeatureFlagsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FeatureFlagsService(prefs);
});

final featureFlagsProvider =
    StateNotifierProvider<FeatureFlagsNotifier, FeatureFlagsState>((ref) {
  final service = ref.watch(featureFlagsServiceProvider);
  return FeatureFlagsNotifier(service);
});

class FeatureFlagsState {
  final Map<String, bool> flags;
  final bool isLoading;

  const FeatureFlagsState({
    required this.flags,
    this.isLoading = false,
  });

  bool isEnabled(String key, {bool defaultValue = true}) {
    return flags[key] ?? defaultValue;
  }

  bool get isSmartDailyPlannerEnabled => isEnabled('smart_daily_planner');
  bool get isMissedTaskRecoveryEnabled => isEnabled('missed_task_recovery');
  bool get isNaturalVoicePlanningEnabled => isEnabled('natural_voice_planning');
  bool get isAutopilotEnabled => isEnabled('timora_autopilot');
  bool get isAutomaticReportsEnabled => isEnabled('automatic_reports');
  bool get isProductivityHeatmapEnabled => isEnabled('productivity_heatmap');
  bool get isRoutineConsistencyEnabled => isEnabled('routine_consistency');
  bool get isSmartNotificationsEnabled => isEnabled('smart_notifications');
  bool get isCareerDocumentVaultEnabled => isEnabled('career_document_vault');
  bool get isCareerRoadmapEnabled => isEnabled('career_roadmap');
  bool get isAiAssistantEnabled => isEnabled('timora_ai_assistant');

  FeatureFlagsState copyWith({
    Map<String, bool>? flags,
    bool? isLoading,
  }) {
    return FeatureFlagsState(
      flags: flags ?? this.flags,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FeatureFlagsService {
  static const String _cacheKey = 'timora_feature_flags_cache';
  final SharedPreferences _prefs;

  static const Map<String, bool> defaultFlags = {
    'smart_daily_planner': true,
    'missed_task_recovery': true,
    'natural_voice_planning': true,
    'timora_autopilot': true,
    'automatic_reports': true,
    'productivity_heatmap': true,
    'routine_consistency': true,
    'smart_notifications': true,
    'career_document_vault': true,
    'career_roadmap': true,
    'timora_ai_assistant': true,
  };

  FeatureFlagsService(this._prefs);

  Map<String, bool> getCachedFlags() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return Map.from(defaultFlags);
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = Map<String, bool>.from(defaultFlags);
      decoded.forEach((key, val) {
        if (val is bool) map[key] = val;
      });
      return map;
    } catch (_) {
      return Map.from(defaultFlags);
    }
  }

  Future<Map<String, bool>> fetchRemoteFlags() async {
    try {
      final client = Supabase.instance.client;
      final response =
          await client.from('app_feature_flags').select('key, is_enabled');

      final rows = List<Map<String, dynamic>>.from(response as List);
      final map = Map<String, bool>.from(defaultFlags);

      for (final row in rows) {
        final key = row['key'] as String?;
        final isEnabled = row['is_enabled'] as bool?;
        if (key != null && isEnabled != null) {
          map[key] = isEnabled;
        }
      }

      await _prefs.setString(_cacheKey, jsonEncode(map));
      return map;
    } catch (e) {
      debugPrint('[FeatureFlags] Remote fetch notice: $e');
      return getCachedFlags();
    }
  }
}

class FeatureFlagsNotifier extends StateNotifier<FeatureFlagsState> {
  final FeatureFlagsService _service;
  RealtimeChannel? _realtimeChannel;

  FeatureFlagsNotifier(this._service)
      : super(FeatureFlagsState(flags: _service.getCachedFlags())) {
    _initAndListen();
  }

  Future<void> _initAndListen() async {
    // 1. Initial remote fetch
    try {
      final fresh = await _service.fetchRemoteFlags();
      state = state.copyWith(flags: fresh);
    } catch (_) {}

    // 2. Realtime subscription for instant feature switches
    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client.channel('public:timora_admin_feature_flags');
      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_feature_flags',
            callback: (payload) async {
              debugPrint(
                  '[FeatureFlags] Realtime change detected, updating flags...');
              final newRecord = payload.newRecord;
              if (newRecord['key'] != null && newRecord['is_enabled'] != null) {
                final key = newRecord['key'] as String;
                final isEnabled = newRecord['is_enabled'] as bool;
                final updatedMap = Map<String, bool>.from(state.flags);
                updatedMap[key] = isEnabled;
                state = state.copyWith(flags: updatedMap);
              }
              final fresh = await _service.fetchRemoteFlags();
              state = state.copyWith(flags: fresh);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[FeatureFlags] Realtime subscription notice: $e');
    }
  }

  Future<void> refresh() async {
    final fresh = await _service.fetchRemoteFlags();
    state = state.copyWith(flags: fresh);
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
