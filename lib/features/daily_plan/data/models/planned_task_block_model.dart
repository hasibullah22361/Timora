import 'package:flutter/material.dart';

enum PlannedBlockStatus { pending, completed, missed }

class PlannedTaskBlockModel {
  final String id;
  final String dailyPlanId;
  final String taskId;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int estimatedDurationSeconds;
  final PlannedBlockStatus status;
  final String? focusSessionId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PlannedTaskBlockModel({
    required this.id,
    required this.dailyPlanId,
    required this.taskId,
    required this.startTime,
    required this.endTime,
    required this.estimatedDurationSeconds,
    this.status = PlannedBlockStatus.pending,
    this.focusSessionId,
    required this.createdAt,
    this.updatedAt,
  });

  PlannedTaskBlockModel copyWith({
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? estimatedDurationSeconds,
    PlannedBlockStatus? status,
    String? focusSessionId,
    DateTime? updatedAt,
  }) {
    return PlannedTaskBlockModel(
      id: id,
      dailyPlanId: dailyPlanId,
      taskId: taskId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      estimatedDurationSeconds: estimatedDurationSeconds ?? this.estimatedDurationSeconds,
      status: status ?? this.status,
      focusSessionId: focusSessionId ?? this.focusSessionId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dailyPlanId': dailyPlanId,
      'taskId': taskId,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'estimatedDurationSeconds': estimatedDurationSeconds,
      'status': status.name,
      'focusSessionId': focusSessionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory PlannedTaskBlockModel.fromJson(Map<String, dynamic> json) {
    final dpId = (json['dailyPlanId'] ?? json['daily_plan_id']) as String? ?? '';
    final tId = (json['taskId'] ?? json['task_id']) as String? ?? '';
    final sHour = (json['startHour'] ?? json['start_hour']) as int? ?? 0;
    final sMinute = (json['startMinute'] ?? json['start_minute']) as int? ?? 0;
    final eHour = (json['endHour'] ?? json['end_hour']) as int? ?? 0;
    final eMinute = (json['endMinute'] ?? json['end_minute']) as int? ?? 0;
    final estSec = (json['estimatedDurationSeconds'] ?? json['estimated_duration_seconds']) as int? ?? 0;
    final fsId = (json['focusSessionId'] ?? json['focus_session_id']) as String?;
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];

    return PlannedTaskBlockModel(
      id: json['id'] as String,
      dailyPlanId: dpId,
      taskId: tId,
      startTime: TimeOfDay(hour: sHour, minute: sMinute),
      endTime: TimeOfDay(hour: eHour, minute: eMinute),
      estimatedDurationSeconds: estSec,
      status: PlannedBlockStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PlannedBlockStatus.pending,
      ),
      focusSessionId: fsId,
      createdAt: createdRaw != null
          ? (DateTime.tryParse(createdRaw.toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: updatedRaw != null
          ? DateTime.tryParse(updatedRaw.toString())
          : null,
    );
  }
}

