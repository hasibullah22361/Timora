import 'package:uuid/uuid.dart';

enum CareerRoadmapStatus { notStarted, inProgress, completed, paused }

class CareerRoadmapModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String targetRole;
  final CareerRoadmapStatus status;
  final double progress; // 0 - 100%
  final DateTime createdAt;
  final DateTime updatedAt;

  CareerRoadmapModel({
    String? id,
    this.userId = '',
    required this.title,
    this.description = '',
    required this.targetRole,
    this.status = CareerRoadmapStatus.inProgress,
    this.progress = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  CareerRoadmapModel copyWith({
    String? title,
    String? description,
    String? targetRole,
    CareerRoadmapStatus? status,
    double? progress,
    DateTime? updatedAt,
  }) {
    return CareerRoadmapModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetRole: targetRole ?? this.targetRole,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'targetRole': targetRole,
      'status': status.name,
      'progress': progress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CareerRoadmapModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final createdRaw = json['createdAt'] ?? json['created_at'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];

    return CareerRoadmapModel(
      id: json['id'] as String? ?? const Uuid().v4(),
      userId: json['userId'] ?? json['user_id'] ?? '',
      title: json['title'] as String? ?? 'Career Roadmap',
      description: json['description'] as String? ?? '',
      targetRole: json['targetRole'] ?? json['target_role'] ?? 'Specialist',
      status: CareerRoadmapStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CareerRoadmapStatus.inProgress,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdRaw != null ? (DateTime.tryParse(createdRaw.toString()) ?? now) : now,
      updatedAt: updatedRaw != null ? (DateTime.tryParse(updatedRaw.toString()) ?? now) : now,
    );
  }
}
