import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../analytics/data/models/productivity_score_model.dart';
import '../../analytics/services/analytics_service.dart';
import '../../analytics/data/models/analytics_models.dart';
import '../../diary/presentation/providers/diary_provider.dart';
import '../../diary/data/repositories/diary_repository.dart';

enum AICoachDiagnosticType {
  peakMomentum,
  burnoutRisk,
  focusDrift,
  habitBreakdown,
  steadyRhythm,
}

class AICoachInsight {
  final AICoachDiagnosticType type;
  final String emoji;
  final String title;
  final String diagnosis;
  final String recommendation;
  final String actionPrompt;

  AICoachInsight({
    required this.type,
    required this.emoji,
    required this.title,
    required this.diagnosis,
    required this.recommendation,
    required this.actionPrompt,
  });
}

final aiCoachServiceProvider = Provider<AICoachService>((ref) {
  return AICoachService(ref);
});

final aiCoachInsightProvider = FutureProvider<AICoachInsight>((ref) async {
  final coach = ref.watch(aiCoachServiceProvider);
  return coach.generateCoachingInsight();
});

class AICoachService {
  final Ref _ref;

  AICoachService(this._ref);

  Future<AICoachInsight> generateCoachingInsight() async {
    final analytics = _ref.read(analyticsServiceProvider);
    final score = await analytics.getProductivityScore(AnalyticsPeriod.last7Days);
    
    MoodTrendSummary? moodSummary;
    try {
      moodSummary = await _ref.read(moodTrendsProvider(7).future);
    } catch (_) {}

    return evaluate(score: score, moodSummary: moodSummary);
  }

  static AICoachInsight evaluate({
    required ProductivityScoreModel score,
    MoodTrendSummary? moodSummary,
  }) {
    final avgMood = moodSummary?.averageMood ?? 3.5;
    final avgEnergy = moodSummary?.averageEnergy ?? 3.5;

    // 1. Burnout Risk: High productivity with depleted mood or energy
    if (avgEnergy < 2.5 || avgMood < 2.5 || (score.overallScore > 85 && avgEnergy < 3.0)) {
      return AICoachInsight(
        type: AICoachDiagnosticType.burnoutRisk,
        emoji: '🔋',
        title: 'Energy Deficit Detected',
        diagnosis: 'Your output is demanding high cognitive effort while your energy ratings are dipping (${avgEnergy.toStringAsFixed(1)}/5.0).',
        recommendation: 'Schedule a 90-minute recovery block today with no screens. Prioritize restorative sleep and lighten your afternoon task load.',
        actionPrompt: 'Suggest a lighter, restorative schedule for today',
      );
    }

    // 2. Peak Momentum: Score >= 85 and Good Energy
    if (score.overallScore >= 85) {
      return AICoachInsight(
        type: AICoachDiagnosticType.peakMomentum,
        emoji: '🔥',
        title: 'Peak Flow State Unlocked',
        diagnosis: 'You are operating at high leverage with an ${score.overallScore}% productivity grade and strong task execution.',
        recommendation: 'Capitalize on this momentum to tackle your highest-friction milestone or long-term strategic project during your morning focus window.',
        actionPrompt: 'Help me break down my highest-priority goal for today',
      );
    }

    // 3. Focus Drift: Focus score < 50
    if (score.focusScore < 50) {
      return AICoachInsight(
        type: AICoachDiagnosticType.focusDrift,
        emoji: '🎯',
        title: 'Re-anchor Deep Focus Blocks',
        diagnosis: 'You logged fewer focus minutes than your weekly target (${score.focusScore}% focus score).',
        recommendation: 'Block a single 45-minute distraction-free Pomodoro session before checking incoming messages tomorrow morning.',
        actionPrompt: 'Plan a 45-minute deep focus sprint for tomorrow',
      );
    }

    // 4. Habit Breakdown: Habit score < 50
    if (score.habitScore < 50) {
      return AICoachInsight(
        type: AICoachDiagnosticType.habitBreakdown,
        emoji: '⚡',
        title: 'Habit Consistency Reset',
        diagnosis: 'Your habit streaks need replenishment (${score.habitScore}% consistency rate).',
        recommendation: 'Shrink your key habit down to a 2-minute version to remove friction and rebuild your daily streak.',
        actionPrompt: 'How can I simplify my daily habits to stay consistent?',
      );
    }

    // 5. Steady Rhythm
    return AICoachInsight(
      type: AICoachDiagnosticType.steadyRhythm,
      emoji: '🚀',
      title: 'Steady Rhythm & Alignment',
      diagnosis: 'You maintain a balanced ${score.overallScore}% score with healthy task completion and regular focus intervals.',
      recommendation: 'Maintain this pace. Set your top 3 priority tasks for tomorrow before winding down this evening.',
      actionPrompt: 'Plan tomorrow with 3 clear priorities',
    );
  }
}
