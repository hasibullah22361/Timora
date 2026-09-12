import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/ai_models.dart';
import '../data/providers/mock_ai_provider.dart';
import 'ai_context_builder.dart';

import '../../tasks/presentation/providers/task_provider.dart';
import '../../tasks/data/models/task_model.dart';
import '../../habits/presentation/providers/habit_provider.dart';
import '../../habits/data/models/habit_model.dart';
import '../../schedule/presentation/providers/schedule_provider.dart';
import '../../schedule/data/models/schedule_activity.dart';
import '../../focus/presentation/providers/focus_provider.dart';
import '../../focus/data/models/focus_session_model.dart';

final aiMessagesProvider = StateNotifierProvider<AIMessagesNotifier, List<AIMessage>>((ref) {
  return AIMessagesNotifier(ref);
});

class AIMessagesNotifier extends StateNotifier<List<AIMessage>> {
  final Ref _ref;
  final _uuid = const Uuid();
  bool _isGenerating = false;

  bool get isGenerating => _isGenerating;

  AIMessagesNotifier(this._ref) : super([]);

  Future<void> sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _isGenerating) return;
    _isGenerating = true;

    final userMessage = AIMessage(
      id: _uuid.v4(),
      role: AIMessageRole.user,
      content: cleanText,
      createdAt: DateTime.now(),
    );
    
    state = [...state, userMessage];

    try {
      final contextBuilder = _ref.read(aiContextBuilderProvider);
      final contextData = await contextBuilder.buildContext();
      
      final provider = _ref.read(aiProvider);
      final response = await provider.generateResponse(
        prompt: cleanText,
        contextContext: contextData,
        history: state,
      );

      state = [...state, response];
    } catch (e) {
      state = [
        ...state,
        AIMessage(
          id: _uuid.v4(),
          role: AIMessageRole.assistant,
          content: "Sorry, I couldn't process that right now. (Error: $e)",
          createdAt: DateTime.now(),
        )
      ];
    } finally {
      _isGenerating = false;
    }
  }

  void clearHistory() {
    state = [];
  }
}

// Service to execute AI Actions
final aiActionServiceProvider = Provider<AIActionService>((ref) => AIActionService(ref));

class AIActionService {
  final Ref _ref;
  final _uuid = const Uuid();

  AIActionService(this._ref);

  Future<void> applyActions(List<AIAction> actions) async {
    for (var action in actions) {
      switch (action.type) {
        case AIActionType.createTask:
          final task = TaskModel(
            id: _uuid.v4(),
            title: action.data['title'] ?? 'AI Task',
            priority: _parsePriority(action.data['priority']),
            category: action.data['category'] ?? 'General',
            estimatedDurationMinutes: action.data['durationMinutes'] as int? ?? 30,
            createdAt: DateTime.now(),
          );
          await _ref.read(taskNotifierProvider).createTask(task);
          break;

        case AIActionType.createHabit:
          final habit = HabitModel(
            id: _uuid.v4(),
            title: action.data['title'] ?? 'New Habit',
            icon: action.data['icon'] ?? '🔥',
            frequency: action.data['frequency'] ?? 'daily',
            createdAt: DateTime.now(),
          );
          await _ref.read(habitNotifierProvider).createHabit(habit);
          break;

        case AIActionType.scheduleActivity:
          final now = DateTime.now();
          final start = now.add(const Duration(minutes: 10));
          final durationMinutes = action.data['durationMinutes'] as int? ?? 45;
          final activity = ScheduleActivity(
            id: _uuid.v4(),
            title: action.data['title'] ?? 'Scheduled Activity',
            date: DateTime(now.year, now.month, now.day),
            startTime: start,
            endTime: start.add(Duration(minutes: durationMinutes)),
            category: action.data['category'] ?? 'Focus',
            icon: '⚡',
            createdAt: DateTime.now(),
          );
          await _ref.read(scheduleNotifierProvider).addActivity(activity);
          break;

        case AIActionType.createFocusSession:
          final duration = action.data['durationMinutes'] as int? ?? 25;
          await _ref.read(focusTimerProvider.notifier).startSession(
            durationMinutes: duration,
            mode: FocusSessionMode.pomodoro,
          );
          break;

        default:
          break;
      }
    }
  }

  TaskPriority _parsePriority(String? p) {
    if (p == 'high') return TaskPriority.high;
    if (p == 'low') return TaskPriority.low;
    if (p == 'urgent') return TaskPriority.urgent;
    return TaskPriority.medium;
  }
}
