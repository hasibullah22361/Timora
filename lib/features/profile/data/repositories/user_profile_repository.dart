import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class UserProfileRepository {
  static const String _defaultProfileKey = 'timora_user_profile_v1';
  final SharedPreferences _prefs;

  UserProfileRepository(this._prefs);

  String _getUserProfileKey(String? userId) {
    if (userId == null || userId.isEmpty || userId == 'user_default' || userId == 'usr_timora_1') {
      return _defaultProfileKey;
    }
    return 'timora_user_profile_${userId}_v1';
  }

  UserProfile loadProfile({
    String? userId,
    String? fallbackEmail,
    String? fallbackName,
  }) {
    final key = _getUserProfileKey(userId);
    final jsonStr = _prefs.getString(key);
    if (jsonStr != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        return UserProfile.fromJson(map);
      } catch (_) {}
    }

    if (userId == null || userId.isEmpty) {
      final defaultProfile = UserProfile.defaultProfile();
      saveProfile(defaultProfile);
      return defaultProfile;
    }

    final now = DateTime.now();
    final effectiveName = (fallbackName != null && fallbackName.trim().isNotEmpty)
        ? fallbackName.trim()
        : ((fallbackEmail != null && fallbackEmail.contains('@'))
            ? fallbackEmail.split('@').first
            : 'Timora User');
    final effectiveUsername = (fallbackEmail != null && fallbackEmail.contains('@'))
        ? fallbackEmail.split('@').first.toLowerCase()
        : 'user';
    final effectiveEmail = fallbackEmail ?? 'user@timora.app';

    final initialProfile = UserProfile(
      id: userId,
      fullName: effectiveName,
      username: effectiveUsername,
      email: effectiveEmail,
      bio: 'Optimizing time, building routines, and staying focused.',
      avatarPreset: '⚡',
      avatarColorValue: 0xFF2563EB,
      createdAt: now,
      updatedAt: now,
    );

    saveProfile(initialProfile, userId: userId);
    return initialProfile;
  }

  Future<void> saveProfile(UserProfile profile, {String? userId}) async {
    final key = _getUserProfileKey(userId ?? profile.id);
    final jsonStr = jsonEncode(profile.toJson());
    await _prefs.setString(key, jsonStr);
  }

  Future<void> clearProfile({String? userId}) async {
    final key = _getUserProfileKey(userId);
    await _prefs.remove(key);
  }
}
