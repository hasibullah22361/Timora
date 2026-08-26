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
    return PlannedTaskBlockModel(
      id: json['id'] as String,
      dailyPlanId: json['dailyPlanId'] as String,
      taskId: json['taskId'] as String,
      startTime: TimeOfDay(
        hour: json['startHour'] as int? ?? 0,
        minute: json['startMinute'] as int? ?? 0,
      ),
      endTime: TimeOfDay(
        hour: json['endHour'] as int? ?? 0,
        minute: json['endMinute'] as int? ?? 0,
      ),
      estimatedDurationSeconds: json['estimatedDurationSeconds'] as int? ?? 0,
      status: PlannedBlockStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PlannedBlockStatus.pending,
      ),
      focusSessionId: json['focusSessionId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

