import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models/ai_models.dart';
import '../../profile/presentation/providers/user_profile_provider.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../goals/presentation/providers/goal_provider.dart';
import '../../projects/presentation/providers/project_provider.dart';
import '../../schedule/data/repositories/schedule_repository.dart';

final aiPrivacyProvider = StateProvider<AIPrivacySettings>((ref) => AIPrivacySettings());

final aiContextBuilderProvider = Provider<AIContextBuilder>((ref) {
  return AIContextBuilder(ref);
});

class AIContextBuilder {
  final Ref _ref;

  AIContextBuilder(this._ref);

  Future<String> buildContext() async {
    final privacy = _ref.read(aiPrivacyProvider);
    if (!privacy.assistantEnabled) return '';

    final buffer = StringBuffer();
    final now = DateTime.now();
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEEE, MMMM d');

    buffer.writeln('=== USER PRODUCTIVITY CONTEXT ===');
    buffer.writeln('Current Date & Time: ${dateFormat.format(now)} at ${timeFormat.format(now)}');

    // 1. User Profile Context
    try {
      final profile = _ref.read(userProfileProvider);
      buffer.writeln('\nUser Profile:');
      buffer.writeln('- Name: ${profile.fullName}');
      buffer.writeln('- Work Hours: ${profile.workHoursStart.format} to ${profile.workHoursEnd.format}');
      buffer.writeln('- Daily Focus Target: ${profile.dailyGoalHours} hours');
      buffer.writeln('- Daily Task Target: ${profile.dailyTaskGoal} tasks');
      buffer.writeln('- Preferred Routine Style: ${profile.routinePreference}');
    } catch (_) {}

    // 2. Today Schedule Context
    try {
      final scheduleRepo = _ref.read(scheduleRepositoryProvider);
      final todayActivities = await scheduleRepo.getActivitiesForDate(DateTime(now.year, now.month, now.day));
      if (todayActivities.isNotEmpty) {
        buffer.writeln('\nToday\'s Scheduled Timeline:');
        for (var act in todayActivities) {
          buffer.writeln('- [${timeFormat.format(act.startTime)} - ${timeFormat.format(act.endTime)}] ${act.title} (Status: ${act.status.name})');
        }
      }
    } catch (_) {}

    // 3. Tasks Context
    if (privacy.allowTasks) {
      try {
        final tasks = await _ref.read(allTasksProvider.future);
        final pending = tasks.where((t) => !t.isCompleted).toList();
        final completed = tasks.where((t) => t.isCompleted).toList();

        buffer.writeln('\nPending Tasks (${pending.length}):');
        for (var t in pending.take(15)) {
          buffer.writeln('- [Priority: ${t.priority.name}] ${t.title}${t.dueDate != null ? ' (Due: ${DateFormat('MMM d').format(t.dueDate!)})' : ''}');
        }
        if (completed.isNotEmpty) {
          buffer.writeln('Recently Completed Tasks: ${completed.take(5).map((t) => t.title).join(', ')}');
        }
      } catch (_) {}
    }

    // 4. Goals Context
    if (privacy.allowGoals) {
      try {
        final goals = await _ref.read(allGoalsProvider.future);
        final activeGoals = goals.where((g) => g.status.name != 'completed').toList();
        if (activeGoals.isNotEmpty) {
          buffer.writeln('\nActive Goals (${activeGoals.length}):');
          for (var g in activeGoals.take(6)) {
            final targetStr = g.targetDate != null ? DateFormat('MMM d, y').format(g.targetDate!) : 'Ongoing';
            buffer.writeln('- ${g.title} (Progress: ${(g.manualProgress * 100).toInt()}%, Target: $targetStr)');
          }
        }
      } catch (_) {}
    }

    // 5. Projects Context
    try {
      final projects = await _ref.read(allProjectsProvider.future);
      final activeProjects = projects.where((p) => p.status.name == 'active').toList();
      if (activeProjects.isNotEmpty) {
        buffer.writeln('\nActive Projects (${activeProjects.length}):');
        for (var p in activeProjects.take(5)) {
          buffer.writeln('- ${p.title}: ${p.description}');
        }
      }
    } catch (_) {}

    buffer.writeln('\n================================');
    return buffer.toString();
  }
}
