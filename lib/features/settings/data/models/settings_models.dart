import 'package:flutter/material.dart';

enum TimoraWeekStart { monday, sunday }
enum ArchiveDuration { never, days7, days30, days90 }
enum TaskPriorityLevel { low, medium, high }
enum AutopilotMode { off, assisted, fullAutopilot }

enum DashboardWidgetType {
  todayPlan,
  dailyReview,
  todayTasks,
  focusTimer,
  projects,
  goals,
  analyticsSnapshot,
  streaks,
  thisWeek,
  thisMonth,
}

class AppSettings {
  // Appearance
  final ThemeMode themeMode;
  final bool reduceMotion;
  
  // Schedule
  final TimoraWeekStart weekStart;
  final String wakeTime; // "07:00"
  final String sleepTime; // "23:00"
  
  // Planning
  final bool autoPlanEnabled;
  final int planningBufferPercentage;
  final bool allowWeekendPlanning;
  final bool protectPersonalTime;
  
  // Focus
  final int defaultFocusSeconds;
  final int shortBreakSeconds;
  final int longBreakSeconds;
  final bool autoStartBreak;
  final bool autoStartFocus;
  final bool focusSoundEnabled;
  final bool keepScreenAwake;
  
  // Tasks
  final TaskPriorityLevel defaultTaskPriority;
  final int defaultTaskDurationSeconds;
  final bool confirmTaskDeletion;
  final bool showCompletedTasks;
  final ArchiveDuration autoArchiveCompletedTasks;
  
  // Notifications
  final bool notificationsEnabled;
  final bool quietHoursEnabled;
  final String quietHoursStart; // "22:00"
  final String quietHoursEnd;   // "08:00"
  
  // Reviews
  final bool dailyReviewReminder;
  final bool weeklyReviewReminder;
  final bool monthlyReviewReminder;
  
  // Streaks
  final bool automaticStreakFreeze;
  final bool streakReminders;
  
  // Dashboard
  final List<DashboardWidgetType> dashboardOrder;
  final Map<DashboardWidgetType, bool> dashboardVisibility;

  // Autopilot
  final AutopilotMode autopilotMode;

  AppSettings({
    this.themeMode = ThemeMode.system,
    this.reduceMotion = false,
    this.weekStart = TimoraWeekStart.monday,
    this.wakeTime = "07:00",
    this.sleepTime = "23:00",
    this.autoPlanEnabled = true,
    this.planningBufferPercentage = 20,
    this.allowWeekendPlanning = false,
    this.protectPersonalTime = true,
    this.defaultFocusSeconds = 1500, // 25 mins
    this.shortBreakSeconds = 300,    // 5 mins
    this.longBreakSeconds = 900,     // 15 mins
    this.autoStartBreak = false,
    this.autoStartFocus = false,
    this.focusSoundEnabled = true,
    this.keepScreenAwake = true,
    this.defaultTaskPriority = TaskPriorityLevel.medium,
    this.defaultTaskDurationSeconds = 1800, // 30 mins
    this.confirmTaskDeletion = true,
    this.showCompletedTasks = true,
    this.autoArchiveCompletedTasks = ArchiveDuration.days30,
    this.notificationsEnabled = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = "22:00",
    this.quietHoursEnd = "08:00",
    this.dailyReviewReminder = true,
    this.weeklyReviewReminder = true,
    this.monthlyReviewReminder = true,
    this.automaticStreakFreeze = false,
    this.streakReminders = true,
    this.autopilotMode = AutopilotMode.assisted,
    this.dashboardOrder = const [
      DashboardWidgetType.todayPlan,
      DashboardWidgetType.dailyReview,
      DashboardWidgetType.todayTasks,
      DashboardWidgetType.focusTimer,
      DashboardWidgetType.analyticsSnapshot,
      DashboardWidgetType.streaks,
      DashboardWidgetType.projects,
      DashboardWidgetType.goals,
      DashboardWidgetType.thisWeek,
      DashboardWidgetType.thisMonth,
    ],
    this.dashboardVisibility = const {
      DashboardWidgetType.todayPlan: true,
      DashboardWidgetType.dailyReview: true,
      DashboardWidgetType.todayTasks: true,
      DashboardWidgetType.focusTimer: true,
      DashboardWidgetType.analyticsSnapshot: true,
      DashboardWidgetType.streaks: true,
      DashboardWidgetType.projects: true,
      DashboardWidgetType.goals: true,
      DashboardWidgetType.thisWeek: true,
      DashboardWidgetType.thisMonth: true,
    },
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? reduceMotion,
    TimoraWeekStart? weekStart,
    String? wakeTime,
    String? sleepTime,
    bool? autoPlanEnabled,
    int? planningBufferPercentage,
    bool? allowWeekendPlanning,
    bool? protectPersonalTime,
    int? defaultFocusSeconds,
    int? shortBreakSeconds,
    int? longBreakSeconds,
    bool? autoStartBreak,
    bool? autoStartFocus,
    bool? focusSoundEnabled,
    bool? keepScreenAwake,
    TaskPriorityLevel? defaultTaskPriority,
    int? defaultTaskDurationSeconds,
    bool? confirmTaskDeletion,
    bool? showCompletedTasks,
    ArchiveDuration? autoArchiveCompletedTasks,
    bool? notificationsEnabled,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? dailyReviewReminder,
    bool? weeklyReviewReminder,
    bool? monthlyReviewReminder,
    bool? automaticStreakFreeze,
    bool? streakReminders,
    AutopilotMode? autopilotMode,
    List<DashboardWidgetType>? dashboardOrder,
    Map<DashboardWidgetType, bool>? dashboardVisibility,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      weekStart: weekStart ?? this.weekStart,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      autoPlanEnabled: autoPlanEnabled ?? this.autoPlanEnabled,
      planningBufferPercentage: planningBufferPercentage ?? this.planningBufferPercentage,
      allowWeekendPlanning: allowWeekendPlanning ?? this.allowWeekendPlanning,
      protectPersonalTime: protectPersonalTime ?? this.protectPersonalTime,
      defaultFocusSeconds: defaultFocusSeconds ?? this.defaultFocusSeconds,
      shortBreakSeconds: shortBreakSeconds ?? this.shortBreakSeconds,
      longBreakSeconds: longBreakSeconds ?? this.longBreakSeconds,
      autoStartBreak: autoStartBreak ?? this.autoStartBreak,
      autoStartFocus: autoStartFocus ?? this.autoStartFocus,
      focusSoundEnabled: focusSoundEnabled ?? this.focusSoundEnabled,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      defaultTaskPriority: defaultTaskPriority ?? this.defaultTaskPriority,
      defaultTaskDurationSeconds: defaultTaskDurationSeconds ?? this.defaultTaskDurationSeconds,
      confirmTaskDeletion: confirmTaskDeletion ?? this.confirmTaskDeletion,
      showCompletedTasks: showCompletedTasks ?? this.showCompletedTasks,
      autoArchiveCompletedTasks: autoArchiveCompletedTasks ?? this.autoArchiveCompletedTasks,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      dailyReviewReminder: dailyReviewReminder ?? this.dailyReviewReminder,
      weeklyReviewReminder: weeklyReviewReminder ?? this.weeklyReviewReminder,
      monthlyReviewReminder: monthlyReviewReminder ?? this.monthlyReviewReminder,
      automaticStreakFreeze: automaticStreakFreeze ?? this.automaticStreakFreeze,
      streakReminders: streakReminders ?? this.streakReminders,
      autopilotMode: autopilotMode ?? this.autopilotMode,
      dashboardOrder: dashboardOrder ?? this.dashboardOrder,
      dashboardVisibility: dashboardVisibility ?? this.dashboardVisibility,
    );
  }

  // Very basic JSON serialization for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'reduceMotion': reduceMotion,
      'weekStart': weekStart.index,
      'planningBufferPercentage': planningBufferPercentage,
      'defaultFocusSeconds': defaultFocusSeconds,
      'autopilotMode': autopilotMode.index,
      'dashboardOrder': dashboardOrder.map((e) => e.index).toList(),
      // Add other fields as necessary for complete serialization...
      // For MVP Settings we will store the critical ones that we're actively demonstrating.
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    try {
      return AppSettings(
        themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
        reduceMotion: json['reduceMotion'] as bool? ?? false,
        weekStart: TimoraWeekStart.values[json['weekStart'] as int? ?? 0],
        planningBufferPercentage: json['planningBufferPercentage'] as int? ?? 20,
        defaultFocusSeconds: json['defaultFocusSeconds'] as int? ?? 1500,
        autopilotMode: json['autopilotMode'] != null
            ? AutopilotMode.values[(json['autopilotMode'] as int).clamp(0, AutopilotMode.values.length - 1)]
            : AutopilotMode.assisted,
        dashboardOrder: (json['dashboardOrder'] as List<dynamic>?)
            ?.map((e) => DashboardWidgetType.values[e as int])
            .toList() ?? AppSettings().dashboardOrder,
      );
    } catch (_) {
      return AppSettings();
    }
  }
}
