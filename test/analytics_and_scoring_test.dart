import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/analytics/data/models/productivity_score_model.dart';
import 'package:timora/features/analytics/data/models/analytics_models.dart';

void main() {
  group('Phase 7 — Advanced Analytics & Productivity Scoring Tests', () {
    test('SCORE-1: 100% completion and focus produces A+ score', () {
      final score = ProductivityScoreModel.calculate(
        taskCompletionRate: 1.0,
        focusMinutes: 120, // > 90m
        habitCompletionRate: 1.0,
        routineAdherence: 1.0,
        activeStreakDays: 5,
      );

      expect(score.overallScore, 100);
      expect(score.grade, 'A+');
      expect(score.taskScore, 100);
      expect(score.focusScore, 100);
      expect(score.habitScore, 100);
      expect(score.routineScore, 100);
      expect(score.streakBonus, 5);
      expect(score.summary, contains('Peak Performance'));
    });

    test('SCORE-2: Partial metrics produce balanced B grade', () {
      final score = ProductivityScoreModel.calculate(
        taskCompletionRate: 0.7,  // 70 * 0.35 = 24.5
        focusMinutes: 60,         // (60/90)*100 = 66.6 -> 67 * 0.30 = 20.1
        habitCompletionRate: 0.8, // 80 * 0.20 = 16.0
        routineAdherence: 0.7,    // 70 * 0.15 = 10.5
        activeStreakDays: 3,      // +3
      );                          // Total ~ 74

      expect(score.overallScore, inInclusiveRange(70, 78));
      expect(score.grade, 'B');
      expect(score.summary, contains('Solid Rhythm'));
    });

    test('SCORE-3: Zero activity produces Grade D', () {
      final score = ProductivityScoreModel.calculate(
        taskCompletionRate: 0.0,
        focusMinutes: 0,
        habitCompletionRate: 0.0,
        routineAdherence: 0.0,
        activeStreakDays: 0,
      );

      expect(score.overallScore, 0);
      expect(score.grade, 'D');
      expect(score.summary, contains('Reset & Refocus'));
    });

    test('PERIOD-1: AnalyticsPeriod labels are clear and formatted', () {
      expect(AnalyticsPeriod.today.label, 'Today');
      expect(AnalyticsPeriod.last7Days.label, 'Last 7 Days');
      expect(AnalyticsPeriod.thisWeek.label, 'This Week');
      expect(AnalyticsPeriod.last30Days.label, 'Last 30 Days');
    });
  });
}
