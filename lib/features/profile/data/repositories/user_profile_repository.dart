import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class UserProfileRepository {
  static const String _defaultProfileKey = 'timora_user_profile_v1';
  final SharedPreferences _prefs;
  final SupabaseClient? _customClient;

  UserProfileRepository(this._prefs, {SupabaseClient? supabaseClient})
      : _customClient = supabaseClient;

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String _getUserProfileKey(String? userId) {
    if (userId == null ||
        userId.isEmpty ||
        userId == 'user_default' ||
        userId == 'usr_timora_1') {
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

  Future<UserProfile?> fetchProfileFromCloud(String userId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        final local = loadProfile(userId: userId);
        final profile = UserProfile.fromSupabaseMap(
          res,
          localImagePath: local.customImagePath,
        );
        await saveProfile(profile, userId: userId);
        return profile;
      }
    } catch (e) {
      debugPrint('Cloud profile fetch notice: $e');
    }
    return null;
  }

  Future<void> saveProfile(UserProfile profile, {String? userId}) async {
    final key = _getUserProfileKey(userId ?? profile.id);
    final jsonStr = jsonEncode(profile.toJson());
    await _prefs.setString(key, jsonStr);

    // Sync to cloud if user is authenticated and not guest
    final currentUserId = userId ?? profile.id;
    if (currentUserId.isNotEmpty &&
        !currentUserId.startsWith('guest_') &&
        currentUserId != 'usr_timora_1' &&
        currentUserId != 'user_default') {
      final client = _client;
      if (client != null) {
        try {
          await client.from('profiles').upsert(profile.toSupabaseMap());
        } catch (e) {
          debugPrint('Cloud profile upsert notice: $e');
        }
      }
    }
  }

  Future<void> clearProfile({String? userId}) async {
    final key = _getUserProfileKey(userId);
    await _prefs.remove(key);
  }
}
