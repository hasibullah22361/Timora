class WeeklyPlanModel {
  final String id;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final String status;
  final String notes;
  final int plannedDurationSeconds;
  final int targetFocusDurationSeconds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WeeklyPlanModel({
    required this.id,
    required this.weekStartDate,
    required this.weekEndDate,
    this.status = 'draft',
    this.notes = '',
    this.plannedDurationSeconds = 0,
    this.targetFocusDurationSeconds = 0,
    required this.createdAt,
    this.updatedAt,
  });

  WeeklyPlanModel copyWith({
    String? status,
    String? notes,
    int? plannedDurationSeconds,
    int? targetFocusDurationSeconds,
    DateTime? updatedAt,
  }) {
    return WeeklyPlanModel(
      id: id,
      weekStartDate: weekStartDate,
      weekEndDate: weekEndDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      plannedDurationSeconds: plannedDurationSeconds ?? this.plannedDurationSeconds,
      targetFocusDurationSeconds: targetFocusDurationSeconds ?? this.targetFocusDurationSeconds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'weekStartDate': weekStartDate.toIso8601String(),
      'weekEndDate': weekEndDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'plannedDurationSeconds': plannedDurationSeconds,
      'targetFocusDurationSeconds': targetFocusDurationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory WeeklyPlanModel.fromJson(Map<String, dynamic> json) {
    return WeeklyPlanModel(
      id: json['id'] as String,
      weekStartDate: DateTime.parse(json['weekStartDate'] as String),
      weekEndDate: DateTime.parse(json['weekEndDate'] as String),
      status: json['status'] as String? ?? 'draft',
      notes: json['notes'] as String? ?? '',
      plannedDurationSeconds: json['plannedDurationSeconds'] as int? ?? 0,
      targetFocusDurationSeconds: json['targetFocusDurationSeconds'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

