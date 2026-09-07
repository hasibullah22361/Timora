import 'package:uuid/uuid.dart';

enum AutopilotActionStatus { suggested, applied, rejected }

class AutopilotActionModel {
  final String id;
  final String actionType; // 'reschedule_missed', 'resolve_conflict', 'optimize_routine'
  final String entityId;
  final String title;
  final DateTime originalStart;
  final DateTime originalEnd;
  final DateTime newStart;
  final DateTime newEnd;
  final String reason;
  final AutopilotActionStatus status;
  final DateTime createdAt;

  AutopilotActionModel({
    String? id,
    required this.actionType,
    required this.entityId,
    required this.title,
    required this.originalStart,
    required this.originalEnd,
    required this.newStart,
    required this.newEnd,
    required this.reason,
    this.status = AutopilotActionStatus.applied,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actionType': actionType,
      'entityId': entityId,
      'title': title,
      'originalStart': originalStart.toIso8601String(),
      'originalEnd': originalEnd.toIso8601String(),
      'newStart': newStart.toIso8601String(),
      'newEnd': newEnd.toIso8601String(),
      'reason': reason,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AutopilotActionModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final origStartRaw = json['originalStart'] ?? json['original_start'];
    final origEndRaw = json['originalEnd'] ?? json['original_end'];
    final newStartRaw = json['newStart'] ?? json['new_start'];
    final newEndRaw = json['newEnd'] ?? json['new_end'];
    final createdRaw = json['createdAt'] ?? json['created_at'];

    return AutopilotActionModel(
      id: json['id'] as String? ?? const Uuid().v4(),
      actionType: json['actionType'] ?? json['action_type'] ?? 'reschedule_missed',
      entityId: json['entityId'] ?? json['entity_id'] ?? '',
      title: json['title'] as String? ?? 'Action',
      originalStart: origStartRaw != null ? (DateTime.tryParse(origStartRaw.toString()) ?? now) : now,
      originalEnd: origEndRaw != null ? (DateTime.tryParse(origEndRaw.toString()) ?? now) : now,
      newStart: newStartRaw != null ? (DateTime.tryParse(newStartRaw.toString()) ?? now) : now,
      newEnd: newEndRaw != null ? (DateTime.tryParse(newEndRaw.toString()) ?? now) : now,
      reason: json['reason'] as String? ?? '',
      status: AutopilotActionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => AutopilotActionStatus.applied,
      ),
      createdAt: createdRaw != null ? (DateTime.tryParse(createdRaw.toString()) ?? now) : now,
    );
  }
}
