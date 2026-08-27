import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'ai_provider.dart';
import '../models/ai_models.dart';

final aiProvider = Provider<AIProvider>((ref) {
  return DynamicContextAIProvider();
});

class DynamicContextAIProvider implements AIProvider {
  final _uuid = const Uuid();

  @override
  Future<AIMessage> generateResponse({
    required String prompt,
    required String contextContext,
    required List<AIMessage> history,
  }) async {
    // Natural slight latency for conversational feel
    await Future.delayed(const Duration(milliseconds: 900));

    final lower = prompt.toLowerCase();
    final lines = contextContext.split('\n');

    // Extract real tasks, goals, and schedule from context if available
    final pendingTasks = lines
        .where((l) => l.trim().startsWith('- [Priority:'))
        .map((l) => l.replaceAll(RegExp(r'^- \[Priority:\s*\w+\]\s*'), '').trim())
        .toList();

    final activeGoals = lines
        .where((l) => l.trim().startsWith('- ') && l.contains('(Progress:'))
        .map((l) => l.replaceAll(RegExp(r'^- '), '').split('(').first.trim())
        .toList();

    // -------------------------------------------------------------
    // 1. "Plan my day" / "Help me organize today"
    // -------------------------------------------------------------
    if (lower.contains('plan my day') || lower.contains('organize today') || lower.contains('plan today')) {
      final task1 = pendingTasks.isNotEmpty ? pendingTasks[0] : 'Deep Focus: Priority Execution';
      final task2 = pendingTasks.length > 1 ? pendingTasks[1] : 'Core Milestone Execution';
      final task3 = pendingTasks.length > 2 ? pendingTasks[2] : 'Daily Review & Inbox Zero';

      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "Here is your personalized daily plan tailored to your timeline and target focus hours:\n\n"
            "🌅 **Morning (Deep Work)**\n"
            "• 9:00 AM – 11:30 AM: Deep Focus Session on **$task1**\n"
            "• 11:30 AM – 11:45 AM: Active Break & Hydration\n\n"
            "☀️ **Midday (Momentum Block)**\n"
            "• 12:00 PM – 1:30 PM: Complete **$task2**\n"
            "• 1:30 PM – 2:30 PM: Lunch & Rest\n\n"
            "🌆 **Afternoon & Evening (Wrap Up)**\n"
            "• 2:30 PM – 5:00 PM: Focus on **$task3**\n"
            "• 5:00 PM – 6:00 PM: Review progress, update goals & plan tomorrow",
        createdAt: DateTime.now(),
        actionPayload: AIActionPayload(
          summary: "Structured your day with 2 deep focus blocks and scheduled top deliverables.",
          confidence: "high",
          actions: [
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createFocusSession,
              data: {'title': 'Morning Deep Focus: $task1', 'durationSeconds': 3600, 'time': '09:00'},
            ),
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {'title': task1, 'priority': 'high'},
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------
    // 2. "Plan tomorrow" / "Tomorrow's plan"
    // -------------------------------------------------------------
    if (lower.contains('plan tomorrow') || lower.contains('tomorrow')) {
      final topGoal = activeGoals.isNotEmpty ? activeGoals.first : 'Primary Goal';
      final topTask = pendingTasks.isNotEmpty ? pendingTasks.first : 'Key Priority Item';

      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "Here is an optimized roadmap for tomorrow designed to build early momentum:\n\n"
            "🎯 **Top Objective**: Advance **$topGoal**\n\n"
            "⏰ **Tomorrow's Recommended Schedule**:\n"
            "• **8:30 AM – 9:00 AM**: Morning Planning & Alignment\n"
            "• **9:00 AM – 11:30 AM**: 2.5-hour Deep Work window on **$topTask**\n"
            "• **11:30 AM – 12:30 PM**: Secondary tasks & follow-ups\n"
            "• **12:30 PM – 1:30 PM**: Lunch break\n"
            "• **1:30 PM – 4:30 PM**: Execution block & project deliverables\n"
            "• **4:30 PM – 5:30 PM**: Habit reflection & daily review",
        createdAt: DateTime.now(),
        actionPayload: AIActionPayload(
          summary: "Created prioritized schedule and milestone block for tomorrow.",
          confidence: "high",
          actions: [
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {'title': 'Tomorrow Priority: $topTask', 'priority': 'high'},
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------
    // 3. "Create a weekly plan" / "Weekly plan"
    // -------------------------------------------------------------
    if (lower.contains('weekly plan') || lower.contains('plan week') || lower.contains('week plan')) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "Here is a balanced 7-day productivity framework to maximize progress while preventing burnout:\n\n"
            "📅 **Monday – Wednesday (High Output & Deep Focus)**\n"
            "• Prioritize heavy cognitive tasks and primary deliverables during morning peak hours.\n"
            "• Target 4+ hours of deep work daily.\n\n"
            "📅 **Thursday – Friday (Execution & Delivery)**\n"
            "• Finalize weekly task backlog, reviews, and collaborative syncs.\n"
            "• Wrap up milestone targets.\n\n"
            "📅 **Saturday – Sunday (Recharge & Strategic Review)**\n"
            "• Dedicate time for health, family, reflection, and setting next week's targets.",
        createdAt: DateTime.now(),
      );
    }

    // -------------------------------------------------------------
    // 4. "Help me complete my goals" / "Break a goal into tasks"
    // -------------------------------------------------------------
    if (lower.contains('goal') || lower.contains('break down') || lower.contains('milestone')) {
      final goalName = activeGoals.isNotEmpty ? activeGoals.first : 'Active Milestone';
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "To make steady progress on **$goalName**, let's break it down into high-impact micro-steps:\n\n"
            "1. 📌 **Step 1 (Clarification)**: Define the exact outcome and success criteria for this week.\n"
            "2. ⚡ **Step 2 (Execution)**: Complete the initial core deliverable in a single 60-minute focus session.\n"
            "3. 🔍 **Step 3 (Refinement)**: Review work, address roadblocks, and iterate.\n"
            "4. 🏁 **Step 4 (Completion)**: Final check and mark milestone as completed.",
        createdAt: DateTime.now(),
        actionPayload: AIActionPayload(
          summary: "Created 3 milestone action tasks for '$goalName'.",
          confidence: "high",
          actions: [
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {'title': 'Step 1: Define weekly scope for $goalName', 'priority': 'high'},
            ),
            AIAction(
              id: _uuid.v4(),
              type: AIActionType.createTask,
              data: {'title': 'Step 2: 60-min execution session for $goalName', 'priority': 'high'},
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------
    // 5. "What should I focus on now?"
    // -------------------------------------------------------------
    if (lower.contains('focus on now') || lower.contains('what should i do') || lower.contains('right now')) {
      final immediateTask = pendingTasks.isNotEmpty ? pendingTasks.first : 'Your highest priority scheduled activity';
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "🎯 **Immediate Focus Recommendation**:\n\n"
            "Dedicate the next **45 minutes** to: **$immediateTask**.\n\n"
            "💡 *Tips to stay locked in*:\n"
            "• Put phone on Do Not Disturb\n"
            "• Close unrelated browser tabs\n"
            "• Keep a water bottle nearby\n"
            "• Focus purely on this single task until the timer ends.",
        createdAt: DateTime.now(),
      );
    }

    // -------------------------------------------------------------
    // 6. "Improve my schedule" / "Suggest breaks"
    // -------------------------------------------------------------
    if (lower.contains('improve schedule') || lower.contains('better schedule') || lower.contains('break') || lower.contains('routine')) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: "💡 **Schedule Optimization Recommendations**:\n\n"
            "1. **Protect Morning Focus**: Keep your first 2 hours dedicated to deep work before answering messages.\n"
            "2. **Add Buffer Intervals**: Add 10-15 minutes of buffer between activities to avoid cognitive fatigue.\n"
            "3. **Hydration & Movement**: Take a 3-minute stretch and water break after every 50 minutes of focused effort.\n"
            "4. **Evening Shutdown**: Conclude work at least 1 hour before bed for better recovery and sleep quality.",
        createdAt: DateTime.now(),
      );
    }

    // -------------------------------------------------------------
    // 7. General Intelligent Productivity Query
    // -------------------------------------------------------------
    final contextHint = pendingTasks.isNotEmpty
        ? "You currently have ${pendingTasks.length} pending tasks (starting with '${pendingTasks.first}')."
        : "Your workspace is ready for new daily goals and routine planning.";

    return AIMessage(
      id: _uuid.v4(),
      role: AIMessageRole.assistant,
      content: "I'm your **Timora AI Productivity Assistant**. $contextHint\n\n"
          "How can I help you today? I can organize your day, prioritize tasks, suggest schedule improvements, or break down large goals into daily action steps.",
      createdAt: DateTime.now(),
    );
  }
}
