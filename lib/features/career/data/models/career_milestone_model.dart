import 'package:uuid/uuid.dart';

enum CareerMilestoneStatus { notStarted, inProgress, completed, paused }

class CareerMilestoneModel {
  final String id;
  final String userId;
  final String roadmapId;
  final String title;
  final String description;
  final CareerMilestoneStatus status;
  final String priority;
  final int progress; // 0, 25, 50, 75, 100
  final DateTime? targetDate;
  final int sortOrder;
  final String? linkedTaskId;
  final String? linkedGoalId;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  CareerMilestoneModel({
    String? id,
    this.userId = '',
    required this.roadmapId,
    required this.title,
    this.description = '',
    this.status = CareerMilestoneStatus.notStarted,
    this.priority = 'Medium',
    this.progress = 0,
    this.targetDate,
    this.sortOrder = 0,
    this.linkedTaskId,
    this.linkedGoalId,
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  CareerMilestoneModel copyWith({
    String? title,
    String? description,
    CareerMilestoneStatus? status,
    String? priority,
    int? progress,
    DateTime? targetDate,
    int? sortOrder,
    String? linkedTaskId,
    String? linkedGoalId,
    String? notes,
    DateTime? updatedAt,
  }) {
    return CareerMilestoneModel(
      id: id,
      userId: userId,
      roadmapId: roadmapId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      targetDate: targetDate ?? this.targetDate,
      sortOrder: sortOrder ?? this.sortOrder,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'roadmapId': roadmapId,
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority,
      'progress': progress,
      'targetDate': targetDate?.toIso8601String(),
      'sortOrder': sortOrder,
      'linkedTaskId': linkedTaskId,
      'linkedGoalId': linkedGoalId,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CareerMilestoneModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final targetRaw = json['targetDate'] ?? json['target_date'];
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];

    return CareerMilestoneModel(
      id: json['id'] as String? ?? const Uuid().v4(),
      userId: json['userId'] ?? json['user_id'] ?? '',
      roadmapId: json['roadmapId'] ?? json['roadmap_id'] ?? '',
      title: json['title'] as String? ?? 'Milestone',
      description: json['description'] as String? ?? '',
      status: CareerMilestoneStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CareerMilestoneStatus.notStarted,
      ),
      priority: json['priority'] as String? ?? 'Medium',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      targetDate: targetRaw != null ? DateTime.tryParse(targetRaw.toString()) : null,
      sortOrder: (json['sortOrder'] ?? json['sort_order'] ?? 0) as int,
      linkedTaskId: (json['linkedTaskId'] ?? json['linked_task_id']) as String?,
      linkedGoalId: (json['linkedGoalId'] ?? json['linked_goal_id']) as String?,
      notes: json['notes'] as String? ?? '',
      createdAt: createdRaw != null ? (DateTime.tryParse(createdRaw.toString()) ?? now) : now,
      updatedAt: updatedRaw != null ? (DateTime.tryParse(updatedRaw.toString()) ?? now) : now,
    );
  }
}
