import 'package:flutter/material.dart';

enum ActivityStatus { upcoming, current, completed, skipped, replaced }

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

  // Activity replacement fields
  final String? replacedByActivityId;
  final String? replacementActivityTitle;
  final String? replacesActivityId;
  final String? originalActivityTitle;

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
    this.replacedByActivityId,
    this.replacementActivityTitle,
    this.replacesActivityId,
    this.originalActivityTitle,
  });

  ScheduleActivity copyWith({
    String? id,
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
    String? replacedByActivityId,
    String? replacementActivityTitle,
    String? replacesActivityId,
    String? originalActivityTitle,
  }) {
    return ScheduleActivity(
      id: id ?? this.id,
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
      replacedByActivityId: replacedByActivityId ?? this.replacedByActivityId,
      replacementActivityTitle: replacementActivityTitle ?? this.replacementActivityTitle,
      replacesActivityId: replacesActivityId ?? this.replacesActivityId,
      originalActivityTitle: originalActivityTitle ?? this.originalActivityTitle,
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
      'replacedByActivityId': replacedByActivityId,
      'replacementActivityTitle': replacementActivityTitle,
      'replacesActivityId': replacesActivityId,
      'originalActivityTitle': originalActivityTitle,
    };
  }

  factory ScheduleActivity.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    final dateRaw = json['date'] ?? json['activity_date'];
    final parsedDate = dateRaw != null ? (DateTime.tryParse(dateRaw.toString()) ?? now) : now;

    final startRaw = json['startTime'] ?? json['start_time'];
    final parsedStart = startRaw != null ? (DateTime.tryParse(startRaw.toString()) ?? now) : now;

    final endRaw = json['endTime'] ?? json['end_time'];
    final parsedEnd = endRaw != null
        ? (DateTime.tryParse(endRaw.toString()) ?? parsedStart.add(const Duration(minutes: 30)))
        : parsedStart.add(const Duration(minutes: 30));

    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];
    final completedRaw = json['completedAt'] ?? json['completed_at'];

    return ScheduleActivity(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Activity',
      description: json['description'] as String? ?? '',
      date: parsedDate,
      startTime: parsedStart,
      endTime: parsedEnd,
      category: json['category'] as String? ?? 'Routine',
      icon: json['icon'] as String? ?? '📌',
      color: json['color'] != null ? Color((json['color'] as num).toInt()) : Colors.blue,
      status: ActivityStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ActivityStatus.upcoming,
      ),
      notes: json['notes'] as String? ?? '',
      reminderEnabled: (json['reminderEnabled'] ?? json['reminder_enabled']) as bool? ?? true,
      routineBlockId: (json['routineBlockId'] ?? json['routine_block_id']) as String?,
      isOverridden: (json['isOverridden'] ?? json['is_overridden']) as bool? ?? false,
      createdAt: createdRaw != null ? (DateTime.tryParse(createdRaw.toString()) ?? now) : now,
      updatedAt: updatedRaw != null ? DateTime.tryParse(updatedRaw.toString()) : null,
      completedAt: completedRaw != null ? DateTime.tryParse(completedRaw.toString()) : null,
      replacedByActivityId: (json['replacedByActivityId'] ?? json['replaced_by_activity_id']) as String?,
      replacementActivityTitle: (json['replacementActivityTitle'] ?? json['replacement_activity_title']) as String?,
      replacesActivityId: (json['replacesActivityId'] ?? json['replaces_activity_id']) as String?,
      originalActivityTitle: (json['originalActivityTitle'] ?? json['original_activity_title']) as String?,
    );
  }
}

