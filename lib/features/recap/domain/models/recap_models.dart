import 'package:flutter/foundation.dart';
import '../../../schedule/data/models/schedule_activity.dart';

enum RecapType { daily, weekly, monthly }

enum TaskOutcomeStatus {
  completed,
  missed,
  skipped,
  replaced,
  rescheduled,
  incomplete,
}

@immutable
class TaskOutcomeItem {
  final String taskId;
  final String title;
  final TaskOutcomeStatus status;
  final DateTime? scheduledTime;
  final String category;
  final int durationMinutes;
  final String? replacedByTitle;
  final String? replacesTitle;
  final bool isRescheduled;
  final String? missedReason;

  const TaskOutcomeItem({
    required this.taskId,
    required this.title,
    required this.status,
    this.scheduledTime,
    this.category = 'General',
    this.durationMinutes = 30,
    this.replacedByTitle,
    this.replacesTitle,
    this.isRescheduled = false,
    this.missedReason,
  });

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'title': title,
        'status': status.name,
        'scheduledTime': scheduledTime?.toIso8601String(),
        'category': category,
        'durationMinutes': durationMinutes,
        'replacedByTitle': replacedByTitle,
        'replacesTitle': replacesTitle,
        'isRescheduled': isRescheduled,
        'missedReason': missedReason,
      };

  factory TaskOutcomeItem.fromJson(Map<String, dynamic> json) {
    return TaskOutcomeItem(
      taskId: json['taskId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: TaskOutcomeStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TaskOutcomeStatus.incomplete,
      ),
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'] as String)
          : null,
      category: json['category'] as String? ?? 'General',
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      replacedByTitle: json['replacedByTitle'] as String?,
      replacesTitle: json['replacesTitle'] as String?,
      isRescheduled: json['isRescheduled'] as bool? ?? false,
      missedReason: json['missedReason'] as String?,
    );
  }
}

@immutable
class RecapTimelineItem {
  final String id;
  final String title;
  final DateTime time;
  final DateTime? endTime;
  final String category;
  final String icon;
  final ActivityStatus status;
  final String? note;

  const RecapTimelineItem({
    required this.id,
    required this.title,
    required this.time,
    this.endTime,
    this.category = 'Activity',
    this.icon = '📌',
    required this.status,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time': time.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'category': category,
        'icon': icon,
        'status': status.name,
        'note': note,
      };

  factory RecapTimelineItem.fromJson(Map<String, dynamic> json) {
    return RecapTimelineItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      time: json['time'] != null
          ? DateTime.parse(json['time'] as String)
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      category: json['category'] as String? ?? 'Activity',
      icon: json['icon'] as String? ?? '📌',
      status: ActivityStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ActivityStatus.upcoming,
      ),
      note: json['note'] as String?,
    );
  }
}

@immutable
class TomorrowRecommendation {
  final String id;
  final String title;
  final String priority; // High, Medium, Low
  final String activityCategory; // Focus, Routine, Task
  final int estimatedMinutes;
  final String reason;
  final bool isApplied;

  const TomorrowRecommendation({
    required this.id,
    required this.title,
    required this.priority,
    this.activityCategory = 'Focus',
    this.estimatedMinutes = 30,
    required this.reason,
    this.isApplied = false,
  });

  TomorrowRecommendation copyWith({bool? isApplied}) {
    return TomorrowRecommendation(
      id: id,
      title: title,
      priority: priority,
      activityCategory: activityCategory,
      estimatedMinutes: estimatedMinutes,
      reason: reason,
      isApplied: isApplied ?? this.isApplied,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority,
        'activityCategory': activityCategory,
        'estimatedMinutes': estimatedMinutes,
        'reason': reason,
        'isApplied': isApplied,
      };

  factory TomorrowRecommendation.fromJson(Map<String, dynamic> json) {
    return TomorrowRecommendation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      priority: json['priority'] as String? ?? 'Medium',
      activityCategory: json['activityCategory'] as String? ?? 'Focus',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 30,
      reason: json['reason'] as String? ?? '',
      isApplied: json['isApplied'] as bool? ?? false,
    );
  }
}

@immutable
class TimoraRecapModel {
  final String id;
  final RecapType type;
  final DateTime targetDate;
  final DateTime periodStart;
  final DateTime periodEnd;

  // Task metrics
  final int totalTasks;
  final int completedTasks;
  final int incompleteTasks;
  final int missedTasks;
  final int skippedTasks;
  final int replacedTasks;
  final int rescheduledTasks;
  final List<TaskOutcomeItem> taskOutcomes;

  // Activity & Routine metrics
  final int totalActivities;
  final int completedActivities;
  final int missedActivities;
  final int skippedActivities;
  final int replacedActivities;
  final int completedRoutines;
  final int missedRoutines;

  // Focus metrics
  final int focusMinutes;
  final int deepWorkMinutes;

  // Performance scores
  final double productivityScore; // 0 - 100
  final double routineConsistency; // 0 - 100
  final double scheduleAdherence; // 0 - 100
  final double goalProgress; // 0 - 100

  // Timeline
  final List<RecapTimelineItem> timelineItems;

  // Qualitative analysis (Real data backed)
  final List<String> wins;
  final List<String> areasToImprove;
  final String aiSummary; // 3-line concise summary
  final String spokenScript; // Short speech script for native TTS
  final String notificationBody; // Short status text
  final List<String> aiInsights;
  final List<TomorrowRecommendation> tomorrowRecommendations;

  // Persistence & Diary integration
  final bool isSavedToDiary;
  final String? diaryEntryId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TimoraRecapModel({
    required this.id,
    required this.type,
    required this.targetDate,
    required this.periodStart,
    required this.periodEnd,
    required this.totalTasks,
    required this.completedTasks,
    required this.incompleteTasks,
    required this.missedTasks,
    required this.skippedTasks,
    required this.replacedTasks,
    required this.rescheduledTasks,
    required this.taskOutcomes,
    required this.totalActivities,
    required this.completedActivities,
    required this.missedActivities,
    required this.skippedActivities,
    required this.replacedActivities,
    required this.completedRoutines,
    required this.missedRoutines,
    required this.focusMinutes,
    required this.deepWorkMinutes,
    required this.productivityScore,
    required this.routineConsistency,
    required this.scheduleAdherence,
    required this.goalProgress,
    required this.timelineItems,
    required this.wins,
    required this.areasToImprove,
    required this.aiSummary,
    required this.spokenScript,
    required this.notificationBody,
    required this.aiInsights,
    required this.tomorrowRecommendations,
    this.isSavedToDiary = false,
    this.diaryEntryId,
    required this.createdAt,
    this.updatedAt,
  });

  /// Deterministic ID generator to prevent duplicate records
  static String buildRecapId(RecapType type, DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    switch (type) {
      case RecapType.daily:
        return 'recap_daily_${y}_${m}_$d';
      case RecapType.weekly:
        // Identify week by its start date (Monday)
        final daysToSubtract = date.weekday - 1;
        final monday = date.subtract(Duration(days: daysToSubtract));
        final my = monday.year.toString().padLeft(4, '0');
        final mm = monday.month.toString().padLeft(2, '0');
        final md = monday.day.toString().padLeft(2, '0');
        return 'recap_weekly_${my}_${mm}_$md';
      case RecapType.monthly:
        return 'recap_monthly_${y}_$m';
    }
  }

  TimoraRecapModel copyWith({
    String? id,
    RecapType? type,
    DateTime? targetDate,
    DateTime? periodStart,
    DateTime? periodEnd,
    int? totalTasks,
    int? completedTasks,
    int? incompleteTasks,
    int? missedTasks,
    int? skippedTasks,
    int? replacedTasks,
    int? rescheduledTasks,
    List<TaskOutcomeItem>? taskOutcomes,
    int? totalActivities,
    int? completedActivities,
    int? missedActivities,
    int? skippedActivities,
    int? replacedActivities,
    int? completedRoutines,
    int? missedRoutines,
    int? focusMinutes,
    int? deepWorkMinutes,
    double? productivityScore,
    double? routineConsistency,
    double? scheduleAdherence,
    double? goalProgress,
    List<RecapTimelineItem>? timelineItems,
    List<String>? wins,
    List<String>? areasToImprove,
    String? aiSummary,
    String? spokenScript,
    String? notificationBody,
    List<String>? aiInsights,
    List<TomorrowRecommendation>? tomorrowRecommendations,
    bool? isSavedToDiary,
    String? diaryEntryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimoraRecapModel(
      id: id ?? this.id,
      type: type ?? this.type,
      targetDate: targetDate ?? this.targetDate,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      incompleteTasks: incompleteTasks ?? this.incompleteTasks,
      missedTasks: missedTasks ?? this.missedTasks,
      skippedTasks: skippedTasks ?? this.skippedTasks,
      replacedTasks: replacedTasks ?? this.replacedTasks,
      rescheduledTasks: rescheduledTasks ?? this.rescheduledTasks,
      taskOutcomes: taskOutcomes ?? this.taskOutcomes,
      totalActivities: totalActivities ?? this.totalActivities,
      completedActivities: completedActivities ?? this.completedActivities,
      missedActivities: missedActivities ?? this.missedActivities,
      skippedActivities: skippedActivities ?? this.skippedActivities,
      replacedActivities: replacedActivities ?? this.replacedActivities,
      completedRoutines: completedRoutines ?? this.completedRoutines,
      missedRoutines: missedRoutines ?? this.missedRoutines,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      deepWorkMinutes: deepWorkMinutes ?? this.deepWorkMinutes,
      productivityScore: productivityScore ?? this.productivityScore,
      routineConsistency: routineConsistency ?? this.routineConsistency,
      scheduleAdherence: scheduleAdherence ?? this.scheduleAdherence,
      goalProgress: goalProgress ?? this.goalProgress,
      timelineItems: timelineItems ?? this.timelineItems,
      wins: wins ?? this.wins,
      areasToImprove: areasToImprove ?? this.areasToImprove,
      aiSummary: aiSummary ?? this.aiSummary,
      spokenScript: spokenScript ?? this.spokenScript,
      notificationBody: notificationBody ?? this.notificationBody,
      aiInsights: aiInsights ?? this.aiInsights,
      tomorrowRecommendations:
          tomorrowRecommendations ?? this.tomorrowRecommendations,
      isSavedToDiary: isSavedToDiary ?? this.isSavedToDiary,
      diaryEntryId: diaryEntryId ?? this.diaryEntryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'targetDate': targetDate.toIso8601String(),
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'incompleteTasks': incompleteTasks,
        'missedTasks': missedTasks,
        'skippedTasks': skippedTasks,
        'replacedTasks': replacedTasks,
        'rescheduledTasks': rescheduledTasks,
        'taskOutcomes': taskOutcomes.map((t) => t.toJson()).toList(),
        'totalActivities': totalActivities,
        'completedActivities': completedActivities,
        'missedActivities': missedActivities,
        'skippedActivities': skippedActivities,
        'replacedActivities': replacedActivities,
        'completedRoutines': completedRoutines,
        'missedRoutines': missedRoutines,
        'focusMinutes': focusMinutes,
        'deepWorkMinutes': deepWorkMinutes,
        'productivityScore': productivityScore,
        'routineConsistency': routineConsistency,
        'scheduleAdherence': scheduleAdherence,
        'goalProgress': goalProgress,
        'timelineItems': timelineItems.map((t) => t.toJson()).toList(),
        'wins': wins,
        'areasToImprove': areasToImprove,
        'aiSummary': aiSummary,
        'spokenScript': spokenScript,
        'notificationBody': notificationBody,
        'aiInsights': aiInsights,
        'tomorrowRecommendations':
            tomorrowRecommendations.map((r) => r.toJson()).toList(),
        'isSavedToDiary': isSavedToDiary,
        'diaryEntryId': diaryEntryId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory TimoraRecapModel.fromJson(Map<String, dynamic> json) {
    return TimoraRecapModel(
      id: json['id'] as String,
      type: RecapType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => RecapType.daily,
      ),
      targetDate: DateTime.parse(json['targetDate'] as String),
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      totalTasks: json['totalTasks'] as int? ?? 0,
      completedTasks: json['completedTasks'] as int? ?? 0,
      incompleteTasks: json['incompleteTasks'] as int? ?? 0,
      missedTasks: json['missedTasks'] as int? ?? 0,
      skippedTasks: json['skippedTasks'] as int? ?? 0,
      replacedTasks: json['replacedTasks'] as int? ?? 0,
      rescheduledTasks: json['rescheduledTasks'] as int? ?? 0,
      taskOutcomes: (json['taskOutcomes'] as List<dynamic>?)
              ?.map((t) => TaskOutcomeItem.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      totalActivities: json['totalActivities'] as int? ?? 0,
      completedActivities: json['completedActivities'] as int? ?? 0,
      missedActivities: json['missedActivities'] as int? ?? 0,
      skippedActivities: json['skippedActivities'] as int? ?? 0,
      replacedActivities: json['replacedActivities'] as int? ?? 0,
      completedRoutines: json['completedRoutines'] as int? ?? 0,
      missedRoutines: json['missedRoutines'] as int? ?? 0,
      focusMinutes: json['focusMinutes'] as int? ?? 0,
      deepWorkMinutes: json['deepWorkMinutes'] as int? ?? 0,
      productivityScore: (json['productivityScore'] as num?)?.toDouble() ?? 0.0,
      routineConsistency:
          (json['routineConsistency'] as num?)?.toDouble() ?? 0.0,
      scheduleAdherence: (json['scheduleAdherence'] as num?)?.toDouble() ?? 0.0,
      goalProgress: (json['goalProgress'] as num?)?.toDouble() ?? 0.0,
      timelineItems: (json['timelineItems'] as List<dynamic>?)
              ?.map(
                  (t) => RecapTimelineItem.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      wins:
          (json['wins'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      areasToImprove: (json['areasToImprove'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      aiSummary: json['aiSummary'] as String? ?? '',
      spokenScript: json['spokenScript'] as String? ?? '',
      notificationBody: json['notificationBody'] as String? ?? '',
      aiInsights: (json['aiInsights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tomorrowRecommendations: (json['tomorrowRecommendations']
                  as List<dynamic>?)
              ?.map((r) =>
                  TomorrowRecommendation.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      isSavedToDiary: json['isSavedToDiary'] as bool? ?? false,
      diaryEntryId: json['diaryEntryId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
