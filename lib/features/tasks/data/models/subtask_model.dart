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
    return SubtaskModel(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

