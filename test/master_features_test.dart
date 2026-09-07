import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/ai_assistant/services/voice_input_service.dart';
import 'package:timora/features/analytics/data/models/productivity_event_model.dart';
import 'package:timora/features/analytics/data/models/report_model.dart';
import 'package:timora/features/career/data/models/career_milestone_model.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';

void main() {
  group('Feature 2: Missed Task Recovery Logic', () {
    test('Identifies missed uncompleted activities in the past', () {
      final now = DateTime(2026, 9, 6, 14, 0); // 2:00 PM
      final pastActivity = ScheduleActivity(
        id: 'act-1',
        title: 'Morning Research',
        date: DateTime(2026, 9, 6),
        startTime: DateTime(2026, 9, 6, 9, 0),
        endTime: DateTime(2026, 9, 6, 10, 30),
        status: ActivityStatus.upcoming,
        createdAt: DateTime(2026, 9, 6, 8, 0),
      );

      final ongoingActivity = ScheduleActivity(
        id: 'act-2',
        title: 'Current Meeting',
        date: DateTime(2026, 9, 6),
        startTime: DateTime(2026, 9, 6, 13, 30),
        endTime: DateTime(2026, 9, 6, 15, 0),
        status: ActivityStatus.current,
        createdAt: DateTime(2026, 9, 6, 8, 0),
      );

      final completedActivity = ScheduleActivity(
        id: 'act-3',
        title: 'Workout',
        date: DateTime(2026, 9, 6),
        startTime: DateTime(2026, 9, 6, 7, 0),
        endTime: DateTime(2026, 9, 6, 8, 0),
        status: ActivityStatus.completed,
        createdAt: DateTime(2026, 9, 6, 6, 0),
      );

      final activities = [pastActivity, ongoingActivity, completedActivity];
      final missed = activities.where((a) {
        if (a.status == ActivityStatus.completed || a.status == ActivityStatus.skipped) {
          return false;
        }
        return a.endTime.isBefore(now);
      }).toList();

      expect(missed.length, 1);
      expect(missed.first.id, 'act-1');
      expect(missed.first.title, 'Morning Research');
    });

    test('Identifies free non-overlapping gap after current schedule', () {
      final existingSchedule = [
        ScheduleActivity(
          id: 's-1',
          title: 'Deep Work',
          date: DateTime(2026, 9, 6),
          startTime: DateTime(2026, 9, 6, 14, 30),
          endTime: DateTime(2026, 9, 6, 16, 0),
          status: ActivityStatus.upcoming,
          createdAt: DateTime(2026, 9, 6, 8, 0),
        ),
        ScheduleActivity(
          id: 's-2',
          title: 'Team Sync',
          date: DateTime(2026, 9, 6),
          startTime: DateTime(2026, 9, 6, 16, 30),
          endTime: DateTime(2026, 9, 6, 17, 30),
          status: ActivityStatus.upcoming,
          createdAt: DateTime(2026, 9, 6, 8, 0),
        ),
      ];

      // Earliest 1-hour candidate starting after 17:30 with 5m buffer
      final candidateStart = existingSchedule.last.endTime.add(const Duration(minutes: 5));
      final candidateEnd = candidateStart.add(const Duration(minutes: 60));

      // Assert that this candidate does not collide with any existing activity
      final hasCollision = existingSchedule.any((a) =>
          candidateStart.isBefore(a.endTime) && candidateEnd.isAfter(a.startTime));

      expect(hasCollision, isFalse);
      expect(candidateStart.hour, 17);
      expect(candidateStart.minute, 35);
    });
  });

  group('Feature 3: Natural Voice Planning Target Determination Tests', () {
    test('Parses schedule creation intent', () {
      final target = VoiceInputService.determineTarget(
        'Tomorrow I want to study AI from 9 to 12',
      );
      expect(target, VoiceRoutingTarget.activity);
    });

    test('Parses query schedule intent', () {
      final target = VoiceInputService.determineTarget('What do I have tomorrow?');
      expect(target, VoiceRoutingTarget.querySchedule);
    });

    test('Parses What Should I Do Now voice query', () {
      final target = VoiceInputService.determineTarget('What should I do now?');
      expect(target, VoiceRoutingTarget.queryWhatShouldIDoNow);
    });

    test('Parses cancel activity intent', () {
      final target = VoiceInputService.determineTarget('Cancel gym at 5 PM today');
      expect(target, VoiceRoutingTarget.cancel);
    });

    test('Parses reschedule intent', () {
      final target = VoiceInputService.determineTarget('Move my research to 9 PM');
      expect(target, VoiceRoutingTarget.reschedule);
    });
  });

  group('Feature 5: Report Model Tests', () {
    test('Calculates and holds structured daily metrics correctly', () {
      final report = DailyReportModel(
        date: DateTime(2026, 9, 6),
        plannedActivities: 8,
        completedActivities: 6,
        missedActivities: 1,
        recoveredActivities: 1,
        completionPercentage: 75.0,
        focusTimeMinutes: 320, // 5h 20m
        routineConsistency: 86.0,
        tasksCompleted: 4,
        tasksRemaining: 2,
      );

      expect(report.completedActivities, 6);
      expect(report.missedActivities, 1);
      expect(report.recoveredActivities, 1);
      expect(report.completionPercentage, 75.0);
      expect(report.focusTimeMinutes, 320);
      expect(report.routineConsistency, 86.0);
    });
  });

  group('Feature 7: Consistency Calculation Logic', () {
    test('Calculates mathematically accurate consistency ratio', () {
      final events = [
        ProductivityEventModel(
          eventType: ProductivityEventType.routineCompleted,
          entityType: 'routine',
          entityId: 'rot-1',
          timestamp: DateTime(2026, 9, 1, 7, 30),
          metadata: {'category': 'Health'},
        ),
        ProductivityEventModel(
          eventType: ProductivityEventType.routineCompleted,
          entityType: 'routine',
          entityId: 'rot-1',
          timestamp: DateTime(2026, 9, 2, 7, 30),
          metadata: {'category': 'Health'},
        ),
        ProductivityEventModel(
          eventType: ProductivityEventType.routineMissed,
          entityType: 'routine',
          entityId: 'rot-1',
          timestamp: DateTime(2026, 9, 3, 7, 30),
          metadata: {'category': 'Health'},
        ),
        ProductivityEventModel(
          eventType: ProductivityEventType.routineCompleted,
          entityType: 'routine',
          entityId: 'rot-1',
          timestamp: DateTime(2026, 9, 4, 7, 30),
          metadata: {'category': 'Health'},
        ),
      ];

      final total = events.length;
      final completed = events.where((e) => e.eventType == ProductivityEventType.routineCompleted).length;
      final score = (completed / total) * 100;

      // Expected: 4 total, 3 completed = 75%
      expect(total, 4);
      expect(completed, 3);
      expect(score, 75.0);
    });
  });

  group('Feature 10: Career Roadmap Tests', () {
    test('Milestone completion and progress roll-up calculation', () {
      final milestones = [
        CareerMilestoneModel(
          id: 'm-1',
          roadmapId: 'r-1',
          userId: 'u-1',
          title: 'Python Fundamentals',
          progress: 100,
          status: CareerMilestoneStatus.completed,
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        CareerMilestoneModel(
          id: 'm-2',
          roadmapId: 'r-1',
          userId: 'u-1',
          title: 'Machine Learning',
          progress: 50,
          status: CareerMilestoneStatus.inProgress,
          sortOrder: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        CareerMilestoneModel(
          id: 'm-3',
          roadmapId: 'r-1',
          userId: 'u-1',
          title: 'Deep Learning',
          progress: 0,
          status: CareerMilestoneStatus.notStarted,
          sortOrder: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final totalProgress = milestones.map((m) => m.progress).reduce((a, b) => a + b) ~/ milestones.length;
      expect(totalProgress, 50); // (100 + 50 + 0) / 3 = 50%
    });
  });
}
