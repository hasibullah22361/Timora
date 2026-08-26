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
    return MilestoneModel(
      id: json['id'] as String,
      goalId: json['goalId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: MilestoneStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MilestoneStatus.notStarted,
      ),
      priority: json['priority'] as int? ?? 1,
      targetDate: json['targetDate'] != null ? DateTime.parse(json['targetDate'] as String) : null,
      order: json['order'] as int? ?? 0,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

