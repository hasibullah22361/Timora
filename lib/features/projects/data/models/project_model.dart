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
    final startRaw = json['startDate'] ?? json['start_date'];
    final targetRaw = json['targetDate'] ?? json['target_date'];
    final completedRaw = json['completedAt'] ?? json['completed_at'];
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];

    return ProjectModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Project',
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
      color: json['color'] != null ? Color((json['color'] as num).toInt()) : Colors.blue,
      startDate: startRaw != null ? DateTime.tryParse(startRaw.toString()) : null,
      targetDate: targetRaw != null ? DateTime.tryParse(targetRaw.toString()) : null,
      goalId: (json['goalId'] ?? json['goal_id']) as String?,
      milestoneId: (json['milestoneId'] ?? json['milestone_id']) as String?,
      notes: json['notes'] as String? ?? '',
      completedAt: completedRaw != null ? DateTime.tryParse(completedRaw.toString()) : null,
      isDeleted: (json['isDeleted'] ?? json['is_deleted']) as bool? ?? false,
      createdAt: createdRaw != null
          ? (DateTime.tryParse(createdRaw.toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: updatedRaw != null
          ? DateTime.tryParse(updatedRaw.toString())
          : null,
    );
  }
}

