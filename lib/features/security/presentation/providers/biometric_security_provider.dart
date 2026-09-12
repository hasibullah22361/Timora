import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/biometric_security_repository.dart';
import '../../services/biometric_auth_service.dart';

class BiometricSecurityState {
  final bool isEnabled;
  final bool isLocked;
  final BiometricAvailability availability;
  final bool isAuthenticating;
  final String? statusMessage;

  const BiometricSecurityState({
    required this.isEnabled,
    required this.isLocked,
    this.availability = BiometricAvailability.available,
    this.isAuthenticating = false,
    this.statusMessage,
  });

  BiometricSecurityState copyWith({
    bool? isEnabled,
    bool? isLocked,
    BiometricAvailability? availability,
    bool? isAuthenticating,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return BiometricSecurityState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      availability: availability ?? this.availability,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      statusMessage:
          clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }
}

final biometricSecurityProvider =
    StateNotifierProvider<BiometricSecurityNotifier, BiometricSecurityState>(
        (ref) {
  final repository = ref.watch(biometricSecurityRepositoryProvider);
  final authService = ref.watch(biometricAuthServiceProvider);
  return BiometricSecurityNotifier(repository, authService);
});

class BiometricSecurityNotifier extends StateNotifier<BiometricSecurityState> {
  final BiometricSecurityRepository _repository;
  final BiometricAuthService _authService;

  BiometricSecurityNotifier(this._repository, this._authService)
      : super(BiometricSecurityState(
          isEnabled: _repository.isBiometricLockEnabled(),
          isLocked: _repository.isBiometricLockEnabled() &&
              !_repository.isSessionUnlocked,
        )) {
    checkAvailability();
  }

  /// Checks whether biometric hardware exists and whether fingerprints are enrolled.
  Future<void> checkAvailability() async {
    final availability = await _authService.checkAvailability();
    state = state.copyWith(availability: availability);
  }

  /// Toggles ON: Must require successful biometric authentication before enabling.
  Future<bool> enableLock() async {
    await checkAvailability();
    if (state.availability == BiometricAvailability.noHardware) {
      state = state.copyWith(
          statusMessage:
              'This device does not support biometric authentication.');
      return false;
    }
    if (state.availability == BiometricAvailability.noneEnrolled) {
      state = state.copyWith(
          statusMessage:
              'No fingerprints enrolled. Please set up a fingerprint in device Settings first.');
      return false;
    }
    if (state.availability == BiometricAvailability.notSupported) {
      state = state.copyWith(
          statusMessage: 'Biometrics are not supported on this platform.');
      return false;
    }

    state = state.copyWith(isAuthenticating: true, clearStatusMessage: true);
    final success = await _authService.authenticate(
      reason: 'Scan your fingerprint to enable Fingerprint Lock',
    );
    state = state.copyWith(isAuthenticating: false);

    if (success) {
      await _repository.setBiometricLockEnabled(true);
      _repository.unlockSession();
      state = state.copyWith(
        isEnabled: true,
        isLocked: false,
        statusMessage: 'Fingerprint Lock enabled successfully.',
      );
      return true;
    } else {
      state = state.copyWith(
        statusMessage:
            'Authentication was cancelled or failed. Lock remains OFF.',
      );
      return false;
    }
  }

  /// Toggles OFF: Must require successful biometric authentication before disabling.
  Future<bool> disableLock() async {
    state = state.copyWith(isAuthenticating: true, clearStatusMessage: true);
    final success = await _authService.authenticate(
      reason: 'Scan your fingerprint to disable Fingerprint Lock',
    );
    state = state.copyWith(isAuthenticating: false);

    if (success) {
      await _repository.setBiometricLockEnabled(false);
      _repository.unlockSession();
      state = state.copyWith(
        isEnabled: false,
        isLocked: false,
        statusMessage: 'Fingerprint Lock disabled.',
      );
      return true;
    } else {
      state = state.copyWith(
        statusMessage:
            'Authentication required to disable Fingerprint Lock. Protection remains ON.',
      );
      return false;
    }
  }

  /// Prompts native authentication and unlocks Timora upon success.
  Future<bool> authenticateAndUnlock() async {
    if (!state.isEnabled) {
      state = state.copyWith(isLocked: false);
      return true;
    }

    if (state.isAuthenticating) return false;

    state = state.copyWith(isAuthenticating: true, clearStatusMessage: true);
    final success = await _authService.authenticate(
      reason: 'Scan your fingerprint to unlock Timora',
    );
    state = state.copyWith(isAuthenticating: false);

    if (success) {
      _repository.unlockSession();
      state = state.copyWith(
        isLocked: false,
        clearStatusMessage: true,
      );
      return true;
    } else {
      state = state.copyWith(
        isLocked: true,
        statusMessage:
            'Biometric not recognized or cancelled. Tap below to retry.',
      );
      return false;
    }
  }

  /// Locks Timora when entering background or manually invoked.
  void lockApp() {
    if (state.isEnabled) {
      _repository.lockSession();
      state = state.copyWith(isLocked: true, clearStatusMessage: true);
    }
  }

  void clearStatusMessage() {
    state = state.copyWith(clearStatusMessage: true);
  }
}
