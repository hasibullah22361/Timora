class ProductivityScoreModel {
  final int overallScore; // 0 - 100
  final int taskScore;    // 0 - 100 (weight: 35%)
  final int focusScore;   // 0 - 100 (weight: 30%)
  final int habitScore;   // 0 - 100 (weight: 20%)
  final int routineScore; // 0 - 100 (weight: 15%)
  final int streakBonus;  // 0 - 10 bonus points
  final String grade;     // 'A+', 'A', 'B', 'C', 'D'
  final String summary;

  ProductivityScoreModel({
    required this.overallScore,
    required this.taskScore,
    required this.focusScore,
    required this.habitScore,
    required this.routineScore,
    this.streakBonus = 0,
    required this.grade,
    required this.summary,
  });

  static ProductivityScoreModel calculate({
    required double taskCompletionRate, // 0.0 - 1.0
    required int focusMinutes,          // Target: 90+ mins
    required double habitCompletionRate,// 0.0 - 1.0
    required double routineAdherence,   // 0.0 - 1.0
    int activeStreakDays = 0,
  }) {
    // 1. Task Score (0 to 100)
    final tScore = (taskCompletionRate * 100).clamp(0, 100).round();

    // 2. Focus Score (0 to 100 based on 90-min target)
    final fScore = ((focusMinutes / 90.0) * 100).clamp(0, 100).round();

    // 3. Habit Score (0 to 100)
    final hScore = (habitCompletionRate * 100).clamp(0, 100).round();

    // 4. Routine Score (0 to 100)
    final rScore = (routineAdherence * 100).clamp(0, 100).round();

    // 5. Streak Bonus (1 point per active streak day up to 10)
    final bonus = activeStreakDays.clamp(0, 10);

    // Weighted Overall
    final rawWeighted = (tScore * 0.35) + (fScore * 0.30) + (hScore * 0.20) + (rScore * 0.15) + bonus;
    final overall = rawWeighted.clamp(0, 100).round();

    String calculatedGrade;
    String calculatedSummary;

    if (overall >= 90) {
      calculatedGrade = 'A+';
      calculatedSummary = '🔥 Peak Performance! Exceptional focus, habit consistency, and task execution.';
    } else if (overall >= 80) {
      calculatedGrade = 'A';
      calculatedSummary = '🚀 High Productivity! Strong alignment with your daily goals and focus blocks.';
    } else if (overall >= 70) {
      calculatedGrade = 'B';
      calculatedSummary = '👍 Solid Rhythm! Good progress made with opportunities to deepen focus sessions.';
    } else if (overall >= 50) {
      calculatedGrade = 'C';
      calculatedSummary = '🌱 Building Momentum. Focus on completing your top 3 priority tasks.';
    } else {
      calculatedGrade = 'D';
      calculatedSummary = '⚡ Reset & Refocus. Pick 1 high-leverage task to unlock momentum.';
    }

    return ProductivityScoreModel(
      overallScore: overall,
      taskScore: tScore,
      focusScore: fScore,
      habitScore: hScore,
      routineScore: rScore,
      streakBonus: bonus,
      grade: calculatedGrade,
      summary: calculatedSummary,
    );
  }
}
