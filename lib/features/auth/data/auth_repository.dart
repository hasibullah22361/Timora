import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
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
    return Supabase.instance.client;
  }

  AuthSession? getCurrentSession() {
    try {
      final session = _client.auth.currentSession;
      if (session == null || session.isExpired) {
        return null;
      }
      final user = _client.auth.currentUser ?? session.user;
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
        token: session.accessToken,
        user: authUser,
        createdAt: DateTime.now(),
        expiresAt: session.expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
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
          message: 'Account created! Please check your email ($normalizedEmail) to confirm your account before signing in.',
        );
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
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
      await _client.auth.resetPasswordForEmail(normalizedEmail);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to send password reset email. Please check your internet connection and try again.');
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
}
