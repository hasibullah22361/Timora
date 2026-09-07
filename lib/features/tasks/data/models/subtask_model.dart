class SubtaskModel {
  final String id;
  final String taskId;
  final String title;
  final bool completed;
  final int order;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SubtaskModel({
    required this.id,
    required this.taskId,
    required this.title,
    this.completed = false,
    required this.order,
    required this.createdAt,
    this.updatedAt,
  });

  SubtaskModel copyWith({
    String? title,
    bool? completed,
    int? order,
    DateTime? updatedAt,
  }) {
    return SubtaskModel(
      id: id,
      taskId: taskId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      order: order ?? this.order,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'title': title,
      'completed': completed,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory SubtaskModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];
    final sortOrder = (json['order'] ?? json['sort_order']) as int? ?? 0;
    final isDone = (json['completed'] ?? json['is_completed']) as bool? ?? false;

    return SubtaskModel(
      id: json['id'] as String,
      taskId: (json['taskId'] ?? json['task_id']) as String? ?? '',
      title: json['title'] as String? ?? 'Subtask',
      completed: isDone,
      order: sortOrder,
      createdAt: createdRaw != null
          ? (DateTime.tryParse(createdRaw.toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: updatedRaw != null
          ? DateTime.tryParse(updatedRaw.toString())
          : null,
    );
  }
}

