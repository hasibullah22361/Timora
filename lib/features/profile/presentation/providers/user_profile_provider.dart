import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/user_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserProfileRepository(prefs);
});

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final repo = ref.watch(userProfileRepositoryProvider);
  return UserProfileNotifier(repo);
});

class UserProfileNotifier extends StateNotifier<UserProfile> {
  final UserProfileRepository _repo;

  UserProfileNotifier(this._repo) : super(_repo.loadProfile());

  Future<void> updateProfile(UserProfile updated) async {
    state = updated.copyWith(updatedAt: DateTime.now());
    await _repo.saveProfile(state);
  }

  Future<void> updateAvatar({required String avatarPreset, required int colorValue}) async {
    state = state.copyWith(
      avatarPreset: avatarPreset,
      avatarColorValue: colorValue,
      updatedAt: DateTime.now(),
    );
    await _repo.saveProfile(state);
  }

  Future<void> updateWorkHours({required int startMinutes, required int endMinutes}) async {
    state = state.copyWith(
      workHoursStartMinutes: startMinutes,
      workHoursEndMinutes: endMinutes,
      updatedAt: DateTime.now(),
    );
    await _repo.saveProfile(state);
  }

  Future<void> updateProductivityGoals({required double dailyGoalHours, required int dailyTaskGoal}) async {
    state = state.copyWith(
      dailyGoalHours: dailyGoalHours,
      dailyTaskGoal: dailyTaskGoal,
      updatedAt: DateTime.now(),
    );
    await _repo.saveProfile(state);
  }

  Future<void> resetToDefault() async {
    final def = UserProfile.defaultProfile();
    state = def;
    await _repo.saveProfile(def);
  }
}
