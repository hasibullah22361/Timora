import 'package:flutter/material.dart';

class UserProfile {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String bio;
  final String avatarPreset; // e.g. '⚡', '🚀', or custom emoji
  final int avatarColorValue;
  final String? customImagePath; // Local file path to user's gallery photo
  final String timezone;
  final int workHoursStartMinutes; // minutes from midnight (e.g. 540 = 9:00 AM)
  final int workHoursEndMinutes; // minutes from midnight (e.g. 1080 = 6:00 PM)
  final double dailyGoalHours; // e.g. 6.0
  final int dailyTaskGoal; // e.g. 5
  final String routinePreference; // e.g. 'Time-blocking', 'Flexible Flow', 'Goal-driven'
  final bool notificationsEnabled;
  final ThemeMode themeMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.bio = 'Optimizing time, building routines, and staying focused.',
    this.avatarPreset = '⚡',
    this.avatarColorValue = 0xFF2563EB,
    this.customImagePath,
    this.timezone = 'UTC+05:00 - Islamabad, Karachi',
    this.workHoursStartMinutes = 540, // 9:00 AM
    this.workHoursEndMinutes = 1080, // 6:00 PM
    this.dailyGoalHours = 6.0,
    this.dailyTaskGoal = 5,
    this.routinePreference = 'Time-blocking',
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasCustomImage => customImagePath != null && customImagePath!.isNotEmpty;

  Color get avatarColor => Color(avatarColorValue);

  TimeOfDay get workHoursStart => TimeOfDay(
        hour: workHoursStartMinutes ~/ 60,
        minute: workHoursStartMinutes % 60,
      );

  TimeOfDay get workHoursEnd => TimeOfDay(
        hour: workHoursEndMinutes ~/ 60,
        minute: workHoursEndMinutes % 60,
      );

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? username,
    String? email,
    String? bio,
    String? avatarPreset,
    int? avatarColorValue,
    String? customImagePath,
    bool clearCustomImage = false,
    String? timezone,
    int? workHoursStartMinutes,
    int? workHoursEndMinutes,
    double? dailyGoalHours,
    int? dailyTaskGoal,
    String? routinePreference,
    bool? notificationsEnabled,
    ThemeMode? themeMode,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      avatarPreset: avatarPreset ?? this.avatarPreset,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      customImagePath: clearCustomImage ? null : (customImagePath ?? this.customImagePath),
      timezone: timezone ?? this.timezone,
      workHoursStartMinutes: workHoursStartMinutes ?? this.workHoursStartMinutes,
      workHoursEndMinutes: workHoursEndMinutes ?? this.workHoursEndMinutes,
      dailyGoalHours: dailyGoalHours ?? this.dailyGoalHours,
      dailyTaskGoal: dailyTaskGoal ?? this.dailyTaskGoal,
      routinePreference: routinePreference ?? this.routinePreference,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'username': username,
      'email': email,
      'bio': bio,
      'avatarPreset': avatarPreset,
      'avatarColorValue': avatarColorValue,
      'customImagePath': customImagePath,
      'timezone': timezone,
      'workHoursStartMinutes': workHoursStartMinutes,
      'workHoursEndMinutes': workHoursEndMinutes,
      'dailyGoalHours': dailyGoalHours,
      'dailyTaskGoal': dailyTaskGoal,
      'routinePreference': routinePreference,
      'notificationsEnabled': notificationsEnabled,
      'themeMode': themeMode.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'display_name': fullName,
      'username': username,
      'email': email,
      'bio': bio,
      'avatar_preset': avatarPreset,
      'avatar_color_value': avatarColorValue,
      'timezone': timezone,
      'work_hours_start_minutes': workHoursStartMinutes,
      'work_hours_end_minutes': workHoursEndMinutes,
      'daily_goal_hours': dailyGoalHours,
      'daily_task_goal': dailyTaskGoal,
      'routine_preference': routinePreference,
      'notifications_enabled': notificationsEnabled,
      'theme_mode': themeMode.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory UserProfile.fromSupabaseMap(Map<String, dynamic> map, {String? localImagePath}) {
    ThemeMode mode = ThemeMode.system;
    if (map['theme_mode'] != null) {
      try {
        mode = ThemeMode.values.firstWhere(
          (m) => m.name == map['theme_mode'],
          orElse: () => ThemeMode.system,
        );
      } catch (_) {}
    }

    return UserProfile(
      id: map['id'] as String? ?? 'user_default',
      fullName: (map['display_name'] as String?)?.isNotEmpty == true
          ? map['display_name'] as String
          : ((map['email'] as String?)?.split('@').first ?? 'Timora User'),
      username: map['username'] as String? ?? 'user',
      email: map['email'] as String? ?? 'user@timora.app',
      bio: map['bio'] as String? ?? 'Optimizing time, building routines, and staying focused.',
      avatarPreset: map['avatar_preset'] as String? ?? '⚡',
      avatarColorValue: map['avatar_color_value'] as int? ?? 0xFF2563EB,
      customImagePath: localImagePath,
      timezone: map['timezone'] as String? ?? 'UTC+05:00 - Islamabad, Karachi',
      workHoursStartMinutes: map['work_hours_start_minutes'] as int? ?? 540,
      workHoursEndMinutes: map['work_hours_end_minutes'] as int? ?? 1080,
      dailyGoalHours: (map['daily_goal_hours'] as num?)?.toDouble() ?? 6.0,
      dailyTaskGoal: map['daily_task_goal'] as int? ?? 5,
      routinePreference: map['routine_preference'] as String? ?? 'Time-blocking',
      notificationsEnabled: map['notifications_enabled'] as bool? ?? true,
      themeMode: mode,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    ThemeMode mode = ThemeMode.system;
    if (json['themeMode'] != null) {
      try {
        mode = ThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => ThemeMode.system,
        );
      } catch (_) {}
    }

    return UserProfile(
      id: json['id'] as String? ?? 'user_default',
      fullName: json['fullName'] as String? ?? 'Alex Johnson',
      username: json['username'] as String? ?? 'alexj',
      email: json['email'] as String? ?? 'alex@example.com',
      bio: json['bio'] as String? ?? 'Optimizing time, building routines, and staying focused.',
      avatarPreset: json['avatarPreset'] as String? ?? '⚡',
      avatarColorValue: json['avatarColorValue'] as int? ?? 0xFF2563EB,
      customImagePath: json['customImagePath'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC+05:00 - Islamabad, Karachi',
      workHoursStartMinutes: json['workHoursStartMinutes'] as int? ?? 540,
      workHoursEndMinutes: json['workHoursEndMinutes'] as int? ?? 1080,
      dailyGoalHours: (json['dailyGoalHours'] as num?)?.toDouble() ?? 6.0,
      dailyTaskGoal: json['dailyTaskGoal'] as int? ?? 5,
      routinePreference: json['routinePreference'] as String? ?? 'Time-blocking',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      themeMode: mode,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  factory UserProfile.defaultProfile() {
    final now = DateTime.now();
    return UserProfile(
      id: 'usr_timora_1',
      fullName: 'Hasib Ullah',
      username: 'hasib',
      email: 'hasib@timora.app',
      bio: 'Mastering routines, optimizing deep work, and achieving daily goals.',
      avatarPreset: '⚡',
      avatarColorValue: 0xFF2563EB,
      customImagePath: null,
      timezone: 'UTC+05:00 - Islamabad, Karachi',
      workHoursStartMinutes: 540, // 9:00 AM
      workHoursEndMinutes: 1080, // 6:00 PM
      dailyGoalHours: 6.0,
      dailyTaskGoal: 5,
      routinePreference: 'Time-blocking',
      notificationsEnabled: true,
      themeMode: ThemeMode.system,
      createdAt: now,
      updatedAt: now,
    );
  }
}

