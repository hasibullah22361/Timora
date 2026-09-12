import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/features/clock/features/world_clock/data/models/world_clock_city_model.dart';
import 'package:timora/features/clock/features/world_clock/data/repositories/world_clock_repository.dart';

/// Emits the current DateTime every second to keep all clock displays synchronized and real-time.
final clockTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final worldClockIs24HourProvider =
    StateNotifierProvider<WorldClockIs24HourNotifier, bool>((ref) {
  final repo = ref.watch(worldClockRepositoryProvider);
  return WorldClockIs24HourNotifier(repo);
});

class WorldClockIs24HourNotifier extends StateNotifier<bool> {
  final WorldClockRepository _repo;

  WorldClockIs24HourNotifier(this._repo) : super(_repo.getIs24Hour());

  Future<void> toggle() async {
    final next = !state;
    state = next;
    await _repo.setIs24Hour(next);
  }
}

final worldClockCitiesProvider =
    StateNotifierProvider<WorldClockCitiesNotifier, List<WorldClockCityModel>>(
        (ref) {
  final repo = ref.watch(worldClockRepositoryProvider);
  return WorldClockCitiesNotifier(repo);
});

class WorldClockCitiesNotifier
    extends StateNotifier<List<WorldClockCityModel>> {
  final WorldClockRepository _repo;

  WorldClockCitiesNotifier(this._repo) : super([]) {
    loadCities();
  }

  void loadCities() {
    state = _repo.getSelectedCities();
  }

  Future<void> addCity(WorldClockCityModel city) async {
    await _repo.addCity(city);
    state = _repo.getSelectedCities();
  }

  Future<void> removeCity(String id) async {
    await _repo.removeCity(id);
    state = _repo.getSelectedCities();
  }

  Future<void> reorderCities(int oldIndex, int newIndex) async {
    await _repo.reorderCities(oldIndex, newIndex);
    state = _repo.getSelectedCities();
  }
}
