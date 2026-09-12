import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/shared_prefs_provider.dart';

class RemoteAppConfig {
  final int defaultTaskDurationMinutes;
  final int defaultReminderOffsetMinutes;
  final bool maintenanceMode;
  final String minSupportedVersion;
  final int syncIntervalSeconds;
  final DateTime? lastUpdated;

  const RemoteAppConfig({
    this.defaultTaskDurationMinutes = 45,
    this.defaultReminderOffsetMinutes = 10,
    this.maintenanceMode = false,
    this.minSupportedVersion = '1.0.0',
    this.syncIntervalSeconds = 60,
    this.lastUpdated,
  });

  factory RemoteAppConfig.fromMap(Map<String, dynamic> map, {DateTime? updatedAt}) {
    return RemoteAppConfig(
      defaultTaskDurationMinutes: map['default_task_duration_minutes'] is int
          ? map['default_task_duration_minutes']
          : int.tryParse(map['default_task_duration_minutes']?.toString() ?? '') ?? 45,
      defaultReminderOffsetMinutes: map['default_reminder_offset_minutes'] is int
          ? map['default_reminder_offset_minutes']
          : int.tryParse(map['default_reminder_offset_minutes']?.toString() ?? '') ?? 10,
      maintenanceMode: map['maintenance_mode'] == true,
      minSupportedVersion: map['min_supported_version']?.toString() ?? '1.0.0',
      syncIntervalSeconds: map['sync_interval_seconds'] is int
          ? map['sync_interval_seconds']
          : int.tryParse(map['sync_interval_seconds']?.toString() ?? '') ?? 60,
      lastUpdated: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'default_task_duration_minutes': defaultTaskDurationMinutes,
      'default_reminder_offset_minutes': defaultReminderOffsetMinutes,
      'maintenance_mode': maintenanceMode,
      'min_supported_version': minSupportedVersion,
      'sync_interval_seconds': syncIntervalSeconds,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }
}

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = RemoteConfigService(prefs);
  ref.onDispose(() => service.dispose());
  return service;
});

final remoteConfigProvider =
    StateNotifierProvider<RemoteConfigNotifier, RemoteAppConfig>((ref) {
  final service = ref.watch(remoteConfigServiceProvider);
  return RemoteConfigNotifier(service);
});

class RemoteConfigNotifier extends StateNotifier<RemoteAppConfig> {
  final RemoteConfigService _service;
  VoidCallback? _listenerRemover;

  RemoteConfigNotifier(this._service) : super(_service.currentConfig) {
    _listenerRemover = _service.addListener((newConfig) {
      if (mounted) {
        state = newConfig;
      }
    });
  }

  Future<void> refresh() async {
    final fresh = await _service.fetchRemoteConfig();
    if (mounted) {
      state = fresh;
    }
  }

  @override
  void dispose() {
    _listenerRemover?.call();
    super.dispose();
  }
}

class RemoteConfigService {
  static const String _cacheKey = 'timora_remote_config_cache';
  static const String _settingsKey = 'general_app_config';
  final SharedPreferences _prefs;

  RemoteAppConfig _currentConfig = const RemoteAppConfig();
  final List<void Function(RemoteAppConfig)> _listeners = [];
  RealtimeChannel? _realtimeChannel;
  bool _isDisposed = false;

  RemoteConfigService(this._prefs) {
    _loadCachedConfig();
    _initRemoteAndRealtime();
  }

  RemoteAppConfig get currentConfig => _currentConfig;

  void Function() addListener(void Function(RemoteAppConfig) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final l in List.from(_listeners)) {
      try {
        l(_currentConfig);
      } catch (e) {
        debugPrint('[RemoteConfigService] Listener error: $e');
      }
    }
  }

  void _loadCachedConfig() {
    final raw = _prefs.getString(_cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _currentConfig = RemoteAppConfig.fromMap(decoded);
      } catch (e) {
        debugPrint('[RemoteConfigService] Cache parse error: $e');
        _currentConfig = const RemoteAppConfig();
      }
    }
  }

  Future<void> _initRemoteAndRealtime() async {
    // 1. Fetch latest from Supabase
    await fetchRemoteConfig();

    // 2. Setup Realtime subscription on app_system_settings
    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client.channel('public:timora_remote_app_settings');
      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_system_settings',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord['key'] == _settingsKey && newRecord['value'] is Map) {
                final valueMap = Map<String, dynamic>.from(newRecord['value'] as Map);
                final updatedAt = newRecord['updated_at'] != null
                    ? DateTime.tryParse(newRecord['updated_at'].toString())
                    : DateTime.now();

                _currentConfig = RemoteAppConfig.fromMap(valueMap, updatedAt: updatedAt);
                _prefs.setString(_cacheKey, jsonEncode(_currentConfig.toMap()));
                _notifyListeners();
                debugPrint('[RemoteConfigService] Live config updated via Realtime');
              } else {
                // If another settings key or update format, do a quick refresh
                fetchRemoteConfig();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[RemoteConfigService] Realtime subscription notice: $e');
    }
  }

  Future<RemoteAppConfig> fetchRemoteConfig() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('app_system_settings')
          .select('value, updated_at')
          .eq('key', _settingsKey)
          .maybeSingle();

      if (response != null && response['value'] is Map) {
        final valueMap = Map<String, dynamic>.from(response['value'] as Map);
        final updatedAt = response['updated_at'] != null
            ? DateTime.tryParse(response['updated_at'].toString())
            : null;

        _currentConfig = RemoteAppConfig.fromMap(valueMap, updatedAt: updatedAt);
        await _prefs.setString(_cacheKey, jsonEncode(_currentConfig.toMap()));
        _notifyListeners();
      }
      return _currentConfig;
    } catch (e) {
      debugPrint('[RemoteConfigService] Remote fetch notice: $e');
      return _currentConfig;
    }
  }

  void dispose() {
    _isDisposed = true;
    _listeners.clear();
    try {
      if (_realtimeChannel != null) {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
        _realtimeChannel = null;
      }
    } catch (_) {}
  }
}
