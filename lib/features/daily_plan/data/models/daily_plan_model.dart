enum DailyPlanStatus { draft, planned, inProgress, completed, archived }

class DailyPlanModel {
  final String id;
  final DateTime date;
  final DailyPlanStatus status;
  final int plannedDurationSeconds;
  final int completedDurationSeconds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DailyPlanModel({
    required this.id,
    required this.date,
    this.status = DailyPlanStatus.draft,
    this.plannedDurationSeconds = 0,
    this.completedDurationSeconds = 0,
    required this.createdAt,
    this.updatedAt,
  });

  DailyPlanModel copyWith({
    DailyPlanStatus? status,
    int? plannedDurationSeconds,
    int? completedDurationSeconds,
    DateTime? updatedAt,
  }) {
    return DailyPlanModel(
      id: id,
      date: date,
      status: status ?? this.status,
      plannedDurationSeconds: plannedDurationSeconds ?? this.plannedDurationSeconds,
      completedDurationSeconds: completedDurationSeconds ?? this.completedDurationSeconds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'status': status.name,
      'plannedDurationSeconds': plannedDurationSeconds,
      'completedDurationSeconds': completedDurationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory DailyPlanModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final dateRaw = json['date'] ?? json['plan_date'];
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];
    final plannedSec = (json['plannedDurationSeconds'] ?? json['planned_duration_seconds']) as int? ?? 0;
    final compSec = (json['completedDurationSeconds'] ?? json['completed_duration_seconds']) as int? ?? 0;

    return DailyPlanModel(
      id: json['id'] as String,
      date: dateRaw != null ? (DateTime.tryParse(dateRaw.toString()) ?? now) : now,
      status: DailyPlanStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DailyPlanStatus.draft,
      ),
      plannedDurationSeconds: plannedSec,
      completedDurationSeconds: compSec,
      createdAt: createdRaw != null
          ? (DateTime.tryParse(createdRaw.toString()) ?? now)
          : now,
      updatedAt: updatedRaw != null
          ? DateTime.tryParse(updatedRaw.toString())
          : null,
    );
  }
}

