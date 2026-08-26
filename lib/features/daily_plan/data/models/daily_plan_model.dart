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
    return DailyPlanModel(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      status: DailyPlanStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DailyPlanStatus.draft,
      ),
      plannedDurationSeconds: json['plannedDurationSeconds'] as int? ?? 0,
      completedDurationSeconds: json['completedDurationSeconds'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

