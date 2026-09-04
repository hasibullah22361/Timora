class HabitLogModel {
  final String id;
  final String habitId;
  final DateTime logDate; // Normalized to YYYY-MM-DD
  final bool completed;
  final String notes;
  final DateTime createdAt;

  HabitLogModel({
    required this.id,
    required this.habitId,
    required this.logDate,
    this.completed = true,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habitId': habitId,
      'logDate': '${logDate.year}-${logDate.month.toString().padLeft(2, '0')}-${logDate.day.toString().padLeft(2, '0')}',
      'completed': completed,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HabitLogModel.fromJson(Map<String, dynamic> json) {
    return HabitLogModel(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      logDate: DateTime.parse(json['logDate'] as String),
      completed: json['completed'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
