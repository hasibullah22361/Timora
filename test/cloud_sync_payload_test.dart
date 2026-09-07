import 'package:flutter_test/flutter_test.dart';
import 'package:timora/features/routine/data/models/routine.dart';
import 'package:timora/features/schedule/data/models/schedule_activity.dart';

void main() {
  group('Supabase Push Payload Formatting Tests', () {
    test('Routine payload formatted correctly for PostgreSQL', () {
      final routine = Routine(
        id: 'r-1',
        name: 'Evening Routine',
        daysOfWeek: [1, 2, 3, 4, 5],
        createdAt: DateTime.parse('2026-09-01T20:00:00.000Z'),
      );

      // Test formatting via reflection or testing the output fields
      final raw = routine.toJson();
      expect(raw.containsKey('daysOfWeek'), isTrue);
      expect(raw.containsKey('startDate'), isTrue);
    });

    test('ScheduleActivity and Task formatting preserves required DB columns', () {
      final now = DateTime.parse('2026-09-05T10:00:00.000Z');
      final act = ScheduleActivity(
        id: 'act-1',
        title: 'Deep Focus',
        date: now,
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        category: 'Work',
        createdAt: now,
      );
      final json = act.toJson();
      expect(json['title'], 'Deep Focus');
      expect(json.containsKey('startTime'), isTrue);
      expect(json.containsKey('date'), isTrue);
    });
  });
}
