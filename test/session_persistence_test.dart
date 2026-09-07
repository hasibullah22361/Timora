import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:timora/features/auth/data/auth_repository.dart';
import 'package:timora/features/auth/presentation/providers/auth_provider.dart';

class TestFakeSession extends Fake implements supabase.Session {
  @override
  final String accessToken;
  @override
  final supabase.User user;
  @override
  final bool isExpired;
  @override
  final int? expiresAt;

  TestFakeSession({
    required this.accessToken,
    required this.user,
    this.isExpired = false,
    this.expiresAt,
  });
}

class TestFakeGoTrueClient extends Fake implements supabase.GoTrueClient {
  supabase.Session? _session;
  bool _networkError = false;

  void setActiveSession(supabase.Session? s) => _session = s;
  void setNetworkError(bool err) => _networkError = err;

  @override
  supabase.Session? get currentSession => _session;

  @override
  supabase.User? get currentUser => _session?.user;

  @override
  Stream<supabase.AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Future<supabase.AuthResponse> refreshSession([String? refreshToken]) async {
    if (_networkError) {
      throw const supabase.AuthException(
        'Failed host lookup: lgjzjzbbhmiejuovgtol.supabase.co',
        statusCode: '0',
      );
    }
    if (_session != null) {
      _session = supabase.Session(
        accessToken: 'token_refreshed_new',
        tokenType: 'bearer',
        user: _session!.user,
      );
      return supabase.AuthResponse(session: _session, user: _session!.user);
    }
    throw const supabase.AuthException('No active session to refresh', statusCode: '400');
  }

  @override
  Future<void> signOut({supabase.SignOutScope scope = supabase.SignOutScope.global}) async {
    _session = null;
  }
}

class TestClientWrapper extends Fake implements supabase.SupabaseClient {
  final TestFakeGoTrueClient _auth = TestFakeGoTrueClient();

  @override
  TestFakeGoTrueClient get auth => _auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestClientWrapper client;
  late AuthRepository repo;

  setUp(() {
    client = TestClientWrapper();
    repo = AuthRepository(supabaseClient: client);
  });

  group('Session Persistence Across App Reopen', () {
    final testUser = supabase.User(
      id: 'user_persistent_123',
      appMetadata: {},
      userMetadata: {'full_name': 'Persisted User'},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'persisted@example.com',
    );

    test('1. App Reopen: Active session persists and returns valid AuthSession', () async {
      client.auth.setActiveSession(supabase.Session(
        accessToken: 'valid_token_abc',
        tokenType: 'bearer',
        user: testUser,
      ));

      final restored = await repo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.isValid, isTrue);
      expect(restored.user.id, 'user_persistent_123');
      expect(restored.user.email, 'persisted@example.com');
    });

    test('2. App Reopen with Expired Token: Proactively refreshes token and keeps user logged in', () async {
      // Simulate expired token
      client.auth.setActiveSession(TestFakeSession(
        accessToken: 'expired_token_123',
        user: testUser,
        isExpired: true,
      ));

      final restored = await repo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.isValid, isTrue);
      expect(restored.token, 'token_refreshed_new');
      expect(restored.user.id, 'user_persistent_123');
    });

    test('3. App Reopen while Offline: Retains cached session and allows entry', () async {
      client.auth.setNetworkError(true);
      client.auth.setActiveSession(TestFakeSession(
        accessToken: 'cached_offline_token',
        user: testUser,
        isExpired: true,
      ));

      final restored = await repo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.isValid, isTrue);
      expect(restored.user.id, 'user_persistent_123');
    });

    test('4. Explicit Logout: Completely clears session so reopen requires login', () async {
      client.auth.setActiveSession(supabase.Session(
        accessToken: 'active_token',
        tokenType: 'bearer',
        user: testUser,
      ));
      expect(repo.getCurrentSession(), isNotNull);

      // Explicit logout
      await repo.logout();

      // App reopened
      final restored = await repo.restoreSession();
      expect(restored, isNull);
    });

    test('5. AuthController startup restoration populates authenticated state', () async {
      client.auth.setActiveSession(supabase.Session(
        accessToken: 'valid_token_controller',
        tokenType: 'bearer',
        user: testUser,
      ));

      final controller = AuthController(repo);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.user?.id, 'user_persistent_123');
      await Future.delayed(Duration.zero);
      controller.dispose();
    });
  });
}
