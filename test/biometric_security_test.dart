import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/features/security/data/repositories/biometric_security_repository.dart';
import 'package:timora/features/security/presentation/providers/biometric_security_provider.dart';
import 'package:timora/features/security/presentation/screens/biometric_lock_screen.dart';
import 'package:timora/features/security/presentation/widgets/app_lock_lifecycle_wrapper.dart';
import 'package:timora/features/security/services/biometric_auth_service.dart';
import 'package:timora/features/settings/presentation/screens/security_settings_screen.dart';

class FakeBiometricAuthService implements BiometricAuthService {
  BiometricAvailability availability;
  bool shouldSucceedAuth;
  int authCalls = 0;
  String? lastReason;

  FakeBiometricAuthService({
    this.availability = BiometricAvailability.available,
    this.shouldSucceedAuth = true,
  });

  @override
  Future<BiometricAvailability> checkAvailability() async {
    return availability;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    authCalls++;
    lastReason = reason;
    return shouldSucceedAuth;
  }

  @override
  Future<void> cancelAuthentication() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricSecurityRepository Tests', () {
    test('Defaults to disabled when no preference is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);

      expect(repo.isBiometricLockEnabled(), isFalse);
      expect(repo.isSessionUnlocked, isFalse);
    });

    test('Loads enabled state when preference is set in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);

      expect(repo.isBiometricLockEnabled(), isTrue);
      expect(repo.isSessionUnlocked, isFalse);
    });

    test('Toggling lock state persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);

      await repo.setBiometricLockEnabled(true);
      expect(repo.isBiometricLockEnabled(), isTrue);
      expect(prefs.getBool('biometric_lock_enabled'), isTrue);

      await repo.setBiometricLockEnabled(false);
      expect(repo.isBiometricLockEnabled(), isFalse);
      expect(prefs.getBool('biometric_lock_enabled'), isFalse);
    });

    test('Session unlock state can be set and reset', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);

      expect(repo.isSessionUnlocked, isFalse);
      repo.unlockSession();
      expect(repo.isSessionUnlocked, isTrue);

      repo.lockSession();
      expect(repo.isSessionUnlocked, isFalse);
    });
  });

  group('BiometricSecurityNotifier State & Flow Tests', () {
    test('Enabling biometric lock requires successful authentication', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.available,
        shouldSucceedAuth: true,
      );

      final notifier = BiometricSecurityNotifier(repo, fakeAuth);
      await pumpEventQueue();

      final success = await notifier.enableLock();
      expect(success, isTrue);
      expect(notifier.state.isEnabled, isTrue);
      expect(notifier.state.isLocked, isFalse);
      expect(fakeAuth.authCalls, 1);
      expect(repo.isBiometricLockEnabled(), isTrue);
    });

    test('Enabling biometric lock fails if user cancels or authentication fails', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.available,
        shouldSucceedAuth: false,
      );

      final notifier = BiometricSecurityNotifier(repo, fakeAuth);
      await pumpEventQueue();

      final success = await notifier.enableLock();
      expect(success, isFalse);
      expect(notifier.state.isEnabled, isFalse);
      expect(notifier.state.statusMessage, isNotNull);
      expect(repo.isBiometricLockEnabled(), isFalse);
    });

    test('Disabling biometric lock requires successful authentication', () async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.available,
        shouldSucceedAuth: true,
      );

      final notifier = BiometricSecurityNotifier(repo, fakeAuth);
      await pumpEventQueue();
      expect(notifier.state.isEnabled, isTrue);

      final success = await notifier.disableLock();
      expect(success, isTrue);
      expect(notifier.state.isEnabled, isFalse);
      expect(repo.isBiometricLockEnabled(), isFalse);
    });

    test('Disabling biometric lock stays enabled if authentication fails or is cancelled', () async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.available,
        shouldSucceedAuth: false,
      );

      final notifier = BiometricSecurityNotifier(repo, fakeAuth);
      await pumpEventQueue();
      expect(notifier.state.isEnabled, isTrue);

      final success = await notifier.disableLock();
      expect(success, isFalse);
      expect(notifier.state.isEnabled, isTrue);
      expect(repo.isBiometricLockEnabled(), isTrue);
    });

    test('authenticateAndUnlock unlocks session on success', () async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.available,
        shouldSucceedAuth: true,
      );

      final notifier = BiometricSecurityNotifier(repo, fakeAuth);
      await pumpEventQueue();
      expect(notifier.state.isLocked, isTrue);

      final unlocked = await notifier.authenticateAndUnlock();
      expect(unlocked, isTrue);
      expect(notifier.state.isLocked, isFalse);
      expect(repo.isSessionUnlocked, isTrue);
    });

    test('authenticateAndUnlock keeps app locked on failure or cancel', () async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.available,
        shouldSucceedAuth: false,
      );

      final notifier = BiometricSecurityNotifier(repo, fakeAuth);
      await pumpEventQueue();

      final unlocked = await notifier.authenticateAndUnlock();
      expect(unlocked, isFalse);
      expect(notifier.state.isLocked, isTrue);
      expect(repo.isSessionUnlocked, isFalse);
    });

    test('lockApp explicitly locks session', () async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      repo.unlockSession();
      final fakeAuth = FakeBiometricAuthService();

      final notifier = BiometricSecurityNotifier(repo, fakeAuth);
      await pumpEventQueue();

      notifier.lockApp();
      expect(notifier.state.isLocked, isTrue);
      expect(repo.isSessionUnlocked, isFalse);
    });

    test('Hardware without biometrics reports noHardware availability', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.noHardware,
      );

      final notifier = BiometricSecurityNotifier(repo, fakeAuth);
      await pumpEventQueue();

      expect(notifier.state.availability, BiometricAvailability.noHardware);
      final success = await notifier.enableLock();
      expect(success, isFalse);
      expect(notifier.state.statusMessage, contains('does not support biometric authentication'));
    });

    test('Hardware without enrolled biometrics reports noneEnrolled availability', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.noneEnrolled,
      );

      final notifier = BiometricSecurityNotifier(repo, fakeAuth);
      await pumpEventQueue();

      expect(notifier.state.availability, BiometricAvailability.noneEnrolled);
      final success = await notifier.enableLock();
      expect(success, isFalse);
      expect(notifier.state.statusMessage, contains('No fingerprints enrolled'));
    });
  });

  group('Biometric UI & Widget Tests', () {
    testWidgets('BiometricLockScreen renders correctly in Dark Mode', (tester) async {
      final fakeAuth = FakeBiometricAuthService(shouldSucceedAuth: false);
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricSecurityRepositoryProvider.overrideWithValue(repo),
            biometricAuthServiceProvider.overrideWithValue(fakeAuth),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const BiometricLockScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Timora is Locked'), findsOneWidget);
      expect(find.text('Unlock with Biometrics'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsWidgets);
    });

    testWidgets('BiometricLockScreen renders correctly in Light Mode', (tester) async {
      final fakeAuth = FakeBiometricAuthService(shouldSucceedAuth: false);
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricSecurityRepositoryProvider.overrideWithValue(repo),
            biometricAuthServiceProvider.overrideWithValue(fakeAuth),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const BiometricLockScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Timora is Locked'), findsOneWidget);
      expect(find.text('Unlock with Biometrics'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsWidgets);
    });

    testWidgets('Tapping Unlock with Biometrics triggers authentication', (tester) async {
      final fakeAuth = FakeBiometricAuthService(shouldSucceedAuth: false);
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricSecurityRepositoryProvider.overrideWithValue(repo),
            biometricAuthServiceProvider.overrideWithValue(fakeAuth),
          ],
          child: const MaterialApp(
            home: BiometricLockScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final unlockButton = find.text('Unlock with Biometrics');
      expect(unlockButton, findsOneWidget);

      await tester.tap(unlockButton);
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAuth.authCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('AppLockLifecycleWrapper shields child when locked and reveals child when unlocked', (tester) async {
      final fakeAuth = FakeBiometricAuthService(shouldSucceedAuth: false);
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricSecurityRepositoryProvider.overrideWithValue(repo),
            biometricAuthServiceProvider.overrideWithValue(fakeAuth),
          ],
          child: const MaterialApp(
            home: AppLockLifecycleWrapper(
              child: Scaffold(
                body: Text('Protected Timora Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Protected content is obscured by lock screen
      expect(find.text('Timora is Locked'), findsOneWidget);
      expect(find.text('Protected Timora Content'), findsNothing);

      // Now set auth to succeed and tap unlock
      fakeAuth.shouldSucceedAuth = true;
      await tester.tap(find.text('Unlock with Biometrics'));
      await tester.pump(const Duration(milliseconds: 100));

      // Content is now revealed
      expect(find.text('Protected Timora Content'), findsOneWidget);
      expect(find.text('Timora is Locked'), findsNothing);
    });

    testWidgets('SecuritySettingsScreen displays Fingerprint Lock and status', (tester) async {
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.available,
        shouldSucceedAuth: true,
      );
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricSecurityRepositoryProvider.overrideWithValue(repo),
            biometricAuthServiceProvider.overrideWithValue(fakeAuth),
          ],
          child: const MaterialApp(
            home: SecuritySettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Security & App Lock'), findsOneWidget);
      expect(find.text('Fingerprint Lock'), findsOneWidget);
      expect(find.text('Fingerprint Sensor Ready'), findsOneWidget);
      expect(find.text('Device biometric hardware is supported and enrolled.'), findsOneWidget);
      expect(find.text('Secure Native Biometrics'), findsOneWidget);
    });

    testWidgets('Toggling switch OFF requires authentication and reverts if auth fails', (tester) async {
      final fakeAuth = FakeBiometricAuthService(
        availability: BiometricAvailability.available,
        shouldSucceedAuth: false, // Auth fails when user attempts to turn off
      );
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final repo = BiometricSecurityRepository(prefs);
      repo.unlockSession();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricSecurityRepositoryProvider.overrideWithValue(repo),
            biometricAuthServiceProvider.overrideWithValue(fakeAuth),
          ],
          child: const MaterialApp(
            home: SecuritySettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch should be currently true (ON)
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);

      // Tap switch to turn OFF
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Since auth failed, switch must remain ON
      final switchAfter = tester.widget<Switch>(switchFinder);
      expect(switchAfter.value, isTrue);
      expect(repo.isBiometricLockEnabled(), isTrue);
    });
  });
}
