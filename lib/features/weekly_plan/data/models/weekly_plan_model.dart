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
    final now = DateTime.now();
    final startRaw = json['weekStartDate'] ?? json['week_start_date'];
    final endRaw = json['weekEndDate'] ?? json['week_end_date'];
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];
    final planSec = (json['plannedDurationSeconds'] ?? json['planned_duration_seconds']) as int? ?? 0;
    final focusSec = (json['targetFocusDurationSeconds'] ?? json['target_focus_duration_seconds']) as int? ?? 0;

    return WeeklyPlanModel(
      id: json['id'] as String,
      weekStartDate: startRaw != null ? (DateTime.tryParse(startRaw.toString()) ?? now) : now,
      weekEndDate: endRaw != null ? (DateTime.tryParse(endRaw.toString()) ?? now.add(const Duration(days: 7))) : now.add(const Duration(days: 7)),
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

