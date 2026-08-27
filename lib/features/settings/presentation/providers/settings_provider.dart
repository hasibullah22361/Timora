import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/models/settings_models.dart';
import '../../../cloud_sync/data/models/cloud_models.dart';
import '../../../cloud_sync/data/repositories/sync_repository.dart';
import '../../../cloud_sync/services/sync_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo, ref);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;
  final Ref? _ref;

  SettingsNotifier(this._repo, [this._ref]) : super(_repo.loadSettings());

  void _onSettingsSaved() {
    if (_ref != null) {
      _ref!.read(syncRepositoryProvider).enqueueChange(
        entityType: 'settings',
        entityId: 'app_settings',
        operation: SyncOperation.update,
      );
      _ref!.read(syncServiceProvider).autoSync();
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    await _repo.saveSettings(newSettings);
    _onSettingsSaved();
  }

  Future<void> resetSettings() async {
    final defaults = AppSettings();
    state = defaults;
    await _repo.saveSettings(defaults);
    _onSettingsSaved();
  }
}
