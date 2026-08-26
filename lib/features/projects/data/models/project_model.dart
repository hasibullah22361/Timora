import 'package:flutter/material.dart';

enum ProjectStatus { active, paused, completed, archived }
enum ProjectPriority { low, medium, high, urgent }

class ProjectModel {
  final String id;
  final String title;
  final String description;
  final ProjectStatus status;
  final ProjectPriority priority;
  final String category;
  final String icon;
  final Color color;
  final DateTime? startDate;
  final DateTime? targetDate;
  final String? goalId;
  final String? milestoneId;
  final String notes;
  final DateTime? completedAt;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProjectModel({
    required this.id,
    required this.title,
    this.description = '',
    this.status = ProjectStatus.active,
    this.priority = ProjectPriority.medium,
    this.category = 'Other',
    this.icon = '📁',
    this.color = Colors.blue,
    this.startDate,
    this.targetDate,
    this.goalId,
    this.milestoneId,
    this.notes = '',
    this.completedAt,
    this.isDeleted = false,
    required this.createdAt,
    this.updatedAt,
  });

  ProjectModel copyWith({
    String? title,
    String? description,
    ProjectStatus? status,
    ProjectPriority? priority,
    String? category,
    String? icon,
    Color? color,
    DateTime? startDate,
    DateTime? targetDate,
    String? goalId,
    String? milestoneId,
    String? notes,
    DateTime? completedAt,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      goalId: goalId ?? this.goalId,
      milestoneId: milestoneId ?? this.milestoneId,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'icon': icon,
      'color': color.toARGB32(),
      'startDate': startDate?.toIso8601String(),
      'targetDate': targetDate?.toIso8601String(),
      'goalId': goalId,
      'milestoneId': milestoneId,
      'notes': notes,
      'completedAt': completedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: ProjectStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ProjectStatus.active,
      ),
      priority: ProjectPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => ProjectPriority.medium,
      ),
      category: json['category'] as String? ?? 'Other',
      icon: json['icon'] as String? ?? '📁',
      color: json['color'] != null ? Color(json['color'] as int) : Colors.blue,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      targetDate: json['targetDate'] != null ? DateTime.parse(json['targetDate'] as String) : null,
      goalId: json['goalId'] as String?,
      milestoneId: json['milestoneId'] as String?,
      notes: json['notes'] as String? ?? '',
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

