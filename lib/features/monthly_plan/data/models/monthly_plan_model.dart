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
    final now = DateTime.now();
    final y = (json['year'] ?? json['plan_year']) as int? ?? now.year;
    final m = (json['month'] ?? json['plan_month']) as int? ?? now.month;
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];
    final planSec = (json['plannedDurationSeconds'] ?? json['planned_duration_seconds']) as int? ?? 0;
    final focusSec = (json['targetFocusDurationSeconds'] ?? json['target_focus_duration_seconds']) as int? ?? 0;

    return MonthlyPlanModel(
      id: json['id'] as String,
      year: y,
      month: m,
      status: json['status'] as String? ?? 'draft',
      notes: json['notes'] as String? ?? '',
      plannedDurationSeconds: planSec,
      targetFocusDurationSeconds: focusSec,
      createdAt: createdRaw != null
          ? (DateTime.tryParse(createdRaw.toString()) ?? now)
          : now,
      updatedAt: updatedRaw != null
          ? DateTime.tryParse(updatedRaw.toString())
          : null,
    );
  }
}

