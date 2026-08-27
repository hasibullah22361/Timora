import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/focus_session_model.dart';

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUser = ref.watch(currentUserProvider);
  return FocusRepository(prefs, userId: currentUser?.id);
});

class FocusRepository {
  static const String _defaultStorageKey = 'timora_focus_sessions_data';

  final SharedPreferences _prefs;
  final String? _userId;
  final List<FocusSessionModel> _sessions = [];

  FocusRepository(this._prefs, {String? userId}) : _userId = userId {
    _loadFromStorage();
  }

  String get _storageKey => (_userId != null && _userId!.isNotEmpty)
      ? 'timora_focus_sessions_${_userId}_data'
      : _defaultStorageKey;

  void _loadFromStorage() {
    final jsonString = _prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _sessions.clear();
        for (var item in decoded) {
          _sessions.add(FocusSessionModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage() async {
    final jsonString = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }

  Future<FocusSessionModel?> getActiveSession() async {
    try {
      return _sessions.firstWhere((s) =>
          s.status == FocusSessionStatus.running ||
          s.status == FocusSessionStatus.paused ||
          s.status == FocusSessionStatus.breakTime);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(FocusSessionModel session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.add(session);
    }
    await _saveToStorage();
  }
  
  Future<List<FocusSessionModel>> getSessionsForToday() async {
    final now = DateTime.now();
    return _sessions.where((s) => 
      s.startedAt.year == now.year && 
      s.startedAt.month == now.month && 
      s.startedAt.day == now.day &&
      s.status == FocusSessionStatus.completed
    ).toList();
  }
  
  Future<List<FocusSessionModel>> getAllCompletedSessions() async {
    return _sessions.where((s) => s.status == FocusSessionStatus.completed).toList();
  }
}

