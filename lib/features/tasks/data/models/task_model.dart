import 'package:flutter/material.dart';

enum TaskStatus { pending, inProgress, completed, cancelled }
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
  final bool reminderEnabled;
  final int reminderMinutesBefore;
  final String? scheduleActivityId;
  final String? projectId;
  final String? goalId;
  final String? milestoneId;
  final String notes;
  final bool isDeleted;
  final String recurrence;
  final int? estimatedDurationMinutes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  bool get isCompleted => status == TaskStatus.completed;

  TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.none,
    this.category = 'Other',
    this.dueDate,
    this.dueTime,
    this.reminderEnabled = false,
    this.reminderMinutesBefore = 10,
    this.scheduleActivityId,
    this.projectId,
    this.goalId,
    this.milestoneId,
    this.notes = '',
    this.isDeleted = false,
    this.recurrence = 'none',
    this.estimatedDurationMinutes,
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
    bool? reminderEnabled,
    int? reminderMinutesBefore,
    String? scheduleActivityId,
    String? projectId,
    String? goalId,
    String? milestoneId,
    String? notes,
    bool? isDeleted,
    String? recurrence,
    int? estimatedDurationMinutes,
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
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      scheduleActivityId: scheduleActivityId ?? this.scheduleActivityId,
      projectId: projectId ?? this.projectId,
      goalId: goalId ?? this.goalId,
      milestoneId: milestoneId ?? this.milestoneId,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      recurrence: recurrence ?? this.recurrence,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
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
      'reminderEnabled': reminderEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
      'scheduleActivityId': scheduleActivityId,
      'projectId': projectId,
      'goalId': goalId,
      'milestoneId': milestoneId,
      'notes': notes,
      'isDeleted': isDeleted,
      'recurrence': recurrence,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parsedDueTime;
    if (json['dueTime'] != null) {
      final parts = (json['dueTime'] as String).split(':');
      if (parts.length == 2) {
        parsedDueTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
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
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      dueTime: parsedDueTime,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderMinutesBefore: json['reminderMinutesBefore'] as int? ?? 15,
      scheduleActivityId: json['scheduleActivityId'] as String?,
      projectId: json['projectId'] as String?,
      goalId: json['goalId'] as String?,
      milestoneId: json['milestoneId'] as String?,
      notes: json['notes'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
      recurrence: json['recurrence'] as String? ?? 'none',
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int? ?? 30,
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

