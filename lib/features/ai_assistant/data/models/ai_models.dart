
class AIPrivacySettings {
  final bool assistantEnabled;
  final bool allowTasks;
  final bool allowGoals;
  final bool allowProjects;
  final bool allowSchedule;
  final bool allowFocus;
  final bool allowReviews;
  final bool allowAnalytics;

  AIPrivacySettings({
    this.assistantEnabled = true,
    this.allowTasks = true,
    this.allowGoals = true,
    this.allowProjects = true,
    this.allowSchedule = true,
    this.allowFocus = true,
    this.allowReviews = true,
    this.allowAnalytics = true,
  });

  AIPrivacySettings copyWith({
    bool? assistantEnabled,
    bool? allowTasks,
    bool? allowGoals,
    bool? allowProjects,
    bool? allowSchedule,
    bool? allowFocus,
    bool? allowReviews,
    bool? allowAnalytics,
  }) {
    return AIPrivacySettings(
      assistantEnabled: assistantEnabled ?? this.assistantEnabled,
      allowTasks: allowTasks ?? this.allowTasks,
      allowGoals: allowGoals ?? this.allowGoals,
      allowProjects: allowProjects ?? this.allowProjects,
      allowSchedule: allowSchedule ?? this.allowSchedule,
      allowFocus: allowFocus ?? this.allowFocus,
      allowReviews: allowReviews ?? this.allowReviews,
      allowAnalytics: allowAnalytics ?? this.allowAnalytics,
    );
  }
}

enum AIMessageRole { user, assistant, system }

class AIMessage {
  final String id;
  final AIMessageRole role;
  final String content;
  final DateTime createdAt;
  final AIActionPayload? actionPayload; // If the AI proposed a plan

  AIMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.actionPayload,
  });
}

// Representing structured JSON returned from the LLM
class AIActionPayload {
  final String summary;
  final String confidence;
  final List<AIAction> actions;

  AIActionPayload({
    required this.summary,
    required this.confidence,
    required this.actions,
  });
}

enum AIActionType { createTask, createFocusSession, updateTask, scheduleActivity, createHabit }

class AIAction {
  final String id;
  final AIActionType type;
  final Map<String, dynamic> data;

  AIAction({
    required this.id,
    required this.type,
    required this.data,
  });
}
