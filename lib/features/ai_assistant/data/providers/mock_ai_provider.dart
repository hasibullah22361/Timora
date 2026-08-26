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
    // Simulate natural response latency
    await Future.delayed(const Duration(milliseconds: 1200));
    
    final lower = prompt.toLowerCase();
    
    // 1. Plan my day / Plan tomorrow
    if (lower.contains('plan my day') || lower.contains('plan tomorrow') || lower.contains('tomorrow\'s plan')) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "I've analyzed your schedule and active goals. Here is an optimized plan that pairs your highest priority tasks with dedicated focus blocks during your peak productivity hours.",
        createdAt: DateTime.now(),
        actionPayload: AIActionPayload(
          summary: "Scheduled 2 deep focus blocks and prioritized 2 key deliverables for your day.",
          confidence: "high",
          actions: [
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createFocusSession,
              data: {
                'title': 'Morning Deep Work: Priority Execution',
                'durationSeconds': 3000,
                'time': '09:00',
              },
            ),
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {
                'title': 'Finalize core project milestone',
                'priority': 'high',
              },
            ),
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {
                'title': 'Review weekly progress and clear inbox',
                'priority': 'medium',
              },
            ),
          ],
        ),
      );
    }
    
    // 2. Create a routine
    if (lower.contains('create a routine') || lower.contains('routine')) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "Here is a high-performance daily routine recommendation designed for maximum sustained energy, deep work, and evening recovery:\n\n• **7:30 AM – 8:30 AM**: Morning Routine & Nutritious Breakfast\n• **8:30 AM – 12:30 PM**: Deep Focus Block 1 (High cognitive demand)\n• **12:30 PM – 1:30 PM**: Lunch & Walk\n• **1:30 PM – 5:30 PM**: Deep Focus Block 2 (Execution & Collaboration)\n• **5:30 PM – 7:00 PM**: Exercise & Wellbeing\n• **7:00 PM – 8:30 PM**: Dinner & Relaxation\n• **8:30 PM – 10:30 PM**: Reading & Skill Learning\n• **10:30 PM – 11:30 PM**: Daily Review & Tomorrow's Plan",
        createdAt: DateTime.now(),
      );
    }

    // 3. Break goal into tasks
    if (lower.contains('break a goal') || lower.contains('break goal') || lower.contains('goal into tasks')) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "I've structured a 4-step action plan to break down your main goal into manageable, actionable steps:",
        createdAt: DateTime.now(),
        actionPayload: AIActionPayload(
          summary: "Created 3 sequential milestone tasks to build momentum towards your goal.",
          confidence: "high",
          actions: [
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {
                'title': 'Phase 1: Define project scope & gather resources',
                'priority': 'high',
              },
            ),
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {
                'title': 'Phase 2: Build working prototype / initial draft',
                'priority': 'high',
              },
            ),
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {
                'title': 'Phase 3: Review feedback & finalize delivery',
                'priority': 'medium',
              },
            ),
          ],
        ),
      );
    }

    // 4. Prioritize tasks
    if (lower.contains('prioritize') || lower.contains('priority')) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "Using the Eisenhower Matrix principle, I suggest prioritizing your tasks as follows:\n\n1. 🔥 **Urgent & High Impact**: Complete pending milestone deliverables.\n2. 📈 **High Impact & Scheduled**: 90-minute Deep Focus block.\n3. 📝 **Maintenance**: Inbox clearance and workspace organizing.\n\nFocus on finishing the top task before switching contexts.",
        createdAt: DateTime.now(),
      );
    }

    // 5. Analyze productivity
    if (lower.contains('analyze') || lower.contains('productivity')) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "📊 **Productivity Insights**:\n\n• **Focus Consistency**: High morning focus output between 9 AM - 12 PM.\n• **Task Completion Rate**: Solid momentum with positive streak.\n• **Recommendation**: Protect your morning 90-minute focus window from minor administrative tasks to maintain peak creative flow.",
        createdAt: DateTime.now(),
      );
    }

    // 6. Suggest breaks / Better schedule
    if (lower.contains('suggest break') || lower.contains('breaks') || lower.contains('suggest a better schedule')) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "💡 **Schedule Optimization Tip**:\n\n• Insert a 10-minute screen-free break after every 50 minutes of deep work.\n• Hydrate and do a quick 3-minute posture stretch between afternoon blocks.\n• Keep 30 minutes of open buffer time before dinner to avoid cognitive overload.",
        createdAt: DateTime.now(),
      );
    }

    // Default friendly conversational response
    return AIMessage(
      id: _uuid.v4(),
      role: AIMessageRole.assistant,
      content: "I'm your Timora AI Productivity Assistant. I can help you plan your day, optimize your routine, prioritize tasks, and breakdown large goals into daily actions. What would you like to achieve today?",
      createdAt: DateTime.now(),
    );
  }
}

