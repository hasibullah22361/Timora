import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/models/settings_models.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  SettingsNotifier(this._repo) : super(_repo.loadSettings());

  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    await _repo.saveSettings(newSettings);
  }

  Future<void> resetSettings() async {
    final defaults = AppSettings();
    state = defaults;
    await _repo.saveSettings(defaults);
  }
}
