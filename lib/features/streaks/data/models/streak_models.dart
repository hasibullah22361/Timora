enum StreakType {
  focus,
  task,
  routine,
  goal,
  project,
}

extension StreakTypeExt on StreakType {
  String get label {
    switch (this) {
      case StreakType.focus: return 'Focus';
      case StreakType.task: return 'Tasks';
      case StreakType.routine: return 'Routine';
      case StreakType.goal: return 'Goal Activity';
      case StreakType.project: return 'Project Activity';
    }
  }
}

class StreakModel {
  final String id;
  final StreakType type;
  final String? targetId;
  final int currentCount;
  final int bestCount;
  final DateTime? currentStartDate;
  final DateTime? lastActiveDate;
  final DateTime updatedAt;
  final Map<DateTime, String> recentHistory; // Date -> Status (e.g., 'completed', 'missed', 'frozen')

  StreakModel({
    required this.id,
    required this.type,
    this.targetId,
    this.currentCount = 0,
    this.bestCount = 0,
    this.currentStartDate,
    this.lastActiveDate,
    required this.updatedAt,
    this.recentHistory = const {},
  });
}

class StreakSettingsModel {
  final bool automaticFreezeEnabled;
  final int availableFreezes;

  StreakSettingsModel({
    this.automaticFreezeEnabled = true,
    this.availableFreezes = 3,
  });
}

class StreakFreezeModel {
  final String id;
  final String streakId;
  final DateTime date;
  final String reason;
  final DateTime createdAt;

  StreakFreezeModel({
    required this.id,
    required this.streakId,
    required this.date,
    required this.reason,
    required this.createdAt,
  });
}
