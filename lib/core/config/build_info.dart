/// Centralized Build & Feature Metadata for Timora.
///
/// Used by About Dialogs, System Diagnostics, and Feature Audit screens to
/// safely determine and verify the exact build installed on the device.
class BuildInfo {
  static const String appName = 'Timora';
  static const String version = '1.1.0';
  static const String buildNumber = '2';
  static const String featureBuildDate = '2026-09-11';
  static const String buildChannel = 'Production / Release Verified';

  static String get fullVersionString => 'v$version ($buildNumber) • $featureBuildDate';

  static const List<Map<String, String>> verifiedFeatures = [
    {
      'name': 'AI Daily Recap',
      'category': 'AI & Intelligence',
      'dataSource': 'Real Tasks, Schedule, Focus, Hive, Diary',
      'route': 'Others → AI Daily Recap',
      'status': 'Available & Verified',
    },
    {
      'name': 'AI Weekly & Monthly Recap',
      'category': 'AI & Intelligence',
      'dataSource': 'Real Tasks, Schedule, Focus, Hive, Diary',
      'route': 'Others → AI Daily Recap (Weekly/Monthly Tabs)',
      'status': 'Available & Verified',
    },
    {
      'name': 'Recap History Archive',
      'category': 'AI & Intelligence',
      'dataSource': 'SharedPreferences / Hive (timora_recaps_data)',
      'route': 'Others → Recap History',
      'status': 'Available & Verified',
    },
    {
      'name': 'Spoken Recap TTS Announcements',
      'category': 'Communication & Voice',
      'dataSource': 'Native Android TextToSpeech & Foreground Service',
      'route': 'Settings → Notifications → Spoken Recap',
      'status': 'Available & Verified',
    },
    {
      'name': 'Automatic Diary Recap Integration',
      'category': 'Personal & Reflection',
      'dataSource': 'DiaryRepository (Deterministic Idempotent IDs)',
      'route': 'Others → Timora Diary',
      'status': 'Available & Verified',
    },
    {
      'name': 'Custom Recap Scheduling',
      'category': 'AI & Intelligence',
      'dataSource': 'NotificationSettingsRepository & Android AlarmManager',
      'route': 'Settings → Notifications → AI Recap Scheduling',
      'status': 'Available & Verified',
    },
    {
      'name': 'Clock Hub (Alarm, World, Stopwatch, Timer)',
      'category': 'Planning & Tools',
      'dataSource': 'Hive, SharedPreferences, AlarmManager',
      'route': 'Others → Clock',
      'status': 'Available & Verified',
    },
    {
      'name': 'Smart Unified Planner',
      'category': 'Planning & Time',
      'dataSource': 'ScheduleRepository & TaskRepository',
      'route': 'Others → Planner',
      'status': 'Available & Verified',
    },
    {
      'name': 'AI Morning Brief',
      'category': 'AI & Intelligence',
      'dataSource': 'Daily Schedule, Tasks, Gemini AI / Offline synthesis',
      'route': 'Others → Morning Brief / Home Pill',
      'status': 'Available & Verified',
    },
    {
      'name': 'AI Daily Debrief',
      'category': 'AI & Intelligence',
      'dataSource': 'Today Metrics, User Reflection, Diary Entry',
      'route': 'Others → Daily Debrief / Home Pill',
      'status': 'Available & Verified',
    },
    {
      'name': 'Timora AI Assistant',
      'category': 'AI & Intelligence',
      'dataSource': 'Gemini 2.5 Flash / Context Builder',
      'route': 'Others → AI Assistant / Home FAB',
      'status': 'Available & Verified',
    },
    {
      'name': 'AI Privacy & Context Permissions',
      'category': 'AI & Intelligence',
      'dataSource': 'SharedPreferences (ai_privacy_settings)',
      'route': 'Others → AI Privacy / Settings',
      'status': 'Available & Verified',
    },
    {
      'name': 'Focus & Pomodoro Timer',
      'category': 'Productivity & Focus',
      'dataSource': 'FocusSessionRepository & Hive',
      'route': 'Others → Focus / Pomodoro',
      'status': 'Available & Verified',
    },
    {
      'name': 'Focus History & Volume Stats',
      'category': 'Analytics & Reviews',
      'dataSource': 'Hive (allFocusSessionsProvider)',
      'route': 'Others → Focus History',
      'status': 'Available & Verified',
    },
    {
      'name': 'Reviews & Reflection Wizard',
      'category': 'Analytics & Reviews',
      'dataSource': 'ReviewRepository & Hive',
      'route': 'Others → Reviews & Reflection',
      'status': 'Available & Verified',
    },
    {
      'name': 'Productivity Analysis & Scoring',
      'category': 'Analytics & Reviews',
      'dataSource': 'ProductivityEventRepository',
      'route': 'Others → Productivity Analysis',
      'status': 'Available & Verified',
    },
    {
      'name': 'Comprehensive Reports',
      'category': 'Analytics & Reviews',
      'dataSource': 'AnalyticsRepository & Chart Models',
      'route': 'Others → Comprehensive Reports',
      'status': 'Available & Verified',
    },
    {
      'name': 'Habits & Consistency Tracking',
      'category': 'Personal & Growth',
      'dataSource': 'HabitsRepository & Hive',
      'route': 'Others → Habits & Consistency',
      'status': 'Available & Verified',
    },
    {
      'name': 'Streaks & Consistency Heatmap',
      'category': 'Analytics & Reviews',
      'dataSource': 'StreaksRepository',
      'route': 'Others → Streaks & Consistency',
      'status': 'Available & Verified',
    },
    {
      'name': 'Ambient Nature Soundscapes',
      'category': 'Personal & Audio',
      'dataSource': '12 Nature Soundscapes & Just Audio',
      'route': 'Others → Ambient Environment Sounds',
      'status': 'Available & Verified',
    },
    {
      'name': 'Timora Diary & Journal',
      'category': 'Personal & Reflection',
      'dataSource': 'DiaryRepository & Supabase',
      'route': 'Others → Timora Diary',
      'status': 'Available & Verified',
    },
    {
      'name': 'Career Roadmap & Skill Pathway',
      'category': 'Personal & Growth',
      'dataSource': 'CareerMilestonesRepository',
      'route': 'Others → Career Roadmap',
      'status': 'Available & Verified',
    },
    {
      'name': 'Career Document Vault',
      'category': 'Personal & Growth',
      'dataSource': 'Supabase Storage / Local Document Vault',
      'route': 'Others → Career Document Vault',
      'status': 'Available & Verified',
    },
    {
      'name': 'Projects & Milestones',
      'category': 'Planning & Time',
      'dataSource': 'ProjectRepository',
      'route': 'Others → Projects',
      'status': 'Available & Verified',
    },
    {
      'name': 'Goals & Targets',
      'category': 'Planning & Time',
      'dataSource': 'GoalRepository',
      'route': 'Others → Goals',
      'status': 'Available & Verified',
    },
    {
      'name': 'Daily Agenda Plan',
      'category': 'Planning & Time',
      'dataSource': 'ScheduleRepository',
      'route': 'Others → Daily Plan Agenda',
      'status': 'Available & Verified',
    },
    {
      'name': 'Weekly Agenda Plan',
      'category': 'Planning & Time',
      'dataSource': 'ScheduleRepository',
      'route': 'Others → Weekly Plan Agenda',
      'status': 'Available & Verified',
    },
    {
      'name': 'Monthly Agenda Plan',
      'category': 'Planning & Time',
      'dataSource': 'ScheduleRepository',
      'route': 'Others → Monthly Plan Agenda',
      'status': 'Available & Verified',
    },
    {
      'name': 'Routine Templates',
      'category': 'Planning & Time',
      'dataSource': 'Built-in Routine Templates Library',
      'route': 'Others → Routine Templates',
      'status': 'Available & Verified',
    },
    {
      'name': 'Notifications Center',
      'category': 'Communication & System',
      'dataSource': 'In-App Notification Engine with Swipe Delete',
      'route': 'Others → Notifications Center / Home Icon',
      'status': 'Available & Verified',
    },
    {
      'name': 'Cloud Backup & Sync',
      'category': 'Communication & System',
      'dataSource': 'Supabase Cloud Sync Engine',
      'route': 'Others → Cloud Account & Sync',
      'status': 'Available & Verified',
    },
    {
      'name': 'Data Privacy, Export & Import',
      'category': 'Communication & System',
      'dataSource': 'File Picker / Local JSON Export',
      'route': 'Others → Data Privacy & Backup',
      'status': 'Available & Verified',
    },
  ];
}
