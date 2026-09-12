import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricAvailability {
  available,
  noHardware,
  noneEnrolled,
  notSupported,
}

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService(LocalAuthentication());
});

/// Service interfacing with native Android biometric authentication system (BiometricPrompt)
/// via local_auth. Never accesses or stores any biometric data or credentials.
class BiometricAuthService {
  final LocalAuthentication _localAuth;

  BiometricAuthService(this._localAuth);

  /// Checks device biometric hardware capabilities and enrollment state.
  Future<BiometricAvailability> checkAvailability() async {
    if (kIsWeb) return BiometricAvailability.notSupported;

    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return BiometricAvailability.notSupported;
      }

      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        return BiometricAvailability.noHardware;
      }

      final enrolled = await _localAuth.getAvailableBiometrics();
      if (enrolled.isEmpty) {
        return BiometricAvailability.noneEnrolled;
      }

      return BiometricAvailability.available;
    } on PlatformException catch (e) {
      debugPrint('[BiometricAuthService] Error checking availability: $e');
      return BiometricAvailability.noHardware;
    } catch (e) {
      debugPrint('[BiometricAuthService] Unexpected error: $e');
      return BiometricAvailability.notSupported;
    }
  }

  /// Prompts Android native biometric authentication dialog.
  /// Returns `true` on successful biometric match, `false` on cancel/failure.
  /// Never crashes or closes the app.
  Future<bool> authenticate({required String reason}) async {
    if (kIsWeb) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
      debugPrint('[BiometricAuthService] Authentication result: $authenticated');
      return authenticated;
    } on LocalAuthException catch (e) {
      debugPrint('[BiometricAuthService] LocalAuthException during auth (${e.code}): ${e.description}');
      return false;
    } on PlatformException catch (e) {
      debugPrint('[BiometricAuthService] PlatformException during auth (${e.code}): ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[BiometricAuthService] Unexpected error during auth: $e');
      return false;
    }
  }

  /// Cancels any active authentication session.
  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (_) {}
  }
}
