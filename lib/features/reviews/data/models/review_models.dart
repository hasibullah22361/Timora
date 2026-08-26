enum ReviewType {
  daily,
  weekly,
  monthly,
}

extension ReviewTypeExt on ReviewType {
  String get label {
    switch (this) {
      case ReviewType.daily: return 'Daily Review';
      case ReviewType.weekly: return 'Weekly Review';
      case ReviewType.monthly: return 'Monthly Review';
    }
  }
}

enum ReviewStatus {
  notStarted,
  inProgress,
  completed,
}

class ReviewModel {
  final String id;
  final ReviewType type;
  final DateTime date; 
  final DateTime periodStart;
  final DateTime periodEnd;
  final ReviewStatus status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewModel({
    required this.id,
    required this.type,
    required this.date,
    required this.periodStart,
    required this.periodEnd,
    this.status = ReviewStatus.notStarted,
    this.completedAt,
    required this.createdAt,
    this.updatedAt,
  });

  ReviewModel copyWith({
    ReviewStatus? status,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id,
      type: type,
      date: date,
      periodStart: periodStart,
      periodEnd: periodEnd,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'date': date.toIso8601String(),
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'status': status.name,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      type: ReviewType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ReviewType.daily,
      ),
      date: DateTime.parse(json['date'] as String),
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      status: ReviewStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ReviewStatus.notStarted,
      ),
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

class ReviewReflectionModel {
  final String id;
  final String reviewId;
  final String wentWell;
  final String challenges;
  final String improvements;
  final String highlight;
  final String lesson;
  final String blockers;
  final String nextPriorities;
  final String energy;
  final String mood;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewReflectionModel({
    required this.id,
    required this.reviewId,
    this.wentWell = '',
    this.challenges = '',
    this.improvements = '',
    this.highlight = '',
    this.lesson = '',
    this.blockers = '',
    this.nextPriorities = '',
    this.energy = '',
    this.mood = '',
    required this.createdAt,
    this.updatedAt,
  });

  ReviewReflectionModel copyWith({
    String? wentWell,
    String? challenges,
    String? improvements,
    String? highlight,
    String? lesson,
    String? blockers,
    String? nextPriorities,
    String? energy,
    String? mood,
    DateTime? updatedAt,
  }) {
    return ReviewReflectionModel(
      id: id,
      reviewId: reviewId,
      wentWell: wentWell ?? this.wentWell,
      challenges: challenges ?? this.challenges,
      improvements: improvements ?? this.improvements,
      highlight: highlight ?? this.highlight,
      lesson: lesson ?? this.lesson,
      blockers: blockers ?? this.blockers,
      nextPriorities: nextPriorities ?? this.nextPriorities,
      energy: energy ?? this.energy,
      mood: mood ?? this.mood,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reviewId': reviewId,
      'wentWell': wentWell,
      'challenges': challenges,
      'improvements': improvements,
      'highlight': highlight,
      'lesson': lesson,
      'blockers': blockers,
      'nextPriorities': nextPriorities,
      'energy': energy,
      'mood': mood,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ReviewReflectionModel.fromJson(Map<String, dynamic> json) {
    return ReviewReflectionModel(
      id: json['id'] as String,
      reviewId: json['reviewId'] as String,
      wentWell: json['wentWell'] as String? ?? '',
      challenges: json['challenges'] as String? ?? '',
      improvements: json['improvements'] as String? ?? '',
      highlight: json['highlight'] as String? ?? '',
      lesson: json['lesson'] as String? ?? '',
      blockers: json['blockers'] as String? ?? '',
      nextPriorities: json['nextPriorities'] as String? ?? '',
      energy: json['energy'] as String? ?? '',
      mood: json['mood'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

