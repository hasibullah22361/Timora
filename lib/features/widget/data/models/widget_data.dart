import 'dart:convert';

/// A single activity item for the widget's Today's Plan timeline.
class WidgetScheduleItem {
  final String id;
  final String title;
  final String timeStr;
  final int startMillis;
  final int endMillis;
  final bool isCompleted;

  const WidgetScheduleItem({
    required this.id,
    required this.title,
    required this.timeStr,
    required this.startMillis,
    required this.endMillis,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'timeStr': timeStr,
        'startMillis': startMillis,
        'endMillis': endMillis,
        'isCompleted': isCompleted,
      };

  factory WidgetScheduleItem.fromJson(Map<String, dynamic> json) {
    return WidgetScheduleItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      timeStr: json['timeStr'] as String? ?? '',
      startMillis: (json['startMillis'] as num?)?.toInt() ?? 0,
      endMillis: (json['endMillis'] as num?)?.toInt() ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

/// A single task item for the widget's compact Tasks section.
class WidgetTaskItem {
  final String id;
  final String title;
  final bool isCompleted;

  const WidgetTaskItem({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory WidgetTaskItem.fromJson(Map<String, dynamic> json) {
    return WidgetTaskItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

/// A single goal item for the widget's highlighted Goals section.
class WidgetGoalItem {
  final String id;
  final String title;
  final int progressPercentage;

  const WidgetGoalItem({
    required this.id,
    required this.title,
    required this.progressPercentage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'progressPercentage': progressPercentage,
      };

  factory WidgetGoalItem.fromJson(Map<String, dynamic> json) {
    return WidgetGoalItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      progressPercentage: (json['progressPercentage'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Compact data payload passed to the Android home screen widgets.
class WidgetData {
  // Legacy fields (retained for backward compatibility)
  final String? currentTaskId;
  final String? currentTaskTitle;
  final String? currentTaskTime;
  final String? nextTaskId;
  final String? nextTaskTitle;
  final String? nextTaskTime;
  final int completedTasksCount;
  final int totalTasksCount;
  final int progressPercentage;
  final bool focusActive;
  final String? focusTitle;
  final int focusRemainingSeconds;
  final List<WidgetScheduleItem> scheduleItems;

  // New fields for updated Home Screen Widget hierarchy
  final int unreadNotificationsCount;
  final String? currentActivityTitle;
  final String? currentActivityTime;
  final bool isActivityRunning;
  final List<WidgetTaskItem> tasks;
  final List<WidgetGoalItem> goals;

  final int lastUpdatedMillis;

  const WidgetData({
    this.currentTaskId,
    this.currentTaskTitle,
    this.currentTaskTime,
    this.nextTaskId,
    this.nextTaskTitle,
    this.nextTaskTime,
    this.completedTasksCount = 0,
    this.totalTasksCount = 0,
    this.progressPercentage = 0,
    this.focusActive = false,
    this.focusTitle,
    this.focusRemainingSeconds = 0,
    this.scheduleItems = const [],
    this.unreadNotificationsCount = 0,
    this.currentActivityTitle,
    this.currentActivityTime,
    this.isActivityRunning = false,
    this.tasks = const [],
    this.goals = const [],
    required this.lastUpdatedMillis,
  });

  Map<String, dynamic> toJson() => {
        'currentTaskId': currentTaskId ?? '',
        'currentTaskTitle': currentTaskTitle ?? '',
        'currentTaskTime': currentTaskTime ?? '',
        'nextTaskId': nextTaskId ?? '',
        'nextTaskTitle': nextTaskTitle ?? '',
        'nextTaskTime': nextTaskTime ?? '',
        'completedTasksCount': completedTasksCount,
        'totalTasksCount': totalTasksCount,
        'progressPercentage': progressPercentage,
        'focusActive': focusActive,
        'focusTitle': focusTitle ?? '',
        'focusRemainingSeconds': focusRemainingSeconds,
        'scheduleItems': scheduleItems.map((e) => e.toJson()).toList(),
        'unreadNotificationsCount': unreadNotificationsCount,
        'currentActivityTitle': currentActivityTitle ?? '',
        'currentActivityTime': currentActivityTime ?? '',
        'isActivityRunning': isActivityRunning,
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'lastUpdatedMillis': lastUpdatedMillis,
      };

  String serialize() => jsonEncode(toJson());

  factory WidgetData.fromJson(Map<String, dynamic> json) {
    final list = (json['scheduleItems'] as List<dynamic>?)
            ?.map((e) => WidgetScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final taskList = (json['tasks'] as List<dynamic>?)
            ?.map((e) => WidgetTaskItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final goalList = (json['goals'] as List<dynamic>?)
            ?.map((e) => WidgetGoalItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return WidgetData(
      currentTaskId: json['currentTaskId'] as String?,
      currentTaskTitle: json['currentTaskTitle'] as String?,
      currentTaskTime: json['currentTaskTime'] as String?,
      nextTaskId: json['nextTaskId'] as String?,
      nextTaskTitle: json['nextTaskTitle'] as String?,
      nextTaskTime: json['nextTaskTime'] as String?,
      completedTasksCount: (json['completedTasksCount'] as num?)?.toInt() ?? 0,
      totalTasksCount: (json['totalTasksCount'] as num?)?.toInt() ?? 0,
      progressPercentage: (json['progressPercentage'] as num?)?.toInt() ?? 0,
      focusActive: json['focusActive'] as bool? ?? false,
      focusTitle: json['focusTitle'] as String?,
      focusRemainingSeconds: (json['focusRemainingSeconds'] as num?)?.toInt() ?? 0,
      scheduleItems: list,
      unreadNotificationsCount: (json['unreadNotificationsCount'] as num?)?.toInt() ?? 0,
      currentActivityTitle: (json['currentActivityTitle'] as String?)?.takeIfNotEmpty,
      currentActivityTime: (json['currentActivityTime'] as String?)?.takeIfNotEmpty,
      isActivityRunning: json['isActivityRunning'] as bool? ?? false,
      tasks: taskList,
      goals: goalList,
      lastUpdatedMillis: (json['lastUpdatedMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

extension on String {
  String? get takeIfNotEmpty => trim().isNotEmpty ? this : null;
}
