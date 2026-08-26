import 'package:flutter/material.dart';

enum GoalStatus { active, paused, completed, archived }
enum GoalPriority { low, medium, high }
enum ProgressMode { auto, manual }

class GoalModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final GoalStatus status;
  final GoalPriority priority;
  final String icon;
  final Color color;
  final DateTime? startDate;
  final DateTime? targetDate;
  final ProgressMode progressMode;
  final double manualProgress;
  final DateTime? completedAt;
  final String notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  GoalModel({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'Other',
    this.status = GoalStatus.active,
    this.priority = GoalPriority.medium,
    this.icon = '🎯',
    this.color = Colors.blue,
    this.startDate,
    this.targetDate,
    this.progressMode = ProgressMode.auto,
    this.manualProgress = 0.0,
    this.completedAt,
    this.notes = '',
    this.isDeleted = false,
    required this.createdAt,
    this.updatedAt,
  });

  GoalModel copyWith({
    String? title,
    String? description,
    String? category,
    GoalStatus? status,
    GoalPriority? priority,
    String? icon,
    Color? color,
    DateTime? startDate,
    DateTime? targetDate,
    ProgressMode? progressMode,
    double? manualProgress,
    DateTime? completedAt,
    String? notes,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return GoalModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      progressMode: progressMode ?? this.progressMode,
      manualProgress: manualProgress ?? this.manualProgress,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
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
      'category': category,
      'status': status.name,
      'priority': priority.name,
      'icon': icon,
      'color': color.toARGB32(),
      'startDate': startDate?.toIso8601String(),
      'targetDate': targetDate?.toIso8601String(),
      'progressMode': progressMode.name,
      'manualProgress': manualProgress,
      'completedAt': completedAt?.toIso8601String(),
      'notes': notes,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      status: GoalStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => GoalStatus.active,
      ),
      priority: GoalPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => GoalPriority.medium,
      ),
      icon: json['icon'] as String? ?? '🎯',
      color: json['color'] != null ? Color(json['color'] as int) : Colors.blue,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      targetDate: json['targetDate'] != null ? DateTime.parse(json['targetDate'] as String) : null,
      progressMode: ProgressMode.values.firstWhere(
        (m) => m.name == json['progressMode'],
        orElse: () => ProgressMode.auto,
      ),
      manualProgress: (json['manualProgress'] as num?)?.toDouble() ?? 0.0,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      notes: json['notes'] as String? ?? '',
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

