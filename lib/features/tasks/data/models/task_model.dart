import 'package:flutter/material.dart';

enum TaskStatus { pending, inProgress, completed, cancelled, overdue }
enum TaskPriority { none, low, medium, high, urgent }

class TaskModel {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final String category;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool reminderEnabled;
  final int reminderMinutesBefore;
  final String? scheduleActivityId;
  final String? projectId;
  final String? goalId;
  final String? milestoneId;
  final String? parentTaskId;
  final List<String> dependsOnTaskIds;
  final List<String> tags;
  final String notes;
  final bool isDeleted;
  final String recurrence;
  final int? estimatedDurationMinutes;
  final int actualDurationMinutes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  bool get isCompleted => status == TaskStatus.completed;

  bool get isOverdue {
    if (isCompleted || isDeleted || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    if (due.isBefore(today)) return true;
    if (due.isAtSameMomentAs(today) && dueTime != null) {
      final currentMinutes = now.hour * 60 + now.minute;
      final dueMinutes = dueTime!.hour * 60 + dueTime!.minute;
      return currentMinutes > dueMinutes;
    }
    return false;
  }

  TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.medium,
    this.category = 'Other',
    this.dueDate,
    this.dueTime,
    this.startTime,
    this.endTime,
    this.reminderEnabled = false,
    this.reminderMinutesBefore = 15,
    this.scheduleActivityId,
    this.projectId,
    this.goalId,
    this.milestoneId,
    this.parentTaskId,
    this.dependsOnTaskIds = const [],
    this.tags = const [],
    this.notes = '',
    this.isDeleted = false,
    this.recurrence = 'none',
    this.estimatedDurationMinutes = 30,
    this.actualDurationMinutes = 0,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  TaskModel copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    String? category,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? reminderEnabled,
    int? reminderMinutesBefore,
    String? scheduleActivityId,
    String? projectId,
    String? goalId,
    String? milestoneId,
    String? parentTaskId,
    List<String>? dependsOnTaskIds,
    List<String>? tags,
    String? notes,
    bool? isDeleted,
    String? recurrence,
    int? estimatedDurationMinutes,
    int? actualDurationMinutes,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      scheduleActivityId: scheduleActivityId ?? this.scheduleActivityId,
      projectId: projectId ?? this.projectId,
      goalId: goalId ?? this.goalId,
      milestoneId: milestoneId ?? this.milestoneId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      dependsOnTaskIds: dependsOnTaskIds ?? this.dependsOnTaskIds,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      recurrence: recurrence ?? this.recurrence,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
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
      'status': status.name,
      'priority': priority.name,
      'category': category,
      'dueDate': dueDate?.toIso8601String(),
      'dueTime': dueTime != null ? '${dueTime!.hour}:${dueTime!.minute}' : null,
      'startTime': startTime != null ? '${startTime!.hour}:${startTime!.minute}' : null,
      'endTime': endTime != null ? '${endTime!.hour}:${endTime!.minute}' : null,
      'reminderEnabled': reminderEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
      'scheduleActivityId': scheduleActivityId,
      'projectId': projectId,
      'goalId': goalId,
      'milestoneId': milestoneId,
      'parentTaskId': parentTaskId,
      'dependsOnTaskIds': dependsOnTaskIds,
      'tags': tags,
      'notes': notes,
      'isDeleted': isDeleted,
      'recurrence': recurrence,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'actualDurationMinutes': actualDurationMinutes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(dynamic val) {
      if (val is String && val.contains(':')) {
        final parts = val.split(':');
        if (parts.length == 2) {
          return TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      return null;
    }

    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: TaskStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      category: json['category'] as String? ?? 'Other',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : (json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String) : null),
      dueTime: parseTime(json['dueTime'] ?? json['due_time']),
      startTime: parseTime(json['startTime'] ?? json['start_time']),
      endTime: parseTime(json['endTime'] ?? json['end_time']),
      reminderEnabled: json['reminderEnabled'] as bool? ?? (json['reminder_enabled'] as bool? ?? false),
      reminderMinutesBefore: json['reminderMinutesBefore'] as int? ?? (json['reminder_minutes_before'] as int? ?? 15),
      scheduleActivityId: json['scheduleActivityId'] as String? ?? json['schedule_activity_id'] as String?,
      projectId: json['projectId'] as String? ?? json['project_id'] as String?,
      goalId: json['goalId'] as String? ?? json['goal_id'] as String?,
      milestoneId: json['milestoneId'] as String? ?? json['milestone_id'] as String?,
      parentTaskId: json['parentTaskId'] as String? ?? json['parent_task_id'] as String?,
      dependsOnTaskIds: (json['dependsOnTaskIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      notes: json['notes'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? (json['is_deleted'] as bool? ?? false),
      recurrence: json['recurrence'] as String? ?? 'none',
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int? ?? (json['estimated_duration_minutes'] as int? ?? 30),
      actualDurationMinutes: json['actualDurationMinutes'] as int? ?? (json['actual_duration_minutes'] as int? ?? 0),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
          : (json['created_at'] != null ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()) : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : (json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : (json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null),
    );
  }
}
