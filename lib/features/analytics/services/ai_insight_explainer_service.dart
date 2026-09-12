import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai_assistant/data/providers/mock_ai_provider.dart';
import '../data/models/analytics_models.dart';

final aiInsightExplainerServiceProvider = Provider<AIInsightExplainerService>((ref) {
  return AIInsightExplainerService(ref);
});

class AIInsightExplainerService {
  final Ref _ref;

  AIInsightExplainerService(this._ref);

  /// Enhances an AnalyticsInsight with AI interpretation while strictly preserving
  /// factual integrity from Timora data.
  Future<AnalyticsInsight> enrichInsightWithAI(AnalyticsInsight insight) async {
    // If insight has insufficient data, do not call AI to invent anything
    if (!insight.hasSufficientData) {
      return insight;
    }

    try {
      final ai = _ref.read(aiProvider);

      final prompt = '''
You are Timora's intelligent productivity analytics interpreter.
Explain the following verified user productivity metric in simple, motivating language.
DO NOT invent any new numbers, percentages, task names, streaks, or completion hours.
Use ONLY the factual values provided below.

Title: ${insight.title}
Factual Finding: ${insight.description}
Category: ${insight.category.name}
Current Recommendation: ${insight.recommendation}

Please provide:
1. A 1-2 sentence clear explanation answering "What does this data mean?"
2. A 1 sentence concrete action answering "What should I do differently?"
Format your response as:
EXPLANATION: <your explanation>
RECOMMENDATION: <your recommendation>
''';

      final response = await ai.generateResponse(
        prompt: prompt,
        contextContext: 'Timora Analytics Engine — Factual Metrics Only',
        history: [],
      );

      final content = response.content;
      String? aiExplanation;
      String? aiRecommendation;

      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.toUpperCase().startsWith('EXPLANATION:')) {
          aiExplanation = trimmed.substring('EXPLANATION:'.length).trim();
        } else if (trimmed.toUpperCase().startsWith('RECOMMENDATION:')) {
          aiRecommendation = trimmed.substring('RECOMMENDATION:'.length).trim();
        }
      }

      if (aiExplanation != null && aiExplanation.isNotEmpty) {
        return AnalyticsInsight(
          id: insight.id,
          type: insight.type,
          title: insight.title,
          description: insight.description,
          explanation: aiExplanation,
          recommendation: (aiRecommendation != null && aiRecommendation.isNotEmpty)
              ? aiRecommendation
              : insight.recommendation,
          category: insight.category,
          impact: insight.impact,
          actionType: insight.actionType,
          actionLabel: insight.actionLabel,
          actionData: insight.actionData,
          confidence: insight.confidence,
          hasSufficientData: insight.hasSufficientData,
          icon: insight.icon,
          createdAt: insight.createdAt,
        );
      }
    } catch (_) {
      // Offline fallback: gracefully retain the deterministic, verified interpretation
    }

    return insight;
  }
}
