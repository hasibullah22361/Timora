import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/ai_assistant/services/ai_coach_service.dart';
import 'package:timora/features/analytics/data/models/productivity_score_model.dart';
import 'package:timora/features/diary/data/repositories/diary_repository.dart';

void main() {
  group('Phase 11 — AI Coach & Strategic Advisor Tests', () {
    test('COACH-1: Evaluates Burnout Risk when energy is depleted', () {
      final score = ProductivityScoreModel.calculate(
        taskCompletionRate: 0.9,
        focusMinutes: 120,
        habitCompletionRate: 0.9,
        routineAdherence: 0.9,
      );

      final moodSummary = MoodTrendSummary(
        averageMood: 3.0,
        averageEnergy: 2.0, // Low energy
        totalEntries: 5,
        recentEntries: const [],
      );

      final insight = AICoachService.evaluate(score: score, moodSummary: moodSummary);

      expect(insight.type, AICoachDiagnosticType.burnoutRisk);
      expect(insight.emoji, '🔋');
      expect(insight.title, contains('Energy Deficit'));
      expect(insight.recommendation, contains('recovery block'));
    });

    test('COACH-2: Evaluates Peak Flow State when productivity >= 85 and energy is healthy', () {
      final score = ProductivityScoreModel.calculate(
        taskCompletionRate: 0.95,
        focusMinutes: 100,
        habitCompletionRate: 0.9,
        routineAdherence: 0.9,
        activeStreakDays: 5,
      );

      final moodSummary = MoodTrendSummary(
        averageMood: 4.5,
        averageEnergy: 4.5,
        totalEntries: 7,
        recentEntries: const [],
      );

      final insight = AICoachService.evaluate(score: score, moodSummary: moodSummary);

      expect(insight.type, AICoachDiagnosticType.peakMomentum);
      expect(insight.emoji, '🔥');
      expect(insight.title, contains('Peak Flow State'));
    });

    test('COACH-3: Evaluates Focus Drift when focus score is under 50', () {
      final score = ProductivityScoreModel.calculate(
        taskCompletionRate: 0.8,
        focusMinutes: 20, // Low focus -> score < 50
        habitCompletionRate: 0.8,
        routineAdherence: 0.8,
      );

      final insight = AICoachService.evaluate(score: score);

      expect(insight.type, AICoachDiagnosticType.focusDrift);
      expect(insight.emoji, '🎯');
      expect(insight.recommendation, contains('Pomodoro'));
    });

    test('COACH-4: Evaluates Habit Breakdown when habit score is under 50', () {
      final score = ProductivityScoreModel.calculate(
        taskCompletionRate: 0.8,
        focusMinutes: 90,
        habitCompletionRate: 0.2, // Low habit rate -> score < 50
        routineAdherence: 0.8,
      );

      final insight = AICoachService.evaluate(score: score);

      expect(insight.type, AICoachDiagnosticType.habitBreakdown);
      expect(insight.emoji, '⚡');
      expect(insight.recommendation, contains('2-minute'));
    });
  });
}
