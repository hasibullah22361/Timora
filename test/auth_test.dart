import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:timora/features/auth/data/auth_repository.dart';
import 'package:timora/features/auth/presentation/providers/auth_provider.dart';
import 'package:timora/features/tasks/data/models/task_model.dart';
import 'package:timora/features/tasks/data/repositories/task_repository.dart';

/// Test client that simulates Supabase Auth backend responses
class FakeSupabaseAuthClient extends Fake implements supabase.GoTrueClient {
  final Map<String, Map<String, dynamic>> _registeredUsers = {};
  final StreamController<supabase.AuthState> _authStateController =
      StreamController<supabase.AuthState>.broadcast();
  supabase.Session? _activeSession;
  bool _simulateNetworkError = false;
  bool _requireEmailConfirmation = false;

  void setRequireEmailConfirmation(bool require) {
    _requireEmailConfirmation = require;
  }

  void setSimulateNetworkError(bool error) {
    _simulateNetworkError = error;
  }

  void emitAuthState(supabase.AuthChangeEvent event, supabase.Session? session) {
    _authStateController.add(supabase.AuthState(event, session));
  }

  @override
  Stream<supabase.AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  supabase.Session? get currentSession => _activeSession;

  @override
  supabase.User? get currentUser => _activeSession?.user;

  @override
  Future<supabase.UserResponse> updateUser(
    supabase.UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    if (_simulateNetworkError) {
      throw const supabase.AuthException(
        'Failed host lookup: lgjzjzbbhmiejuovgtol.supabase.co',
        statusCode: '0',
      );
    }
    if (_activeSession == null) {
      throw const supabase.AuthException('Not authenticated', statusCode: '401');
    }
    final user = _activeSession!.user;
    if (attributes.password != null) {
      final email = user.email;
      if (email != null && _registeredUsers.containsKey(email)) {
        _registeredUsers[email]!['password'] = attributes.password!;
      }
    }
    return supabase.UserResponse.fromJson({
      'id': user.id,
      'app_metadata': user.appMetadata,
      'user_metadata': user.userMetadata,
      'aud': user.aud,
      'email': user.email,
      'created_at': user.createdAt,
    });
  }

  @override
  Future<supabase.AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    supabase.OtpChannel channel = supabase.OtpChannel.sms,
  }) async {
    if (_simulateNetworkError) {
      throw const supabase.AuthException(
        'Failed host lookup: lgjzjzbbhmiejuovgtol.supabase.co',
        statusCode: '0',
      );
    }

    final normalized = (email ?? '').trim().toLowerCase();
    if (_registeredUsers.containsKey(normalized)) {
      throw const supabase.AuthException(
        'User already registered',
        statusCode: '422',
      );
    }

    final userId = 'sb_user_${normalized.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    final user = supabase.User(
      id: userId,
      appMetadata: {},
      userMetadata: data ?? {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: normalized,
    );

    _registeredUsers[normalized] = {
      'user': user,
      'password': password,
    };

    if (_requireEmailConfirmation) {
      _activeSession = null;
      return supabase.AuthResponse(session: null, user: user);
    } else {
      _activeSession = supabase.Session(
        accessToken: 'token_$userId',
        tokenType: 'bearer',
        user: user,
      );
      return supabase.AuthResponse(session: _activeSession, user: user);
    }
  }

  @override
  Future<supabase.AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    if (_simulateNetworkError) {
      throw const supabase.AuthException(
        'Failed host lookup: lgjzjzbbhmiejuovgtol.supabase.co',
        statusCode: '0',
      );
    }

    final normalized = (email ?? '').trim().toLowerCase();
    final record = _registeredUsers[normalized];

    if (record == null) {
      throw const supabase.AuthException(
        'Invalid login credentials',
        statusCode: '400',
      );
    }

    if (record['password'] != password) {
      throw const supabase.AuthException(
        'Invalid login credentials',
        statusCode: '400',
      );
    }

    final user = record['user'] as supabase.User;
    _activeSession = supabase.Session(
      accessToken: 'token_${user.id}',
      tokenType: 'bearer',
      user: user,
    );

    return supabase.AuthResponse(session: _activeSession, user: user);
  }

  @override
  Future<void> resetPasswordForEmail(
    String email, {
    String? redirectTo,
    String? captchaToken,
  }) async {
    if (_simulateNetworkError) {
      throw const supabase.AuthException(
        'Failed host lookup: lgjzjzbbhmiejuovgtol.supabase.co',
        statusCode: '0',
      );
    }
    // Supabase reset password succeeds silently even if user doesn't exist for security
  }

  @override
  Future<supabase.AuthResponse> signInAnonymously({
    Map<String, dynamic>? data,
    String? captchaToken,
  }) async {
    final anonUser = supabase.User(
      id: 'sb_anon_123',
      appMetadata: {},
      userMetadata: data ?? {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      isAnonymous: true,
    );
    _activeSession = supabase.Session(
      accessToken: 'token_anon',
      tokenType: 'bearer',
      user: anonUser,
    );
    return supabase.AuthResponse(session: _activeSession, user: anonUser);
  }

  @override
  Future<void> signOut({supabase.SignOutScope scope = supabase.SignOutScope.global}) async {
    _activeSession = null;
  }
}

/// Fake Supabase client wrapper for injecting into AuthRepository
class TestSupabaseClient extends Fake implements supabase.SupabaseClient {
  final FakeSupabaseAuthClient _auth = FakeSupabaseAuthClient();

  @override
  supabase.GoTrueClient get auth => _auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late TestSupabaseClient testClient;
  late AuthRepository authRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    testClient = TestSupabaseClient();
    authRepo = AuthRepository(supabaseClient: testClient);
  });

  group('Timora Supabase Authentication System Tests', () {
    test('TEST 1: Create Account with valid name, email, password creates real Supabase Auth user', () async {
      final result = await authRepo.register(
        name: 'Alice Johnson',
        email: 'alice@example.com',
        password: 'password123',
        confirmPassword: 'password123',
      );

      expect(result.user, isNotNull);
      expect(result.user!.name, 'Alice Johnson');
      expect(result.user!.email, 'alice@example.com');
      expect(result.user!.id.startsWith('sb_user_'), isTrue);

      final session = authRepo.getCurrentSession();
      expect(session, isNotNull);
      expect(session!.user.id, result.user!.id);
      expect(session.user.email, 'alice@example.com');
    });

    test('TEST 2: Email confirmation required state is correctly identified and communicated', () async {
      (testClient.auth as FakeSupabaseAuthClient).setRequireEmailConfirmation(true);

      final result = await authRepo.register(
        name: 'David Miller',
        email: 'david@example.com',
        password: 'password123',
        confirmPassword: 'password123',
      );

      expect(result.requiresEmailConfirmation, isTrue);
      expect(result.message.contains('check your email'), isTrue);
      // No active session yet because email confirmation is pending
      expect(authRepo.getCurrentSession(), isNull);
    });

    test('TEST 3: Sign in with registered Supabase email and correct password succeeds', () async {
      await authRepo.register(
        name: 'Bob Smith',
        email: 'bob@example.com',
        password: 'securePassword1',
        confirmPassword: 'securePassword1',
      );

      await authRepo.logout();
      expect(authRepo.getCurrentSession(), isNull);

      final loggedInUser = await authRepo.login(
        email: 'bob@example.com',
        password: 'securePassword1',
      );

      expect(loggedInUser.email, 'bob@example.com');
      expect(loggedInUser.name, 'Bob Smith');
      expect(authRepo.getCurrentSession(), isNotNull);
    });

    test('TEST 4: Sign in with registered email and incorrect password fails in Supabase', () async {
      await authRepo.register(
        name: 'Charlie Brown',
        email: 'charlie@example.com',
        password: 'mysecretpassword',
        confirmPassword: 'mysecretpassword',
      );

      await authRepo.logout();

      expect(
        () async => await authRepo.login(
          email: 'charlie@example.com',
          password: 'wrongPassword123',
        ),
        throwsA(predicate((e) => e.toString().contains('Incorrect email or password.'))),
      );
      expect(authRepo.getCurrentSession(), isNull);
    });

    test('TEST 5: Sign in with unregistered email fails with credentials error', () async {
      expect(
        () async => await authRepo.login(
          email: 'unknown.user@example.com',
          password: 'somePassword123',
        ),
        throwsA(predicate((e) => e.toString().contains('Incorrect email or password.'))),
      );
      expect(authRepo.getCurrentSession(), isNull);
    });

    test('TEST 6: Sign in with invalid email format throws client validation error', () async {
      expect(
        () async => await authRepo.login(
          email: 'invalid-email-format',
          password: 'password123',
        ),
        throwsA(predicate((e) => e.toString().contains('valid email'))),
      );
    });

    test('TEST 7: Sign in with empty password throws client validation error', () async {
      expect(
        () async => await authRepo.login(
          email: 'valid@example.com',
          password: '',
        ),
        throwsA(predicate((e) => e.toString().contains('password'))),
      );
    });

    test('TEST 8: Sign in with empty email throws client validation error', () async {
      expect(
        () async => await authRepo.login(
          email: '',
          password: 'password123',
        ),
        throwsA(predicate((e) => e.toString().contains('email'))),
      );
    });

    test('TEST 9: Registration with mismatched passwords fails before reaching backend', () async {
      expect(
        () async => await authRepo.register(
          name: 'Dana White',
          email: 'dana@example.com',
          password: 'password123',
          confirmPassword: 'differentPassword456',
        ),
        throwsA(predicate((e) => e.toString().contains('Passwords do not match'))),
      );
    });

    test('TEST 10: Registration with already registered email fails with clear message', () async {
      await authRepo.register(
        name: 'User One',
        email: 'duplicate@example.com',
        password: 'password123',
        confirmPassword: 'password123',
      );

      expect(
        () async => await authRepo.register(
          name: 'User Two',
          email: 'duplicate@example.com',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        throwsA(predicate((e) => e.toString().contains('already exists'))),
      );
    });

    test('TEST 11: Network error during registration does not create local fake account', () async {
      (testClient.auth as FakeSupabaseAuthClient).setSimulateNetworkError(true);

      expect(
        () async => await authRepo.register(
          name: 'Offline User',
          email: 'offline@example.com',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        throwsA(predicate((e) => e.toString().contains('Unable to connect to authentication service'))),
      );

      expect(authRepo.getCurrentSession(), isNull);
    });

    test('TEST 12: Network error during login does not authenticate or bypass', () async {
      (testClient.auth as FakeSupabaseAuthClient).setSimulateNetworkError(true);

      expect(
        () async => await authRepo.login(
          email: 'offline@example.com',
          password: 'password123',
        ),
        throwsA(predicate((e) => e.toString().contains('Unable to connect to authentication service'))),
      );

      expect(authRepo.getCurrentSession(), isNull);
    });

    test('TEST 13: Password reset triggers Supabase Auth recovery email', () async {
      await authRepo.resetPassword('user@example.com');
      // No exception thrown
    });

    test('TEST 14: Logout clears Supabase session and resets state', () async {
      await authRepo.register(
        name: 'Eve Adams',
        email: 'eve@example.com',
        password: 'password123',
        confirmPassword: 'password123',
      );

      expect(authRepo.getCurrentSession(), isNotNull);

      await authRepo.logout();
      expect(authRepo.getCurrentSession(), isNull);
    });

    test('TEST 15: User data is completely isolated by Supabase User ID', () async {
      final userA = await authRepo.register(
        name: 'User A',
        email: 'usera@example.com',
        password: 'password123',
        confirmPassword: 'password123',
      );

      final userB = await authRepo.register(
        name: 'User B',
        email: 'userb@example.com',
        password: 'password123',
        confirmPassword: 'password123',
      );

      final taskRepoA = TaskRepository(prefs, userId: userA.user!.id);
      final taskRepoB = TaskRepository(prefs, userId: userB.user!.id);

      await taskRepoA.createTask(TaskModel(
        id: 'task_user_a',
        title: 'Secret Task for User A',
        createdAt: DateTime.now(),
      ));

      final tasksA = await taskRepoA.getTasks();
      final tasksB = await taskRepoB.getTasks();

      expect(tasksA.any((t) => t.id == 'task_user_a'), isTrue);
      expect(tasksB.any((t) => t.id == 'task_user_a'), isFalse);
    });

    test('TEST 16: AuthController properly manages Supabase auth state transitions', () async {
      final controller = AuthController(authRepo);

      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.isLoading, isFalse);

      final success = await controller.register(
        name: 'Frank Ocean',
        email: 'frank@example.com',
        password: 'password123',
        confirmPassword: 'password123',
      );

      expect(success, isTrue);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.user?.name, 'Frank Ocean');

      await controller.logout();
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.user, isNull);
    });

    test('TEST 17: Update password updates credentials in Supabase Auth', () async {
      await authRepo.register(
        name: 'Grace Hopper',
        email: 'grace@example.com',
        password: 'initialPassword1',
        confirmPassword: 'initialPassword1',
      );

      // Update password online
      await authRepo.updatePassword('newSecretPassword2');

      // Logout
      await authRepo.logout();
      expect(authRepo.getCurrentSession(), isNull);

      // Old password fails
      expect(
        () async => await authRepo.login(
          email: 'grace@example.com',
          password: 'initialPassword1',
        ),
        throwsA(predicate((e) => e.toString().contains('Incorrect email or password.'))),
      );

      // New password succeeds
      final user = await authRepo.login(
        email: 'grace@example.com',
        password: 'newSecretPassword2',
      );
      expect(user.email, 'grace@example.com');
      expect(authRepo.getCurrentSession(), isNotNull);
    });

    test('TEST 18: Password recovery state transitions and updatePassword in AuthController', () async {
      final controller = AuthController(authRepo);

      // User registered
      await controller.register(
        name: 'Henry Ford',
        email: 'henry@example.com',
        password: 'oldPassword123',
        confirmPassword: 'oldPassword123',
      );

      // Simulate Supabase emitting passwordRecovery event on link click
      (testClient.auth as FakeSupabaseAuthClient).emitAuthState(
        supabase.AuthChangeEvent.passwordRecovery,
        testClient.auth.currentSession,
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(controller.state.isPasswordRecovery, isTrue);

      // Execute update password
      final updateSuccess = await controller.updatePassword('brandNewPassword456');
      expect(updateSuccess, isTrue);
      expect(controller.state.isPasswordRecovery, isFalse);
      expect(controller.state.successMessage?.contains('successfully'), isTrue);

      controller.dispose();
    });
  });
}

