import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/features/ai_assistant/services/ai_context_builder.dart';
import 'package:timora/features/ai_assistant/services/voice_input_service.dart';
import 'package:timora/features/ai_assistant/services/ai_coach_service.dart';
import 'package:timora/features/ai_assistant/services/ai_service.dart';
import 'package:timora/features/analytics/data/models/productivity_score_model.dart';
import 'package:timora/features/diary/data/repositories/diary_repository.dart';
import 'package:timora/features/daily_plan/data/repositories/daily_plan_repository.dart';
import 'package:timora/features/daily_plan/data/models/daily_plan_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Assistant Context Builder Tests', () {
    test('AIContextBuilder gathers comprehensive context including active plans', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final today = DateTime.now();
      final dailyRepo = container.read(dailyPlanRepositoryProvider);
      await dailyRepo.savePlan(DailyPlanModel(
        id: 'plan_today',
        date: DateTime(today.year, today.month, today.day),
        status: DailyPlanStatus.planned,
        plannedDurationSeconds: 7200,
        createdAt: today,
      ));

      final contextBuilder = container.read(aiContextBuilderProvider);
      final contextText = await contextBuilder.buildContext();

      expect(contextText.contains('USER PRODUCTIVITY CONTEXT'), isTrue);
      expect(contextText.contains('Today\'s Daily Plan'), isTrue);
      expect(contextText.contains('planned'), isTrue);
    });
  });

  group('Voice Input Routing Tests', () {
    test('Determines AI Assistant routing target for AI-prefixed queries', () {
      expect(VoiceInputService.determineTarget('Ask AI: Plan my morning around deep work'), VoiceRoutingTarget.aiAssistant);
      expect(VoiceInputService.determineTarget('ai suggest a focus strategy'), VoiceRoutingTarget.aiAssistant);
      expect(VoiceInputService.determineTarget('plan my day around high priority tasks'), VoiceRoutingTarget.aiAssistant);
      expect(VoiceInputService.determineTarget('what should i do next?'), VoiceRoutingTarget.aiAssistant);
      expect(VoiceInputService.determineTarget('coach me on productivity'), VoiceRoutingTarget.aiAssistant);
    });

    test('Determines Task routing target for actionable commands', () {
      expect(VoiceInputService.determineTarget('Urgent submit proposal today at 4pm'), VoiceRoutingTarget.task);
      expect(VoiceInputService.determineTarget('Buy groceries tonight at 7pm'), VoiceRoutingTarget.task);
      expect(VoiceInputService.determineTarget('Gym workout every Monday at 6am'), VoiceRoutingTarget.task);
    });
  });

  group('AI Coach Evaluation Tests', () {
    test('Burnout Risk is diagnosed when energy ratings are low', () {
      final score = ProductivityScoreModel(
        overallScore: 90,
        taskScore: 90,
        focusScore: 90,
        habitScore: 90,
        routineScore: 90,
        grade: 'A+',
        summary: 'High output',
      );

      final moodSummary = MoodTrendSummary(
        averageMood: 2.0,
        averageEnergy: 2.1,
        totalEntries: 5,
        recentEntries: [],
      );

      final insight = AICoachService.evaluate(score: score, moodSummary: moodSummary);
      expect(insight.type, AICoachDiagnosticType.burnoutRisk);
      expect(insight.emoji, '🔋');
      expect(insight.title, 'Energy Deficit Detected');
    });

    test('Peak Momentum is diagnosed for high productivity and healthy energy', () {
      final score = ProductivityScoreModel(
        overallScore: 88,
        taskScore: 90,
        focusScore: 85,
        habitScore: 90,
        routineScore: 85,
        grade: 'A',
        summary: 'Great momentum',
      );

      final moodSummary = MoodTrendSummary(
        averageMood: 4.5,
        averageEnergy: 4.2,
        totalEntries: 6,
        recentEntries: [],
      );

      final insight = AICoachService.evaluate(score: score, moodSummary: moodSummary);
      expect(insight.type, AICoachDiagnosticType.peakMomentum);
      expect(insight.emoji, '🔥');
    });
  });

  group('AI Messages Notifier State Tests', () {
    test('Messages can be sent and cleared', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(aiMessagesProvider.notifier);
      expect(container.read(aiMessagesProvider), isEmpty);

      await notifier.sendMessage('Hello Timora AI');
      final messages = container.read(aiMessagesProvider);
      expect(messages.length, greaterThanOrEqualTo(2));
      expect(messages.first.content, 'Hello Timora AI');

      notifier.clearHistory();
      expect(container.read(aiMessagesProvider), isEmpty);
    });
  });
}
