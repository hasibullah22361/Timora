import 'package:flutter/material.dart';

enum ActivityStatus { upcoming, current, completed, skipped }

class ScheduleActivity {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String category;
  final String icon;
  final Color color;
  final ActivityStatus status;
  final String notes;
  final bool reminderEnabled;
  final String? routineBlockId;
  final bool isOverridden;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  ScheduleActivity({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    required this.startTime,
    required this.endTime,
    this.category = 'Routine',
    this.icon = '📌',
    this.color = Colors.blue,
    this.status = ActivityStatus.upcoming,
    this.notes = '',
    this.reminderEnabled = true,
    this.routineBlockId,
    this.isOverridden = false,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  ScheduleActivity copyWith({
    String? title,
    String? description,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    String? category,
    String? icon,
    Color? color,
    ActivityStatus? status,
    String? notes,
    bool? reminderEnabled,
    String? routineBlockId,
    bool? isOverridden,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return ScheduleActivity(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      routineBlockId: routineBlockId ?? this.routineBlockId,
      isOverridden: isOverridden ?? this.isOverridden,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'category': category,
      'icon': icon,
      'color': color.toARGB32(),
      'status': status.name,
      'notes': notes,
      'reminderEnabled': reminderEnabled,
      'routineBlockId': routineBlockId,
      'isOverridden': isOverridden,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory ScheduleActivity.fromJson(Map<String, dynamic> json) {
    return ScheduleActivity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      category: json['category'] as String? ?? 'Routine',
      icon: json['icon'] as String? ?? '📌',
      color: json['color'] != null ? Color(json['color'] as int) : Colors.blue,
      status: ActivityStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ActivityStatus.upcoming,
      ),
      notes: json['notes'] as String? ?? '',
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      routineBlockId: json['routineBlockId'] as String?,
      isOverridden: json['isOverridden'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
}

