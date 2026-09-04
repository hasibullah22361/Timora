import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/features/focus/data/models/focus_session_model.dart';
import 'package:timora/features/focus/data/models/focus_stats_model.dart';
import 'package:timora/features/focus/data/repositories/focus_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FocusRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = FocusRepository(prefs, userId: 'test_user_focus');
  });

  group('Phase 6 — Focus Mode & Flow State Tests', () {
    test('FOCUS-1: FocusSessionModel serialization and status', () {
      final now = DateTime(2026, 8, 28, 14, 0);
      final session = FocusSessionModel(
        id: 'session_1',
        startedAt: now,
        plannedDurationSeconds: 1500, // 25 min
        actualDurationSeconds: 1500,
        status: FocusSessionStatus.completed,
        mode: FocusSessionMode.pomodoro,
        taskId: 'task_xyz',
        notes: 'Great focus on core modules',
        createdAt: now,
      );

      final json = session.toJson();
      final reconstituted = FocusSessionModel.fromJson(json);

      expect(reconstituted.id, 'session_1');
      expect(reconstituted.plannedDurationSeconds, 1500);
      expect(reconstituted.status, FocusSessionStatus.completed);
      expect(reconstituted.mode, FocusSessionMode.pomodoro);
      expect(reconstituted.taskId, 'task_xyz');
    });

    test('FOCUS-2: FocusStatsModel computes accurate daily and weekly metrics', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 0);

      final s1 = FocusSessionModel(
        id: 's_1',
        startedAt: today,
        plannedDurationSeconds: 1500, // 25 min
        actualDurationSeconds: 1500,
        status: FocusSessionStatus.completed,
        mode: FocusSessionMode.pomodoro,
        createdAt: today,
      );

      final s2 = FocusSessionModel(
        id: 's_2',
        startedAt: today.add(const Duration(hours: 2)),
        plannedDurationSeconds: 3000, // 50 min
        actualDurationSeconds: 3000,
        status: FocusSessionStatus.completed,
        mode: FocusSessionMode.focus,
        createdAt: today,
      );

      final stats = FocusStatsModel.fromSessions([s1, s2]);

      expect(stats.totalCompletedSessions, 2);
      expect(stats.todayFocusMinutes, 75); // 25 + 50
      expect(stats.weekFocusMinutes, 75);
      expect(stats.pomodoroCyclesCompleted, 1);
      expect(stats.averageSessionMinutes, 37.5);
    });

    test('FOCUS-3: FocusRepository active session detection and persistence', () async {
      final active = FocusSessionModel(
        id: 'active_1',
        startedAt: DateTime.now(),
        plannedDurationSeconds: 1800,
        status: FocusSessionStatus.running,
        createdAt: DateTime.now(),
      );

      await repo.saveSession(active);
      final foundActive = await repo.getActiveSession();

      expect(foundActive, isNotNull);
      expect(foundActive!.id, 'active_1');
      expect(foundActive.status, FocusSessionStatus.running);

      // Complete session
      final completed = foundActive.copyWith(
        status: FocusSessionStatus.completed,
        endedAt: DateTime.now(),
      );
      await repo.saveSession(completed);

      final afterComplete = await repo.getActiveSession();
      expect(afterComplete, isNull);

      final allCompleted = await repo.getAllCompletedSessions();
      expect(allCompleted.length, 1);
      expect(allCompleted.first.id, 'active_1');
    });
  });
}
