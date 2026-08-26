import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_models.dart';

class SettingsRepository {
  static const String _settingsKey = 'timora_app_settings';
  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  AppSettings loadSettings() {
    final jsonString = _prefs.getString(_settingsKey);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(jsonString);
        return AppSettings.fromJson(json);
      } catch (e) {
        return AppSettings();
      }
    }
    return AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final jsonString = jsonEncode(settings.toJson());
    await _prefs.setString(_settingsKey, jsonString);
  }

  Future<void> clearSettings() async {
    await _prefs.remove(_settingsKey);
  }
}
