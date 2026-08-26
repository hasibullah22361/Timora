import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class UserProfileRepository {
  static const String _profileKey = 'timora_user_profile_v1';
  final SharedPreferences _prefs;

  UserProfileRepository(this._prefs);

  UserProfile loadProfile() {
    final jsonStr = _prefs.getString(_profileKey);
    if (jsonStr != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        return UserProfile.fromJson(map);
      } catch (_) {}
    }
    final defaultProfile = UserProfile.defaultProfile();
    saveProfile(defaultProfile);
    return defaultProfile;
  }

  Future<void> saveProfile(UserProfile profile) async {
    final jsonStr = jsonEncode(profile.toJson());
    await _prefs.setString(_profileKey, jsonStr);
  }

  Future<void> clearProfile() async {
    await _prefs.remove(_profileKey);
  }
}
