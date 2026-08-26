import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/ai_models.dart';
import '../data/providers/mock_ai_provider.dart';
import 'ai_context_builder.dart';

import '../../tasks/presentation/providers/task_provider.dart';
import '../../tasks/data/models/task_model.dart';
import '../../tasks/data/repositories/task_repository.dart';

final aiMessagesProvider = StateNotifierProvider<AIMessagesNotifier, List<AIMessage>>((ref) {
  return AIMessagesNotifier(ref);
});

class AIMessagesNotifier extends StateNotifier<List<AIMessage>> {
  final Ref _ref;
  final _uuid = const Uuid();

  AIMessagesNotifier(this._ref) : super([]);

  Future<void> sendMessage(String text) async {
    final userMessage = AIMessage(
      id: _uuid.v4(),
      role: AIMessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );
    
    state = [...state, userMessage];

    try {
      final contextBuilder = _ref.read(aiContextBuilderProvider);
      final contextData = await contextBuilder.buildContext();
      
      final provider = _ref.read(aiProvider);
      final response = await provider.generateResponse(
        prompt: text,
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
          final repo = _ref.read(taskRepositoryProvider);
          await repo.createTask(TaskModel(
            id: _uuid.v4(),
            title: action.data['title'] ?? 'AI Task',
            priority: _parsePriority(action.data['priority']),
            createdAt: DateTime.now(),
          ));
          _ref.invalidate(allTasksProvider);
          break;
        case AIActionType.createFocusSession:
          // Simulate focus session creation (MVP)
          debugPrint('AI created focus session: ${action.data['title']}');
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
