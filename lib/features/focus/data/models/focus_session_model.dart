enum FocusSessionStatus { running, paused, completed, cancelled, breakTime }
enum FocusSessionMode { focus, pomodoro, custom }

class FocusSessionModel {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? pausedAt; // Tracks when the session was last paused
  final int totalPausedDurationSeconds; // Cumulative paused time
  final int plannedDurationSeconds;
  final int actualDurationSeconds; // Total calculated focus time upon completion
  final FocusSessionStatus status;
  final FocusSessionMode mode;
  
  // Relationships
  final String? taskId;
  final String? projectId;
  final String? goalId;
  final String? milestoneId;
  final String? scheduleActivityId;
  final String? plannedTaskBlockId;
  
  final String notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FocusSessionModel({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.pausedAt,
    this.totalPausedDurationSeconds = 0,
    required this.plannedDurationSeconds,
    this.actualDurationSeconds = 0,
    this.status = FocusSessionStatus.running,
    this.mode = FocusSessionMode.focus,
    this.taskId,
    this.projectId,
    this.goalId,
    this.milestoneId,
    this.scheduleActivityId,
    this.plannedTaskBlockId,
    this.notes = '',
    required this.createdAt,
    this.updatedAt,
  });

  FocusSessionModel copyWith({
    DateTime? endedAt,
    DateTime? pausedAt,
    int? totalPausedDurationSeconds,
    int? actualDurationSeconds,
    FocusSessionStatus? status,
    FocusSessionMode? mode,
    String? notes,
    DateTime? updatedAt,
  }) {
    // Note: We don't typically change relationships after start
    return FocusSessionModel(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      pausedAt: pausedAt, // Can be null if resuming, so we assign directly or conditionally based on status
      totalPausedDurationSeconds: totalPausedDurationSeconds ?? this.totalPausedDurationSeconds,
      plannedDurationSeconds: plannedDurationSeconds,
      actualDurationSeconds: actualDurationSeconds ?? this.actualDurationSeconds,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      taskId: taskId,
      projectId: projectId,
      goalId: goalId,
      milestoneId: milestoneId,
      scheduleActivityId: scheduleActivityId,
      plannedTaskBlockId: plannedTaskBlockId,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'pausedAt': pausedAt?.toIso8601String(),
      'totalPausedDurationSeconds': totalPausedDurationSeconds,
      'plannedDurationSeconds': plannedDurationSeconds,
      'actualDurationSeconds': actualDurationSeconds,
      'status': status.name,
      'mode': mode.name,
      'taskId': taskId,
      'projectId': projectId,
      'goalId': goalId,
      'milestoneId': milestoneId,
      'scheduleActivityId': scheduleActivityId,
      'plannedTaskBlockId': plannedTaskBlockId,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory FocusSessionModel.fromJson(Map<String, dynamic> json) {
    return FocusSessionModel(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt'] as String) : null,
      pausedAt: json['pausedAt'] != null ? DateTime.parse(json['pausedAt'] as String) : null,
      totalPausedDurationSeconds: json['totalPausedDurationSeconds'] as int? ?? 0,
      plannedDurationSeconds: json['plannedDurationSeconds'] as int? ?? 1500,
      actualDurationSeconds: json['actualDurationSeconds'] as int? ?? 0,
      status: FocusSessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FocusSessionStatus.completed,
      ),
      mode: FocusSessionMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => FocusSessionMode.focus,
      ),
      taskId: json['taskId'] as String?,
      projectId: json['projectId'] as String?,
      goalId: json['goalId'] as String?,
      milestoneId: json['milestoneId'] as String?,
      scheduleActivityId: json['scheduleActivityId'] as String?,
      plannedTaskBlockId: json['plannedTaskBlockId'] as String?,
      notes: json['notes'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

