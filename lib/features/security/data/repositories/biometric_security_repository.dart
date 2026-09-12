import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_prefs_provider.dart';

final biometricSecurityRepositoryProvider =
    Provider<BiometricSecurityRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BiometricSecurityRepository(prefs);
});

/// Repository governing persistent biometric app-lock preferences and
/// ephemeral in-memory session unlock state.
class BiometricSecurityRepository {
  static const String _keyBiometricLockEnabled = 'biometric_lock_enabled';

  final SharedPreferences _prefs;
  bool _isSessionUnlocked = false;

  BiometricSecurityRepository(this._prefs);

  /// Whether Fingerprint / Biometric App Lock is persistently enabled.
  bool isBiometricLockEnabled() {
    return _prefs.getBool(_keyBiometricLockEnabled) ?? false;
  }

  /// Persistently saves the biometric app-lock preference.
  Future<bool> setBiometricLockEnabled(bool enabled) async {
    return await _prefs.setBool(_keyBiometricLockEnabled, enabled);
  }

  /// Ephemeral session unlock state (reset on app exit or background timeout).
  bool get isSessionUnlocked => _isSessionUnlocked;

  void unlockSession() {
    _isSessionUnlocked = true;
  }

  void lockSession() {
    _isSessionUnlocked = false;
  }
}
