class MonthlyPlanModel {
  final String id;
  final int year;
  final int month;
  final String status;
  final String notes;
  final int plannedDurationSeconds;
  final int targetFocusDurationSeconds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MonthlyPlanModel({
    required this.id,
    required this.year,
    required this.month,
    this.status = 'draft',
    this.notes = '',
    this.plannedDurationSeconds = 0,
    this.targetFocusDurationSeconds = 0,
    required this.createdAt,
    this.updatedAt,
  });

  MonthlyPlanModel copyWith({
    String? status,
    String? notes,
    int? plannedDurationSeconds,
    int? targetFocusDurationSeconds,
    DateTime? updatedAt,
  }) {
    return MonthlyPlanModel(
      id: id,
      year: year,
      month: month,
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
      'year': year,
      'month': month,
      'status': status,
      'notes': notes,
      'plannedDurationSeconds': plannedDurationSeconds,
      'targetFocusDurationSeconds': targetFocusDurationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MonthlyPlanModel.fromJson(Map<String, dynamic> json) {
    return MonthlyPlanModel(
      id: json['id'] as String,
      year: json['year'] as int,
      month: json['month'] as int,
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

