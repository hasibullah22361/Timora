import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../../cloud_sync/data/models/cloud_models.dart';
import '../../../cloud_sync/data/repositories/sync_repository.dart';
import '../../../cloud_sync/services/sync_service.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserProfileRepository(prefs);
});

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final repo = ref.watch(userProfileRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider);
  return UserProfileNotifier(repo, currentUser?.id, currentUser?.email, currentUser?.name, ref);
});

class UserProfileNotifier extends StateNotifier<UserProfile> {
  final UserProfileRepository _repo;
  final String? _userId;
  final Ref? _ref;

  UserProfileNotifier(this._repo, this._userId, String? email, String? name, [this._ref])
      : super(_repo.loadProfile(
          userId: _userId,
          fallbackEmail: email,
          fallbackName: name,
        )) {
    _hydrateFromCloud();
  }

  void _hydrateFromCloud() async {
    if (_userId != null &&
        _userId!.isNotEmpty &&
        !_userId!.startsWith('guest_') &&
        _userId != 'usr_timora_1' &&
        _userId != 'user_default') {
      final cloudProfile = await _repo.fetchProfileFromCloud(_userId!);
      if (cloudProfile != null) {
        state = cloudProfile;
      }
    }
  }

  void _onProfileSaved() {
    if (_ref != null) {
      _ref!.read(syncRepositoryProvider).enqueueChange(
        entityType: 'user_profile',
        entityId: state.id,
        operation: SyncOperation.update,
      );
      _ref!.read(syncServiceProvider).autoSync();
    }
  }

  Future<void> updateProfile(UserProfile updated) async {
    state = updated.copyWith(updatedAt: DateTime.now());
    await _repo.saveProfile(state, userId: _userId ?? state.id);
    _onProfileSaved();
  }

  Future<void> updateAvatar({required String avatarPreset, required int colorValue}) async {
    state = state.copyWith(
      avatarPreset: avatarPreset,
      avatarColorValue: colorValue,
      updatedAt: DateTime.now(),
    );
    await _repo.saveProfile(state, userId: _userId ?? state.id);
    _onProfileSaved();
  }

  Future<void> updateWorkHours({required int startMinutes, required int endMinutes}) async {
    state = state.copyWith(
      workHoursStartMinutes: startMinutes,
      workHoursEndMinutes: endMinutes,
      updatedAt: DateTime.now(),
    );
    await _repo.saveProfile(state, userId: _userId ?? state.id);
    _onProfileSaved();
  }

  Future<void> updateProductivityGoals({required double dailyGoalHours, required int dailyTaskGoal}) async {
    state = state.copyWith(
      dailyGoalHours: dailyGoalHours,
      dailyTaskGoal: dailyTaskGoal,
      updatedAt: DateTime.now(),
    );
    await _repo.saveProfile(state, userId: _userId ?? state.id);
    _onProfileSaved();
  }

  Future<void> resetToDefault() async {
    final def = UserProfile.defaultProfile();
    state = def;
    await _repo.saveProfile(def, userId: _userId ?? def.id);
    _onProfileSaved();
  }
}
