import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import '../models/world_clock_city_model.dart';
import '../sources/world_cities_database.dart';

final worldClockRepositoryProvider = Provider<WorldClockRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return WorldClockRepository(prefs);
});

class WorldClockRepository {
  static const String _keySelectedCities = 'timora_clock_world_cities';
  static const String _keyIs24Hour = 'timora_clock_is_24_hour';

  final SharedPreferences _prefs;

  WorldClockRepository(this._prefs);

  List<WorldClockCityModel> getSelectedCities() {
    try {
      final rawList = _prefs.getStringList(_keySelectedCities);
      if (rawList == null || rawList.isEmpty) {
        // Sensible initial defaults
        final defaults = [
          WorldCitiesDatabase.allCities.firstWhere(
            (c) => c.cityName == 'Islamabad',
            orElse: () => WorldCitiesDatabase.allCities.first,
          ),
          WorldCitiesDatabase.allCities.firstWhere(
            (c) => c.cityName == 'Dubai',
            orElse: () => WorldCitiesDatabase.allCities[1],
          ),
          WorldCitiesDatabase.allCities.firstWhere(
            (c) => c.cityName == 'London',
            orElse: () => WorldCitiesDatabase.allCities[2],
          ),
          WorldCitiesDatabase.allCities.firstWhere(
            (c) => c.cityName == 'New York',
            orElse: () => WorldCitiesDatabase.allCities[3],
          ),
        ];
        saveSelectedCities(defaults);
        return defaults;
      }

      return rawList.map((str) {
        return WorldClockCityModel.fromJson(
            jsonDecode(str) as Map<String, dynamic>);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSelectedCities(List<WorldClockCityModel> cities) async {
    final rawList = cities.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(_keySelectedCities, rawList);
  }

  Future<void> addCity(WorldClockCityModel city) async {
    final current = getSelectedCities();
    // Prevent exact duplicates
    if (!current.any((c) =>
        c.cityName == city.cityName && c.countryName == city.countryName)) {
      current.add(city);
      await saveSelectedCities(current);
    }
  }

  Future<void> removeCity(String cityId) async {
    final current = getSelectedCities();
    current.removeWhere((c) => c.id == cityId);
    await saveSelectedCities(current);
  }

  Future<void> reorderCities(int oldIndex, int newIndex) async {
    final current = getSelectedCities();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    await saveSelectedCities(current);
  }

  bool getIs24Hour() {
    return _prefs.getBool(_keyIs24Hour) ?? false;
  }

  Future<void> setIs24Hour(bool is24) async {
    await _prefs.setBool(_keyIs24Hour, is24);
  }
}
