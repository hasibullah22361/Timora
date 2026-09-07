import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show AuthChangeEvent;
import '../../data/auth_repository.dart';
import '../../data/models/auth_models.dart';
import '../../../cloud_sync/services/sync_service.dart';
import '../../../profile/services/profile_image_service.dart';

class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final bool requiresEmailConfirmation;
  final bool isPasswordRecovery;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.requiresEmailConfirmation = false,
    this.isPasswordRecovery = false,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    bool? requiresEmailConfirmation,
    bool? isPasswordRecovery,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      requiresEmailConfirmation: requiresEmailConfirmation ?? this.requiresEmailConfirmation,
      isPasswordRecovery: isPasswordRecovery ?? this.isPasswordRecovery,
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository, ref);
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isAuthenticated;
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref? _ref;
  StreamSubscription? _authSubscription;
  bool _isSyncTriggered = false;

  AuthController(this._repository, [this._ref])
      : super(_repository.getCurrentUser() != null
            ? AuthState(user: _repository.getCurrentUser())
            : const AuthState()) {
    _initSession();
    _listenToAuthChanges();
  }

  Future<void> _initSession() async {
    try {
      final session = await _repository.restoreSession();
      if (!mounted) return;
      if (session != null) {
        state = AuthState(user: session.user, isLoading: false);
        debugPrint('[Auth] Session restored on startup for user: ${session.user.id}');
        Future.microtask(() => _triggerPostLoginSync(isFullRestore: true));
      } else {
        if (state.user == null) {
          state = const AuthState(user: null, isLoading: false);
        }
      }
    } catch (e) {
      debugPrint('[Auth] _initSession notice: $e');
      if (!mounted) return;
      if (state.user == null) {
        state = const AuthState(user: null, isLoading: false);
      }
    }
  }

  void _listenToAuthChanges() {
    _authSubscription = _repository.authStateChanges.listen((data) {
      if (!mounted) return;
      final event = data.event;
      if (event == supabase.AuthChangeEvent.passwordRecovery) {
        state = state.copyWith(isPasswordRecovery: true, clearError: true);
      } else if (event == supabase.AuthChangeEvent.signedOut) {
        state = const AuthState(user: null, isLoading: false);
        debugPrint('[Auth] User signed out');
        try {
          _ref?.read(syncServiceProvider).onUserSignedOut();
        } catch (_) {}
      } else if (event == supabase.AuthChangeEvent.signedIn) {
        final currentUser = _repository.getCurrentUser();
        if (currentUser != null) {
          state = state.copyWith(user: currentUser, isLoading: false);
          debugPrint('[Auth] Signed in as user: ${currentUser.id}');
          // Trigger full cloud restore on sign-in via microtask to avoid Riverpod reentrancy
          Future.microtask(() => _triggerPostLoginSync(isFullRestore: true));
        }
      } else if (event == supabase.AuthChangeEvent.initialSession) {
        final currentUser = _repository.getCurrentUser();
        if (currentUser != null) {
          state = state.copyWith(user: currentUser, isLoading: false);
          debugPrint('[Auth] Initial session for user: ${currentUser.id}');
          Future.microtask(() => _triggerPostLoginSync(isFullRestore: true));
        }
      } else if (event == supabase.AuthChangeEvent.tokenRefreshed) {
        // Token refresh: update user info without resetting state
        final currentUser = _repository.getCurrentUser();
        if (currentUser != null) {
          state = state.copyWith(user: currentUser, isLoading: false);
          debugPrint('[Auth] Token refreshed for user: ${currentUser.id}');
        }
      } else if (event == supabase.AuthChangeEvent.userUpdated) {
        final currentUser = _repository.getCurrentUser();
        if (currentUser != null) {
          state = state.copyWith(user: currentUser, isLoading: false);
        }
      }
    });
  }

  /// Triggers sync after login to restore user data from the cloud.
  void _triggerPostLoginSync({bool isFullRestore = true}) {
    if (_ref == null || _isSyncTriggered) return;
    _isSyncTriggered = true;

    Future.microtask(() async {
      try {
        final syncService = _ref!.read(syncServiceProvider);
        if (isFullRestore) {
          await syncService.fullRestore();
        } else {
          await syncService.syncNow();
        }
        debugPrint('[Auth] Cloud sync completed (isFullRestore: $isFullRestore)');
      } catch (e) {
        debugPrint('[Auth] Post-login sync notice: $e');
      } finally {
        _isSyncTriggered = false;
      }

      // Also download profile image from cloud
      try {
        final imgService = _ref!.read(profileImageServiceProvider);
        await imgService.downloadAndCacheProfileImage();
      } catch (e) {
        debugPrint('[Auth] Profile image download notice: $e');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String _cleanErrorMessage(Object error) {
    String msg = error.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring('Exception: '.length);
    }
    return msg;
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void clearSuccess() {
    if (state.successMessage != null) {
      state = state.copyWith(clearSuccess: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState(user: user, isLoading: false);
      _triggerPostLoginSync();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final result = await _repository.register(
        name: name,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );
      state = AuthState(
        user: result.requiresEmailConfirmation ? null : result.user,
        isLoading: false,
        successMessage: result.message,
        requiresEmailConfirmation: result.requiresEmailConfirmation,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _repository.resetPassword(email);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Password reset instructions have been sent to your email.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _repository.updatePassword(newPassword);
      state = state.copyWith(
        isLoading: false,
        isPasswordRecovery: false,
        successMessage: 'Password updated successfully! Please sign in with your new password.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> loginAsGuest() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final user = await _repository.loginAsGuest();
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.logout();
    } finally {
      state = const AuthState(user: null, isLoading: false);
    }
  }

  /// Signs in with Google OAuth. Phase 4.
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final user = await _repository.signInWithGoogle();
      state = AuthState(user: user, isLoading: false);
      _triggerPostLoginSync();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }
}

