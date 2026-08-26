import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timora/features/streaks/data/models/streak_models.dart';
import 'package:timora/features/streaks/services/streak_service.dart';

final streakSettingsProvider = Provider<StreakSettingsModel>((ref) {
  final service = ref.watch(streakServiceProvider);
  return service.getSettings();
});

final streakProvider = FutureProvider.family<StreakModel, StreakType>((ref, type) async {
  final service = ref.watch(streakServiceProvider);
  return service.calculateStreak(type);
});
