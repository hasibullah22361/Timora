import 'focus_session_model.dart';

class FocusStatsModel {
  final int todayFocusMinutes;
  final int weekFocusMinutes;
  final int totalCompletedSessions;
  final int pomodoroCyclesCompleted;
  final double averageSessionMinutes;

  FocusStatsModel({
    required this.todayFocusMinutes,
    required this.weekFocusMinutes,
    required this.totalCompletedSessions,
    required this.pomodoroCyclesCompleted,
    required this.averageSessionMinutes,
  });

  factory FocusStatsModel.fromSessions(List<FocusSessionModel> sessions) {
    final completed = sessions.where((s) => s.status == FocusSessionStatus.completed).toList();
    if (completed.isEmpty) {
      return FocusStatsModel(
        todayFocusMinutes: 0,
        weekFocusMinutes: 0,
        totalCompletedSessions: 0,
        pomodoroCyclesCompleted: 0,
        averageSessionMinutes: 0.0,
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    int todaySeconds = 0;
    int weekSeconds = 0;
    int totalSeconds = 0;
    int pomodoros = 0;

    for (var s in completed) {
      final sessionStart = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
      final duration = s.actualDurationSeconds > 0 ? s.actualDurationSeconds : s.plannedDurationSeconds;

      totalSeconds += duration;

      if (sessionStart.isAtSameMomentAs(today)) {
        todaySeconds += duration;
      }

      if (sessionStart.isAfter(startOfWeek) || sessionStart.isAtSameMomentAs(startOfWeek)) {
        weekSeconds += duration;
      }

      if (s.mode == FocusSessionMode.pomodoro) {
        pomodoros++;
      }
    }

    final avgMinutes = (totalSeconds / 60) / completed.length;

    return FocusStatsModel(
      todayFocusMinutes: (todaySeconds / 60).round(),
      weekFocusMinutes: (weekSeconds / 60).round(),
      totalCompletedSessions: completed.length,
      pomodoroCyclesCompleted: pomodoros,
      averageSessionMinutes: double.parse(avgMinutes.toStringAsFixed(1)),
    );
  }

  int get totalFocusTimeMinutes => todayFocusMinutes;
  int get todayCompletedSessions => totalCompletedSessions;
  int get currentStreakDays => pomodoroCyclesCompleted > 0 ? pomodoroCyclesCompleted : 1;
}
