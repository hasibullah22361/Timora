import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../data/models/auth_models.dart';

class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final bool requiresEmailConfirmation;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.requiresEmailConfirmation = false,
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
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      requiresEmailConfirmation: requiresEmailConfirmation ?? this.requiresEmailConfirmation,
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isAuthenticated;
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AuthState()) {
    _initSession();
  }

  void _initSession() {
    final user = _repository.getCurrentUser();
    if (user != null) {
      state = AuthState(user: user);
    }
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
        successMessage: 'Password reset link sent if an account exists for that email.',
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
}
