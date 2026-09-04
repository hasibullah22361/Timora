import 'package:flutter/material.dart';

class HabitModel {
  final String id;
  final String title;
  final String description;
  final String icon;
  final Color color;
  final String frequency; // 'daily', 'weekly'
  final int targetDaysPerWeek;
  final TimeOfDay? reminderTime;
  final int currentStreak;
  final int bestStreak;
  final String? goalId;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? updatedAt;

  HabitModel({
    required this.id,
    required this.title,
    this.description = '',
    this.icon = '🔥',
    this.color = const Color(0xFF3B82F6),
    this.frequency = 'daily',
    this.targetDaysPerWeek = 7,
    this.reminderTime,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.goalId,
    this.isArchived = false,
    required this.createdAt,
    this.updatedAt,
  });

  HabitModel copyWith({
    String? title,
    String? description,
    String? icon,
    Color? color,
    String? frequency,
    int? targetDaysPerWeek,
    TimeOfDay? reminderTime,
    int? currentStreak,
    int? bestStreak,
    String? goalId,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return HabitModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      frequency: frequency ?? this.frequency,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      reminderTime: reminderTime ?? this.reminderTime,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      goalId: goalId ?? this.goalId,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'color': color.toARGB32(),
      'frequency': frequency,
      'targetDaysPerWeek': targetDaysPerWeek,
      'reminderTime': reminderTime != null ? '${reminderTime!.hour}:${reminderTime!.minute}' : null,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'goalId': goalId,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory HabitModel.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parsedTime;
    if (json['reminderTime'] != null) {
      final parts = (json['reminderTime'] as String).split(':');
      if (parts.length == 2) {
        parsedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    return HabitModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '🔥',
      color: json['color'] != null ? Color(json['color'] as int) : const Color(0xFF3B82F6),
      frequency: json['frequency'] as String? ?? 'daily',
      targetDaysPerWeek: json['targetDaysPerWeek'] as int? ?? 7,
      reminderTime: parsedTime,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      goalId: json['goalId'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
