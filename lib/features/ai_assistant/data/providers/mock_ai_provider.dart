import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'ai_provider.dart';
import '../models/ai_models.dart';

final aiProvider = Provider<AIProvider>((ref) {
  return MockAIProvider();
});

class MockAIProvider implements AIProvider {
  final _uuid = const Uuid();

  @override
  Future<AIMessage> generateResponse({
    required String prompt,
    required String contextContext,
    required List<AIMessage> history,
  }) async {
    // Simulate network/LLM generation time
    await Future.delayed(const Duration(seconds: 2));
    
    final lowerPrompt = prompt.toLowerCase();
    
    // Simulate "Plan Tomorrow" or "Plan Day"
    if (lowerPrompt.contains('plan tomorrow') || lowerPrompt.contains('plan my day')) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "Based on your current routine and available time, I've drafted a plan for tomorrow. I prioritized tasks with upcoming deadlines.",
        createdAt: DateTime.now(),
        actionPayload: AIActionPayload(
          summary: "I found 3 tasks that fit your available blocks. I've also scheduled a 25m focus session for your deep work.",
          confidence: "high",
          actions: [
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createFocusSession,
              data: {
                'title': 'Deep Work Block',
                'durationSeconds': 1500,
                'time': '09:00',
              },
            ),
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {
                'title': 'Review ML notes',
                'priority': 'high',
              },
            ),
          ],
        ),
      );
    }
    
    // Simulate simple question
    return AIMessage(
      id: _uuid.v4(),
      role: AIMessageRole.assistant,
      content: "I'm your AI productivity assistant. I can help you plan your day, break down projects, and review your progress. What would you like to focus on?",
      createdAt: DateTime.now(),
    );
  }
}
