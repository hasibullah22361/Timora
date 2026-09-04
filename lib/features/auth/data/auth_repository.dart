import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show AuthState;
import 'package:uuid/uuid.dart';

import 'models/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  final SupabaseClient? _customClient;
  final _uuid = const Uuid();

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  AuthRepository({SupabaseClient? supabaseClient})
      : _customClient = supabaseClient;

  SupabaseClient get _client {
    if (_customClient != null) return _customClient!;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw Exception(
        'Supabase client is not initialized. Please ensure Supabase is configured before using authentication.',
      );
    }
  }

  Stream<supabase.AuthState> get authStateChanges {
    try {
      return _client.auth.onAuthStateChange;
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Returns the current session without rejecting expired tokens.
  /// Supabase SDK automatically refreshes tokens, so we should not
  /// reject sessions that appear expired — the SDK handles renewal.
  AuthSession? getCurrentSession() {
    try {
      final session = _client.auth.currentSession;
      final user = _client.auth.currentUser;

      // Prefer currentUser which is always available if session was restored
      if (user == null) return null;

      // If session is null but user exists, session might still be refreshing
      // Return user info with a placeholder token — the SDK will refresh
      final effectiveSession = session;
      final displayName = (user.userMetadata?['full_name'] as String?)?.trim() ??
          (user.userMetadata?['name'] as String?)?.trim() ??
          (user.email?.split('@').first ?? 'User');

      final authUser = AuthUser(
        id: user.id,
        email: user.email ?? '',
        name: displayName.isNotEmpty ? displayName : 'User',
        isGuest: user.isAnonymous,
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );

      return AuthSession(
        token: effectiveSession?.accessToken ?? '',
        user: authUser,
        createdAt: DateTime.now(),
        expiresAt: effectiveSession?.expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(effectiveSession!.expiresAt! * 1000)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  AuthUser? getCurrentUser() {
    return getCurrentSession()?.user;
  }

  void _validateRegistrationInputs({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    if (name.trim().isEmpty) {
      throw Exception('Please enter your full name.');
    }
    if (email.trim().isEmpty) {
      throw Exception('Please enter your email address.');
    }
    if (!_emailRegExp.hasMatch(email.trim())) {
      throw Exception('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      throw Exception('Please enter a password.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    if (confirmPassword.isEmpty) {
      throw Exception('Please confirm your password.');
    }
    if (password != confirmPassword) {
      throw Exception('Passwords do not match.');
    }
  }

  void _validateLoginInputs({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty) {
      throw Exception('Please enter your email address.');
    }
    if (!_emailRegExp.hasMatch(email.trim())) {
      throw Exception('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      throw Exception('Please enter your password.');
    }
  }

  Future<AuthRegistrationResult> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    _validateRegistrationInputs(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );

    final normalizedEmail = email.trim().toLowerCase();
    final cleanName = name.trim();

    try {
      final res = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'full_name': cleanName},
        emailRedirectTo: 'io.supabase.timora://auth-callback',
      );

      final user = res.user;
      if (user == null) {
        throw Exception('Account creation failed. Please try again.');
      }

      final authUser = AuthUser(
        id: user.id,
        email: user.email ?? normalizedEmail,
        name: cleanName,
        isGuest: false,
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );

      final session = res.session;
      if (session != null) {
        // Auto-confirmed / immediate active session
        return AuthRegistrationResult(
          user: authUser,
          requiresEmailConfirmation: false,
          message: 'Account created successfully! Welcome to Timora.',
        );
      } else {
        // Email confirmation required by Supabase Auth configuration
        return AuthRegistrationResult(
          user: authUser,
          requiresEmailConfirmation: true,
          message: 'Your Timora account has been created. Please check your email ($normalizedEmail) to verify your account before signing in.',
        );
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid api key') ||
          msg.contains('apikey') ||
          msg.contains('jwt') ||
          msg.contains('api key')) {
        throw Exception('Authentication service configuration error (Invalid API key). Please ensure your Supabase API credentials are configured correctly.');
      }
      if (msg.contains('failed host lookup') ||
          msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('retryable') ||
          e.statusCode == '0') {
        throw Exception('Unable to connect to authentication service. Please check your internet connection and try again.');
      }
      if (msg.contains('already registered') ||
          msg.contains('already exists') ||
          e.statusCode == '422') {
        throw Exception('An account with this email already exists. Please sign in instead.');
      }
      if (msg.contains('password')) {
        throw Exception(e.message);
      }
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception &&
          !e.toString().toLowerCase().contains('socket') &&
          !e.toString().toLowerCase().contains('client') &&
          !e.toString().toLowerCase().contains('lookup') &&
          !e.toString().toLowerCase().contains('network') &&
          !e.toString().toLowerCase().contains('connection')) {
        rethrow;
      }
      throw Exception('Unable to connect to authentication service. Please check your internet connection and try again.');
    }
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    _validateLoginInputs(email: email, password: password);

    final normalizedEmail = email.trim().toLowerCase();

    try {
      final res = await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = res.user;
      final session = res.session;

      if (user == null || session == null) {
        throw Exception('Unable to authenticate. Please check your credentials.');
      }

      final displayName = (user.userMetadata?['full_name'] as String?)?.trim() ??
          (user.userMetadata?['name'] as String?)?.trim() ??
          normalizedEmail.split('@').first;

      final authUser = AuthUser(
        id: user.id,
        email: user.email ?? normalizedEmail,
        name: displayName.isNotEmpty ? displayName : normalizedEmail.split('@').first,
        isGuest: false,
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );

      return authUser;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid api key') ||
          msg.contains('apikey') ||
          msg.contains('jwt') ||
          msg.contains('api key')) {
        throw Exception('Authentication service configuration error (Invalid API key). Please ensure your Supabase API credentials are configured correctly.');
      }
      if (msg.contains('failed host lookup') ||
          msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('retryable') ||
          e.statusCode == '0') {
        throw Exception('Unable to connect to authentication service. Please check your internet connection and try again.');
      }
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials') ||
          msg.contains('invalid email or password') ||
          msg.contains('user not found')) {
        throw Exception('Incorrect email or password.');
      }
      if (msg.contains('email not confirmed')) {
        throw Exception('Please confirm your email address before signing in. Check your inbox for the confirmation link.');
      }
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception &&
          !e.toString().toLowerCase().contains('socket') &&
          !e.toString().toLowerCase().contains('client') &&
          !e.toString().toLowerCase().contains('lookup') &&
          !e.toString().toLowerCase().contains('network') &&
          !e.toString().toLowerCase().contains('connection')) {
        rethrow;
      }
      throw Exception('Unable to connect to authentication service. Please check your internet connection and try again.');
    }
  }

  Future<void> resetPassword(String email) async {
    if (email.trim().isEmpty) {
      throw Exception('Please enter your email address.');
    }
    if (!_emailRegExp.hasMatch(email.trim())) {
      throw Exception('Please enter a valid email address.');
    }

    final normalizedEmail = email.trim().toLowerCase();

    try {
      await _client.auth.resetPasswordForEmail(
        normalizedEmail,
        redirectTo: 'io.supabase.timora://auth-callback',
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid api key') ||
          msg.contains('apikey') ||
          msg.contains('jwt') ||
          msg.contains('api key')) {
        throw Exception('Authentication service configuration error (Invalid API key). Please ensure your Supabase API credentials are configured correctly.');
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to send password reset email. Please check your internet connection and try again.');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    if (newPassword.isEmpty) {
      throw Exception('Please enter a new password.');
    }
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid api key') ||
          msg.contains('apikey') ||
          msg.contains('jwt') ||
          msg.contains('api key')) {
        throw Exception('Authentication service configuration error (Invalid API key). Please ensure your Supabase API credentials are configured correctly.');
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to update password. Please check your internet connection and try again.');
    }
  }

  Future<AuthUser> loginAsGuest() async {
    try {
      final res = await _client.auth.signInAnonymously(
        data: {'full_name': 'Guest User'},
      );
      if (res.user != null) {
        return AuthUser(
          id: res.user!.id,
          email: res.user!.email ?? 'guest@timora.local',
          name: 'Guest User',
          isGuest: true,
          createdAt: DateTime.tryParse(res.user!.createdAt) ?? DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Anonymous auth notice: $e');
    }

    final now = DateTime.now();
    final guestId = 'guest_${_uuid.v4().substring(0, 8)}';
    return AuthUser(
      id: guestId,
      email: 'guest@timora.local',
      name: 'Guest User',
      isGuest: true,
      createdAt: now,
    );
  }

  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  /// Signs in with Google using native Google Sign-In + Supabase OAuth.
  Future<AuthUser> signInWithGoogle() async {
    try {
      // Native Google Sign-In flow
      const webClientId = String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue: '',
      );

      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId.isNotEmpty ? webClientId : null,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('Unable to retrieve Google credentials. Please try again.');
      }

      // Sign in to Supabase with Google token
      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = res.user;
      final session = res.session;

      if (user == null || session == null) {
        throw Exception('Unable to authenticate with Google. Please try again.');
      }

      final displayName = googleUser.displayName ??
          (user.userMetadata?['full_name'] as String?)?.trim() ??
          (user.userMetadata?['name'] as String?)?.trim() ??
          (user.email?.split('@').first ?? 'User');

      return AuthUser(
        id: user.id,
        email: user.email ?? googleUser.email,
        name: displayName.isNotEmpty ? displayName : 'User',
        isGuest: false,
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
        throw Exception('Unable to connect. Please check your internet connection and try again.');
      }
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Google sign-in failed. Please try again.');
    }
  }
}

