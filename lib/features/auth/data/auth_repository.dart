import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  // Mock login for V1 offline-first approach. 
  // Prepared for future Firebase/Supabase integration.
  Future<void> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 2));
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
  }

  Future<void> register(String email, String password) async {
    await Future.delayed(const Duration(seconds: 2));
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
  }

  Future<void> resetPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    if (email.isEmpty) {
      throw Exception('Email cannot be empty');
    }
  }

  Future<void> loginAsGuest() async {
    // Guest mode works completely offline
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
