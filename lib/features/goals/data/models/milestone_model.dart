enum MilestoneStatus { notStarted, inProgress, completed, skipped }

class MilestoneModel {
  final String id;
  final String goalId;
  final String title;
  final String description;
  final MilestoneStatus status;
  final int priority;
  final DateTime? targetDate;
  final int order;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MilestoneModel({
    required this.id,
    required this.goalId,
    required this.title,
    this.description = '',
    this.status = MilestoneStatus.notStarted,
    this.priority = 1,
    this.targetDate,
    required this.order,
    this.completedAt,
    required this.createdAt,
    this.updatedAt,
  });

  MilestoneModel copyWith({
    String? title,
    String? description,
    MilestoneStatus? status,
    int? priority,
    DateTime? targetDate,
    int? order,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return MilestoneModel(
      id: id,
      goalId: goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      targetDate: targetDate ?? this.targetDate,
      order: order ?? this.order,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goalId': goalId,
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority,
      'targetDate': targetDate?.toIso8601String(),
      'order': order,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    final targetRaw = json['targetDate'] ?? json['target_date'];
    final completedRaw = json['completedAt'] ?? json['completed_at'];
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];
    final sortOrder = (json['order'] ?? json['sort_order']) as int? ?? 0;

    return MilestoneModel(
      id: json['id'] as String,
      goalId: (json['goalId'] ?? json['goal_id']) as String? ?? '',
      title: json['title'] as String? ?? 'Milestone',
      description: json['description'] as String? ?? '',
      status: MilestoneStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MilestoneStatus.notStarted,
      ),
      priority: json['priority'] as int? ?? 1,
      targetDate: targetRaw != null ? DateTime.tryParse(targetRaw.toString()) : null,
      order: sortOrder,
      completedAt: completedRaw != null ? DateTime.tryParse(completedRaw.toString()) : null,
      createdAt: createdRaw != null
          ? (DateTime.tryParse(createdRaw.toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: updatedRaw != null
          ? DateTime.tryParse(updatedRaw.toString())
          : null,
    );
  }
}

