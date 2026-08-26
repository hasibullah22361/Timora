import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ai_models.dart';
import '../../tasks/presentation/providers/task_provider.dart';
import '../../goals/presentation/providers/goal_provider.dart';

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
    buffer.writeln('Current Date: ${DateTime.now().toIso8601String()}');
    
    if (privacy.allowTasks) {
      final tasks = await _ref.read(allTasksProvider.future);
      buffer.writeln('Active Tasks:');
      for (var t in tasks.take(20)) { // Limit history context
        buffer.writeln('- [${t.status.name}] ${t.title} (Priority: ${t.priority.name})');
      }
    }

    if (privacy.allowGoals) {
      final goals = await _ref.read(allGoalsProvider.future);
      buffer.writeln('Active Goals:');
      for (var g in goals.take(5)) {
        buffer.writeln('- ${g.title} (Status: ${g.status.name}, Progress: ${(g.manualProgress * 100).toInt()}%)');
      }
    }

    // In a full implementation, we'd add routines, reviews, etc.
    return buffer.toString();
  }
}
