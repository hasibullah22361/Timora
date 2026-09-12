import 'package:uuid/uuid.dart';

class ProductivityEventType {
  static const String taskCreated = 'TASK_CREATED';
  static const String taskStarted = 'TASK_STARTED';
  static const String taskCompleted = 'TASK_COMPLETED';
  static const String taskMissed = 'TASK_MISSED';
  static const String taskRecovered = 'TASK_RECOVERED';
  static const String taskRescheduled = 'TASK_RESCHEDULED';

  static const String activityStarted = 'ACTIVITY_STARTED';
  static const String activityCompleted = 'ACTIVITY_COMPLETED';
  static const String activityMissed = 'ACTIVITY_MISSED';
  static const String activityRescheduled = 'ACTIVITY_RESCHEDULED';
  static const String activityReplaced = 'ACTIVITY_REPLACED';

  static const String routineCompleted = 'ROUTINE_COMPLETED';
  static const String routineMissed = 'ROUTINE_MISSED';

  static const String autopilotAction = 'AUTOPILOT_ACTION';
  static const String notificationSent = 'NOTIFICATION_SENT';

  static const String careerMilestoneStarted = 'CAREER_MILESTONE_STARTED';
  static const String careerMilestoneCompleted = 'CAREER_MILESTONE_COMPLETED';
}

class ProductivityEventModel {
  final String id;
  final String eventType;
  final String entityType;
  final String entityId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  ProductivityEventModel({
    String? id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? const {},
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventType': eventType,
      'entityType': entityType,
      'entityId': entityId,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProductivityEventModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final timeRaw = json['timestamp'] ?? json['created_at'];
    final createdRaw = json['createdAt'] ?? json['created_at'];

    return ProductivityEventModel(
      id: json['id'] as String? ?? const Uuid().v4(),
      eventType: json['eventType'] ?? json['event_type'] ?? 'UNKNOWN',
      entityType: json['entityType'] ?? json['entity_type'] ?? 'general',
      entityId: json['entityId'] ?? json['entity_id'] ?? '',
      timestamp: timeRaw != null ? (DateTime.tryParse(timeRaw.toString()) ?? now) : now,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      createdAt: createdRaw != null ? (DateTime.tryParse(createdRaw.toString()) ?? now) : now,
    );
  }
}
